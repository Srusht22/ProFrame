import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/opening_model.dart';
import 'region_editor.dart';
import 'region_solver.dart';

enum IssueSeverity { info, warning, serious }

extension IssueSeverityInfo on IssueSeverity {
  String get label => switch (this) {
        IssueSeverity.info => 'Note',
        IssueSeverity.warning => 'Check this',
        IssueSeverity.serious => 'Likely a problem',
      };
}

/// Something worth telling the user about the design.
///
/// An issue never changes anything. When a sensible correction exists it is
/// offered through [recommendedFix], which the user can apply, ignore, or fix
/// their own way — the design stays theirs.
class DesignIssue {
  final String id;
  final IssueSeverity severity;
  final String title;
  final String detail;
  final String? regionId;

  /// A proposed change, offered and never applied on its own.
  final OpeningModel Function(OpeningModel model)? recommendedFix;
  final String? recommendationLabel;

  const DesignIssue({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
    this.regionId,
    this.recommendedFix,
    this.recommendationLabel,
  });

  bool get hasRecommendation => recommendedFix != null;
}

/// Checks a design and reports what it finds.
///
/// This is the only place manufacturing limits are applied, and it applies them
/// by *saying something* — never by editing the design. A customer who wants a
/// deliberately awkward unit gets it, with the risks spelled out.
class DesignValidator {
  const DesignValidator();

  /// Below this the product is not something a factory can make.
  static const double minProductMm = 200;
  static const double maxWidthMm = 6000;
  static const double maxHeightMm = 4000;

  /// An opening leaf wider than this sags and needs reinforcement.
  static const double maxLeafWidthMm = 1200;

  List<DesignIssue> validate(OpeningModel model) {
    final issues = <DesignIssue>[];

    if (model.widthMm < minProductMm) {
      issues.add(DesignIssue(
        id: 'width.min',
        severity: IssueSeverity.serious,
        title: 'Width is below the ${minProductMm.round()} mm minimum',
        detail: '${model.widthMm.round()} mm is too narrow to build with this profile.',
      ));
    }
    if (model.heightMm < minProductMm) {
      issues.add(DesignIssue(
        id: 'height.min',
        severity: IssueSeverity.serious,
        title: 'Height is below the ${minProductMm.round()} mm minimum',
        detail: '${model.heightMm.round()} mm is too short to build with this profile.',
      ));
    }
    if (model.widthMm > maxWidthMm) {
      issues.add(DesignIssue(
        id: 'width.max',
        severity: IssueSeverity.warning,
        title: 'Width exceeds the usual ${maxWidthMm.round()} mm span',
        detail: 'A ${model.widthMm.round()} mm unit normally needs a structural '
            'mullion or a coupled frame.',
      ));
    }
    if (model.heightMm > maxHeightMm) {
      issues.add(DesignIssue(
        id: 'height.max',
        severity: IssueSeverity.warning,
        title: 'Height exceeds the usual ${maxHeightMm.round()} mm span',
        detail: 'A ${model.heightMm.round()} mm unit normally needs a transom.',
      ));
    }

    issues.addAll(_boundsIssues(model));
    issues.addAll(_overlapIssues(model));
    issues.addAll(_coverageIssues(model));
    issues.addAll(_sectionIssues(model));

    return issues;
  }

  /// Nothing may stick out past the overall dimensions.
  List<DesignIssue> _boundsIssues(OpeningModel model) {
    final issues = <DesignIssue>[];
    final outer = model.outerRect;
    for (final region in model.regions) {
      final rect = region.rect;
      if (rect.left < -0.5 ||
          rect.top < -0.5 ||
          rect.right > outer.right + 0.5 ||
          rect.bottom > outer.bottom + 0.5) {
        issues.add(DesignIssue(
          id: 'bounds.${region.id}',
          severity: IssueSeverity.serious,
          regionId: region.id,
          title: 'A section sits outside the product',
          detail: '${_name(region)} runs from '
              '${rect.left.round()},${rect.top.round()} to '
              '${rect.right.round()},${rect.bottom.round()} mm, which is outside '
              'the ${model.widthMm.round()} × ${model.heightMm.round()} mm frame.',
          recommendationLabel: 'Pull it back inside the frame',
          recommendedFix: (m) => RegionEditor.setRect(
            m,
            region.id,
            Box2(
              math.max(rect.left, 0),
              math.max(rect.top, 0),
              math.min(rect.right, m.widthMm),
              math.min(rect.bottom, m.heightMm),
            ),
          ),
        ));
      }
    }
    return issues;
  }

  List<DesignIssue> _overlapIssues(OpeningModel model) {
    final issues = <DesignIssue>[];
    final regions = model.regions;
    for (var i = 0; i < regions.length; i++) {
      for (var j = i + 1; j < regions.length; j++) {
        final overlap = regions[i].rect.intersect(regions[j].rect);
        if (overlap == null || overlap.area < 1) continue;
        issues.add(DesignIssue(
          id: 'overlap.${regions[i].id}.${regions[j].id}',
          severity: IssueSeverity.serious,
          regionId: regions[i].id,
          title: 'Two sections overlap',
          detail: '${_name(regions[i])} and ${_name(regions[j])} share '
              '${overlap.width.round()} × ${overlap.height.round()} mm. '
              'Two sections cannot occupy the same place.',
        ));
      }
    }
    return issues;
  }

  /// Area belonging to no section. Reported, never filled in automatically.
  List<DesignIssue> _coverageIssues(OpeningModel model) {
    final total = model.widthMm * model.heightMm;
    if (total <= 0) return const [];
    final covered = model.regions
        .fold<double>(0, (sum, r) => sum + r.rect.width * r.rect.height);
    final gap = total - covered;
    if (gap <= total * 0.005) return const [];

    return [
      DesignIssue(
        id: 'coverage',
        severity: IssueSeverity.warning,
        title: '${(gap / total * 100).round()}% of the frame is not assigned',
        detail: 'Any area with no section becomes solid profile. If that is not '
            'what you want, add a section over it or stretch a neighbour.',
      ),
    ];
  }

  List<DesignIssue> _sectionIssues(OpeningModel model) {
    final issues = <DesignIssue>[];
    final solved = RegionSolver.solve(model);

    for (final region in solved.allRegions) {
      final aperture = region.aperture;
      if (aperture.width < 60 || aperture.height < 60) {
        issues.add(DesignIssue(
          id: 'tiny.${region.id}',
          severity: IssueSeverity.serious,
          regionId: region.id,
          title: 'A section is too small to fabricate',
          detail: '${_name(region.spec)} leaves only '
              '${math.max(aperture.width, 0).round()} × '
              '${math.max(aperture.height, 0).round()} mm once the profile is '
              'taken off. It needs to be at least '
              '${RegionEditor.minSectionMm.round()} mm each way.',
        ));
        continue;
      }

      if (region.spec.operation.isOperable &&
          !region.spec.operation.isSliding &&
          region.rect.width > maxLeafWidthMm) {
        issues.add(DesignIssue(
          id: 'leafWidth.${region.id}',
          severity: IssueSeverity.warning,
          regionId: region.id,
          title: 'Opening leaf is ${region.rect.width.round()} mm wide',
          detail: 'Hinged leaves over ${maxLeafWidthMm.round()} mm sag over time '
              'and need heavier hardware. It can still be built — this is a '
              'durability warning, not a refusal.',
          recommendationLabel:
              'Narrow it to ${maxLeafWidthMm.round()} mm',
          recommendedFix: (m) =>
              RegionEditor.setWidth(m, region.id, maxLeafWidthMm),
        ));
      }
    }
    return issues;
  }

  String _name(DesignRegion region) =>
      region.label ?? 'Section ${region.id}';
}
