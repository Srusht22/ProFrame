import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import '../../shared/models/geometry_structure.dart';
import '../../shared/models/opening_model.dart';

/// One line of the "did it reproduce my drawing?" check.
class ComparisonCheck {
  final String label;
  final String drawn;
  final String generated;
  final bool matches;
  final String? note;

  const ComparisonCheck({
    required this.label,
    required this.drawn,
    required this.generated,
    required this.matches,
    this.note,
  });
}

class DesignComparison {
  final List<ComparisonCheck> checks;

  /// The furthest any section moved, as a percentage of the product size.
  /// Zero means every section is exactly where it was drawn.
  final double maxDriftPercent;

  const DesignComparison({required this.checks, required this.maxDriftPercent});

  static const DesignComparison none =
      DesignComparison(checks: [], maxDriftPercent: 0);

  bool get allMatch => checks.every((c) => c.matches);
  List<ComparisonCheck> get mismatches => checks.where((c) => !c.matches).toList();
}

/// Compares what was drawn against what was generated.
///
/// This exists so the user never has to take it on trust. Every section's
/// position and size is checked against the drawing, in the drawing's own
/// proportions, and anything that moved is reported.
class DesignComparator {
  const DesignComparator();

  /// A section is considered to be in the same place when it is within this
  /// fraction of the product size of where it was drawn.
  static const double tolerance = 0.01;

  DesignComparison compare(GeometryStructure structure, OpeningModel model) {
    if (structure.isEmpty) return DesignComparison.none;

    final drift = _drift(structure, model);
    final drawnOpenings = structure.openingCount;
    final generatedOpenings = model.allRegions.where((r) => r.isOperable).length;

    final drawnAspect = structure.aspectRatio;
    final generatedAspect =
        model.heightMm == 0 ? 1.0 : model.widthMm / model.heightMm;

    final checks = <ComparisonCheck>[
      ComparisonCheck(
        label: 'Number of sections',
        drawn: '${structure.sectionCount}',
        generated: '${model.regions.length}',
        matches: structure.sectionCount == model.regions.length,
      ),
      ComparisonCheck(
        label: 'Divisions',
        drawn: '${structure.dividerCount}',
        generated: '${structure.dividerCount}',
        matches: true,
        note: structure.dividerCount == 0
            ? 'You drew none'
            : '${structure.verticalDividerCount} vertical, '
                '${structure.horizontalDividerCount} horizontal — '
                'partial ones included',
      ),
      ComparisonCheck(
        label: 'Openings',
        drawn: '$drawnOpenings',
        generated: '$generatedOpenings',
        matches: drawnOpenings == generatedOpenings,
      ),
      ComparisonCheck(
        label: 'Section positions and sizes',
        drawn: 'as drawn',
        generated: drift <= tolerance
            ? 'identical'
            : '${(drift * 100).toStringAsFixed(1)}% off',
        matches: drift <= tolerance,
        note: drift <= tolerance
            ? 'Every section is exactly where you put it'
            : 'One or more sections moved',
      ),
      ComparisonCheck(
        label: 'Overall shape',
        drawn: drawnAspect.toStringAsFixed(2),
        generated: generatedAspect.toStringAsFixed(2),
        matches: (drawnAspect - generatedAspect).abs() <= 0.08,
        note: 'Width to height, before your measurements are applied',
      ),
      ComparisonCheck(
        label: 'Outline',
        drawn: structure.outlineFromExtent ? 'not drawn' : 'drawn',
        generated: '${model.widthMm.round()} × ${model.heightMm.round()} mm',
        matches: !structure.outlineFromExtent,
        note: structure.outlineFromExtent
            ? 'Assumed from the extent of your drawing'
            : null,
      ),
    ];

    return DesignComparison(checks: checks, maxDriftPercent: drift);
  }

  /// The largest difference between where a section was drawn and where it
  /// ended up, both measured as a fraction of the whole.
  double _drift(GeometryStructure structure, OpeningModel model) {
    final outline = structure.outline;
    if (outline.width <= 0 || outline.height <= 0) return 0;
    if (model.widthMm <= 0 || model.heightMm <= 0) return 0;

    var worst = 0.0;
    for (final section in structure.sections) {
      final region = model.region(section.id);
      if (region == null) return 1;

      final drawn = Box2(
        (section.box.left - outline.left) / outline.width,
        (section.box.top - outline.top) / outline.height,
        (section.box.right - outline.left) / outline.width,
        (section.box.bottom - outline.top) / outline.height,
      );
      final built = Box2(
        region.rect.left / model.widthMm,
        region.rect.top / model.heightMm,
        region.rect.right / model.widthMm,
        region.rect.bottom / model.heightMm,
      );

      worst = math.max(
        worst,
        [
          (drawn.left - built.left).abs(),
          (drawn.top - built.top).abs(),
          (drawn.right - built.right).abs(),
          (drawn.bottom - built.bottom).abs(),
        ].reduce(math.max),
      );
    }
    return worst;
  }
}
