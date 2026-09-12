import '../design_document.dart';
import '../geometry/tolerances.dart';
import '../panel.dart';

/// How serious a finding is.
enum FindingLevel {
  /// Something is missing. The design is unfinished, not wrong.
  incomplete,

  /// Something is contradictory or unbuildable. It has to be resolved.
  conflict,
}

/// One thing the app noticed about a design.
///
/// A finding is a **report**, never a correction. The spec is explicit that a
/// confirmed dimension is not silently overridden to make a layout fit
/// (section 6), so nothing in this file changes a design — it only describes
/// what it found, in language a factory worker can act on.
class Finding {
  final FindingLevel level;

  /// What is wrong, in plain words. No jargon, no error codes.
  final String message;

  /// What the user can do about it.
  final String remedy;

  /// The panel or divider involved, so the UI can point at it.
  final String? subjectId;

  const Finding({
    required this.level,
    required this.message,
    required this.remedy,
    this.subjectId,
  });

  bool get isConflict => level == FindingLevel.conflict;

  @override
  String toString() => '${level.name}: $message';
}

/// Checks a design for missing and contradictory dimensions.
///
/// Pure: it reads a document and returns findings. It never edits anything.
abstract final class DesignValidator {
  /// Everything worth telling the user about [design].
  static List<Finding> check(DesignDocument design) => [
        ..._sizeFindings(design),
        ..._panelFindings(design),
        ..._openingFindings(design),
        ..._fitFindings(design),
      ];

  /// True when nothing contradictory was found. Missing values do not make a
  /// design invalid — they make it unfinished.
  static bool isBuildable(DesignDocument design) =>
      check(design).every((f) => !f.isConflict);

  // -- overall size ---------------------------------------------------------

  static List<Finding> _sizeFindings(DesignDocument design) {
    final findings = <Finding>[];
    final width = design.overallWidth;
    final height = design.overallHeight;

    if (width == null) {
      findings.add(const Finding(
        level: FindingLevel.incomplete,
        message: 'The overall width has not been entered.',
        remedy: 'Tap the width below the drawing and type it.',
      ));
    } else if (width.millimetres <= 0) {
      findings.add(const Finding(
        level: FindingLevel.conflict,
        message: 'The overall width is zero or negative.',
        remedy: 'Type a width greater than zero.',
      ));
    }

    if (height == null) {
      findings.add(const Finding(
        level: FindingLevel.incomplete,
        message: 'The overall height has not been entered.',
        remedy: 'Tap the height beside the drawing and type it.',
      ));
    } else if (height.millimetres <= 0) {
      findings.add(const Finding(
        level: FindingLevel.conflict,
        message: 'The overall height is zero or negative.',
        remedy: 'Type a height greater than zero.',
      ));
    }

    // A wall opening smaller than twice its own fitting gap leaves no frame.
    final frameWidth = design.frameWidthMm;
    final frameHeight = design.frameHeightMm;
    if (frameWidth != null && frameWidth <= 0) {
      findings.add(Finding(
        level: FindingLevel.conflict,
        message: 'The fitting gap of ${design.fittingGapMm.round()} mm each '
            'side leaves no frame at all in a '
            '${width?.millimetres.round()} mm opening.',
        remedy: 'Reduce the fitting gap, or check the opening size.',
      ));
    }
    if (frameHeight != null && frameHeight <= 0) {
      findings.add(const Finding(
        level: FindingLevel.conflict,
        message: 'The fitting gap leaves no frame height at all.',
        remedy: 'Reduce the fitting gap, or check the opening height.',
      ));
    }

    return findings;
  }

  // -- panels ---------------------------------------------------------------

  static List<Finding> _panelFindings(DesignDocument design) {
    final findings = <Finding>[];

    for (var i = 0; i < design.panels.length; i++) {
      final panel = design.panels[i];
      final name = _nameOf(panel, i);

      if (panel.widthMm <= 0 || panel.heightMm <= 0) {
        findings.add(Finding(
          level: FindingLevel.conflict,
          message: '$name has no size.',
          remedy: 'Move the divider beside it, or undo the last change.',
          subjectId: panel.id,
        ));
        continue;
      }

      if (panel.widthMm < Tolerances.minimumPanelSideMm ||
          panel.heightMm < Tolerances.minimumPanelSideMm) {
        findings.add(Finding(
          level: FindingLevel.conflict,
          message: '$name is ${panel.widthMm.round()} × '
              '${panel.heightMm.round()} mm, under the '
              '${Tolerances.minimumPanelSideMm.round()} mm minimum.',
          remedy: 'Widen it, or remove the divider beside it.',
          subjectId: panel.id,
        ));
      }

      final outline = design.outline;
      if (outline != null) {
        final box = panel.boundary;
        final outside = box.left < outline.left - Tolerances.lengthMm ||
            box.right > outline.right + Tolerances.lengthMm ||
            box.top < outline.top - Tolerances.lengthMm ||
            box.bottom > outline.bottom + Tolerances.lengthMm;
        if (outside) {
          findings.add(Finding(
            level: FindingLevel.conflict,
            message: '$name sits outside the frame.',
            remedy: 'Undo the change that moved it, or redraw the divider.',
            subjectId: panel.id,
          ));
        }
      }
    }

    return findings;
  }

  // -- panels against the frame ---------------------------------------------

  /// Do the panels in each row still add up to the frame width?
  ///
  /// This is the check that catches a contradiction between what the user
  /// typed and what the layout can hold. It reports; it does not reconcile.
  static List<Finding> _fitFindings(DesignDocument design) {
    final outline = design.outline;
    if (outline == null || design.panels.isEmpty) return const [];

    final findings = <Finding>[];
    final rows = _rows(design.panels);

    for (final row in rows) {
      if (row.length < 2) continue;
      final sorted = [...row]
        ..sort((a, b) => a.boundary.left.compareTo(b.boundary.left));

      // Gaps and overlaps between neighbours.
      for (var i = 1; i < sorted.length; i++) {
        final gap = sorted[i].boundary.left - sorted[i - 1].boundary.right;
        if (gap > Tolerances.lengthMm) {
          findings.add(Finding(
            level: FindingLevel.conflict,
            message: 'There is a ${gap.round()} mm gap between two panels '
                'that nothing fills.',
            remedy: 'Widen one of them, or move the divider between them.',
            subjectId: sorted[i].id,
          ));
        } else if (gap < -Tolerances.lengthMm) {
          findings.add(Finding(
            level: FindingLevel.conflict,
            message: 'Two panels overlap by ${gap.abs().round()} mm.',
            remedy: 'Narrow one of them, or move the divider between them.',
            subjectId: sorted[i].id,
          ));
        }
      }

      final total = sorted.last.boundary.right - sorted.first.boundary.left;
      final span = outline.width;
      if ((total - span).abs() > Tolerances.lengthMm) {
        findings.add(Finding(
          level: FindingLevel.conflict,
          message: 'The panels in one row add up to ${total.round()} mm, but '
              'the frame is ${span.round()} mm wide.',
          remedy: 'Change a panel width — the panel beside it will take up '
              'the difference.',
        ));
      }
    }

    return findings;
  }

  // -- openings -------------------------------------------------------------

  static List<Finding> _openingFindings(DesignDocument design) {
    final findings = <Finding>[];
    final profile = design.profileSystem;

    for (var i = 0; i < design.panels.length; i++) {
      final panel = design.panels[i];
      final opening = panel.opening;
      if (opening == null) continue;
      final name = _nameOf(panel, i);

      if (!opening.isConfirmed) {
        findings.add(Finding(
          level: FindingLevel.incomplete,
          message: '$name opens, but how it opens has not been confirmed.',
          remedy: 'Long-press it and choose the hinge side and direction.',
          subjectId: panel.id,
        ));
      }

      // Size limits come from the profile system, so PVC and aluminium differ
      // (spec section 9).
      if (panel.widthMm > profile.maxSashWidthMm) {
        findings.add(Finding(
          level: FindingLevel.conflict,
          message: '$name is ${panel.widthMm.round()} mm wide, over the '
              '${profile.maxSashWidthMm.round()} mm limit for an opening leaf '
              'in ${profile.name}.',
          remedy: 'Make it fixed (CH), narrow it, or choose a system rated '
              'for a wider leaf.',
          subjectId: panel.id,
        ));
      }
      if (panel.heightMm > profile.maxSashHeightMm) {
        findings.add(Finding(
          level: FindingLevel.conflict,
          message: '$name is ${panel.heightMm.round()} mm tall, over the '
              '${profile.maxSashHeightMm.round()} mm limit for an opening leaf '
              'in ${profile.name}.',
          remedy: 'Make it fixed (CH), or add a transom above it.',
          subjectId: panel.id,
        ));
      }
    }

    return findings;
  }

  // -- helpers --------------------------------------------------------------

  static String _nameOf(Panel panel, int index) =>
      panel.label.isEmpty ? 'Panel ${index + 1}' : panel.label;

  /// Panels grouped into horizontal bands.
  static List<List<Panel>> _rows(List<Panel> panels) {
    final rows = <List<Panel>>[];
    for (final panel in panels) {
      final row = rows.where((candidate) {
        final other = candidate.first.boundary;
        final box = panel.boundary;
        final overlap = (other.bottom < box.bottom ? other.bottom : box.bottom) -
            (other.top > box.top ? other.top : box.top);
        return overlap > 1;
      }).firstOrNull;
      if (row == null) {
        rows.add([panel]);
      } else {
        row.add(panel);
      }
    }
    return rows;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
