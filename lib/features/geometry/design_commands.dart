import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import 'region_editor.dart';
import 'region_selector.dart';

/// What a command did, or why it could not.
class CommandOutcome {
  final OpeningModel model;
  final String? selectedId;
  final String description;
  final String? problem;

  const CommandOutcome.done(this.model, this.description, {this.selectedId})
      : problem = null;

  const CommandOutcome.failed(this.model, this.problem)
      : description = '',
        selectedId = null;

  bool get succeeded => problem == null;
}

/// One editable change derived from an instruction.
///
/// Commands do exactly what they say. None of them tidies the design up
/// afterwards, and none runs unless the section it names resolves to exactly
/// one part of the design.
sealed class DesignCommand {
  const DesignCommand();

  CommandOutcome apply(OpeningModel model, {String? selectedId});

  /// Plain words for what this will do, shown before it is applied.
  String get preview;
}

const _resolver = RegionResolver();

/// "Make the upper half glass and the lower half panel."
class DivideCommand extends DesignCommand {
  final RegionSelector target;
  final Axis2 axis;
  final double ratio;
  final CellInfill? firstInfill;
  final CellInfill? secondInfill;

  const DivideCommand({
    this.target = const RegionSelector(),
    required this.axis,
    this.ratio = 0.5,
    this.firstInfill,
    this.secondInfill,
  });

  @override
  String get preview => axis == Axis2.horizontal
      ? 'Split ${target.describe()} into ${_percent(ratio)} on top and '
          '${_percent(1 - ratio)} underneath'
      : 'Split ${target.describe()} into ${_percent(ratio)} on the left and '
          '${_percent(1 - ratio)} on the right';

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final resolved = _resolveTarget(model, target, selectedId);
    final id = resolved.id;
    if (id == null) {
      return CommandOutcome.failed(
        model,
        resolved.problem ?? 'I could not tell which section to divide.',
      );
    }

    final before = model.allRegions.map((r) => r.id).toSet();
    var next = RegionEditor.divide(model, id, axis: axis, ratio: ratio);
    final added = next.allRegions.map((r) => r.id).where((i) => !before.contains(i));
    if (added.isEmpty) {
      return CommandOutcome.failed(
        model,
        'That section is too small to divide — each part needs at least '
        '${RegionEditor.minSectionMm.round()} mm.',
      );
    }

    if (firstInfill != null) {
      next = RegionEditor.update(next, id, (r) => r.copyWith(infill: firstInfill));
    }
    if (secondInfill != null) {
      next = RegionEditor.update(
        next,
        added.first,
        (r) => r.copyWith(infill: secondInfill),
      );
    }
    return CommandOutcome.done(next, preview, selectedId: id);
  }
}

/// "Make the glass 70%." — moves the boundary it shares with its neighbour.
class SetShareCommand extends DesignCommand {
  final RegionSelector target;
  final double fraction;
  final Axis2 axis;

  const SetShareCommand({
    required this.target,
    required this.fraction,
    this.axis = Axis2.horizontal,
  });

  @override
  String get preview =>
      'Make ${target.describe()} ${_percent(fraction)} of the ${axis == Axis2.horizontal ? 'height' : 'width'}';

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final resolved = _resolveTarget(model, target, selectedId);
    final id = resolved.id;
    if (id == null) {
      return CommandOutcome.failed(
        model,
        resolved.problem ?? 'I could not tell which section you mean.',
      );
    }
    final region = model.region(id)!;
    final container = RegionTree.parentOf(model.regions, id)?.rect ?? model.outerRect;
    final extent =
        axis == Axis2.horizontal ? container.height : container.width;
    final size = extent * fraction;
    final next = axis == Axis2.horizontal
        ? RegionEditor.setHeight(model, id, size)
        : RegionEditor.setWidth(model, id, size);

    final achieved = next.region(id)!;
    final actual =
        axis == Axis2.horizontal ? achieved.rect.height : achieved.rect.width;
    if ((actual - size).abs() > 1) {
      return CommandOutcome.done(
        next,
        '${preview.replaceFirst('Make', 'Made')} — limited to '
        '${actual.round()} mm so the neighbouring section stays buildable',
        selectedId: id,
      );
    }
    if (region.rect == achieved.rect) {
      return CommandOutcome.failed(
        model,
        'That section is already ${_percent(fraction)}.',
      );
    }
    return CommandOutcome.done(next, preview, selectedId: id);
  }
}

/// "Make the left section 40 cm wide." / "…full height."
class SetSizeCommand extends DesignCommand {
  final RegionSelector target;
  final double? widthMm;
  final double? heightMm;
  final bool fullWidth;
  final bool fullHeight;

  const SetSizeCommand({
    required this.target,
    this.widthMm,
    this.heightMm,
    this.fullWidth = false,
    this.fullHeight = false,
  });

  @override
  String get preview {
    final parts = <String>[
      if (fullWidth) 'the full width' else if (widthMm != null) '${widthMm!.round()} mm wide',
      if (fullHeight)
        'the full height'
      else if (heightMm != null)
        '${heightMm!.round()} mm high',
    ];
    return 'Make ${target.describe()} ${parts.join(' and ')}';
  }

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final resolved = _resolveTarget(model, target, selectedId);
    final id = resolved.id;
    if (id == null) {
      return CommandOutcome.failed(
        model,
        resolved.problem ?? 'I could not tell which section you mean.',
      );
    }
    var next = model;
    if (fullWidth) next = RegionEditor.expandToFull(next, id, Axis2.vertical);
    if (fullHeight) next = RegionEditor.expandToFull(next, id, Axis2.horizontal);
    if (!fullWidth && widthMm != null) {
      next = RegionEditor.setWidth(next, id, widthMm!);
    }
    if (!fullHeight && heightMm != null) {
      next = RegionEditor.setHeight(next, id, heightMm!);
    }

    if (next.region(id)!.rect == model.region(id)!.rect) {
      return CommandOutcome.failed(
        model,
        'That would not change anything, or it is limited by the neighbouring '
        'sections.',
      );
    }
    return CommandOutcome.done(next, preview, selectedId: id);
  }
}

/// "At the top-right, a 40 by 40 cm opening."
class PlaceOpeningCommand extends DesignCommand {
  final double widthMm;
  final double heightMm;
  final bool fullHeight;
  final bool fullWidth;
  final RegionAnchor anchor;
  final CellOperation operation;
  final String? label;

  const PlaceOpeningCommand({
    required this.widthMm,
    required this.heightMm,
    required this.anchor,
    this.operation = CellOperation.awning,
    this.fullHeight = false,
    this.fullWidth = false,
    this.label,
  });

  @override
  String get preview {
    final w = fullWidth ? 'full width' : '${widthMm.round()} mm';
    final h = fullHeight ? 'full height' : '${heightMm.round()} mm';
    return 'Put a $w × $h opening at the ${anchor.label}';
  }

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final width = fullWidth ? model.widthMm : widthMm;
    final height = fullHeight ? model.heightMm : heightMm;
    if (width < RegionEditor.minSectionMm || height < RegionEditor.minSectionMm) {
      return CommandOutcome.failed(
        model,
        'An opening has to be at least ${RegionEditor.minSectionMm.round()} mm '
        'each way.',
      );
    }
    if (width > model.widthMm || height > model.heightMm) {
      return CommandOutcome.failed(
        model,
        'A ${width.round()} × ${height.round()} mm opening does not fit inside a '
        '${model.widthMm.round()} × ${model.heightMm.round()} mm product.',
      );
    }

    final rect = anchor.place(model.outerRect, width, height);
    final placed = RegionEditor.placeRegion(
      model,
      rect,
      operation: operation,
      swing: operation.isOperable && !operation.isSliding
          ? SwingDirection.outward
          : SwingDirection.none,
      handle: operation.isOperable ? HandleStyle.lever : HandleStyle.none,
      label: label,
    );
    return CommandOutcome.done(placed.model, preview, selectedId: placed.id);
  }
}

/// "Make the right panel sliding." / "Keep the centre panel fixed."
class SetOperationCommand extends DesignCommand {
  final RegionSelector target;
  final CellOperation operation;

  const SetOperationCommand({required this.target, required this.operation});

  @override
  String get preview => 'Set ${target.describe()} to ${operation.label.toLowerCase()}';

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final resolved = _resolveTarget(model, target, selectedId);
    final id = resolved.id;
    if (id == null) {
      return CommandOutcome.failed(
        model,
        resolved.problem ?? 'I could not tell which section you mean.',
      );
    }
    return CommandOutcome.done(
      RegionEditor.setOperation(model, id, operation),
      preview,
      selectedId: id,
    );
  }
}

/// "Make the upper section glass."
class SetInfillCommand extends DesignCommand {
  final RegionSelector target;
  final CellInfill infill;

  const SetInfillCommand({required this.target, required this.infill});

  @override
  String get preview => 'Fill ${target.describe()} with ${infill.label.toLowerCase()}';

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final resolved = _resolveTarget(model, target, selectedId);
    final id = resolved.id;
    if (id == null) {
      return CommandOutcome.failed(
        model,
        resolved.problem ?? 'I could not tell which section you mean.',
      );
    }
    return CommandOutcome.done(
      RegionEditor.update(model, id, (r) => r.copyWith(infill: infill)),
      preview,
      selectedId: id,
    );
  }
}

/// "Move that opening to the top-right."
class MoveCommand extends DesignCommand {
  final RegionSelector target;
  final RegionAnchor anchor;

  const MoveCommand({required this.target, required this.anchor});

  @override
  String get preview => 'Move ${target.describe()} to the ${anchor.label}';

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final resolved = _resolveTarget(model, target, selectedId);
    final id = resolved.id;
    if (id == null) {
      return CommandOutcome.failed(
        model,
        resolved.problem ?? 'I could not tell which section to move.',
      );
    }
    final next = RegionEditor.anchor(model, id, anchor);
    if (next.region(id)!.rect == model.region(id)!.rect) {
      return CommandOutcome.failed(
        model,
        'That section is already at the ${anchor.label}.',
      );
    }
    return CommandOutcome.done(next, preview, selectedId: id);
  }
}

/// "Put the handle 100 cm from the floor."
class SetHandleHeightCommand extends DesignCommand {
  final RegionSelector target;
  final double heightMm;

  const SetHandleHeightCommand({required this.target, required this.heightMm});

  @override
  String get preview =>
      'Put the handle on ${target.describe()} ${heightMm.round()} mm from the floor';

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    var selector = target;
    if (selector.isEmpty) selector = const RegionSelector(operableOnly: true);
    final resolved = _resolveTarget(model, selector, selectedId);
    final id = resolved.id;
    if (id == null) {
      return CommandOutcome.failed(
        model,
        resolved.problem ?? 'I could not tell which opening leaf you mean.',
      );
    }
    if (heightMm <= 0 || heightMm >= model.heightMm) {
      return CommandOutcome.failed(
        model,
        'A handle ${heightMm.round()} mm from the floor is outside a '
        '${model.heightMm.round()} mm product.',
      );
    }
    return CommandOutcome.done(
      RegionEditor.update(
        model,
        id,
        (r) => r.copyWith(
          handleHeightMm: heightMm,
          handle: r.handle == HandleStyle.none ? HandleStyle.lever : r.handle,
        ),
      ),
      preview,
      selectedId: id,
    );
  }
}

/// "Make the left section 30 cm wider than the right section."
class RelativeSizeCommand extends DesignCommand {
  final RegionSelector target;
  final RegionSelector reference;
  final double deltaMm;
  final Axis2 axis;

  const RelativeSizeCommand({
    required this.target,
    required this.reference,
    required this.deltaMm,
    required this.axis,
  });

  @override
  String get preview {
    final word = axis == Axis2.vertical
        ? (deltaMm >= 0 ? 'wider' : 'narrower')
        : (deltaMm >= 0 ? 'taller' : 'shorter');
    return 'Make ${target.describe()} ${deltaMm.abs().round()} mm $word than '
        '${reference.describe()}';
  }

  @override
  CommandOutcome apply(OpeningModel model, {String? selectedId}) {
    final targetId = _targetId(model, target, selectedId);
    final referenceId = _targetId(model, reference, selectedId);
    if (targetId == null || referenceId == null || targetId == referenceId) {
      return CommandOutcome.failed(
        model,
        'I need two different sections to compare.',
      );
    }
    final targetRegion = model.region(targetId)!;
    final referenceRegion = model.region(referenceId)!;
    final targetExtent = axis == Axis2.vertical
        ? targetRegion.rect.width
        : targetRegion.rect.height;
    final referenceExtent = axis == Axis2.vertical
        ? referenceRegion.rect.width
        : referenceRegion.rect.height;

    // When the two sit side by side their combined size is fixed, so "30 cm
    // wider than" has to be solved rather than simply added: growing one takes
    // from the other, and a naive add would end up twice the difference asked.
    final adjacent = _sharesBoundary(targetRegion.rect, referenceRegion.rect, axis);
    final wanted = adjacent
        ? (targetExtent + referenceExtent + deltaMm) / 2
        : referenceExtent + deltaMm;
    final next = axis == Axis2.vertical
        ? RegionEditor.setWidth(model, targetId, wanted)
        : RegionEditor.setHeight(model, targetId, wanted);
    return CommandOutcome.done(next, preview, selectedId: targetId);
  }
}

/// Whether two sections touch along the axis being sized, which is what makes
/// their combined extent fixed.
bool _sharesBoundary(Box2 a, Box2 b, Axis2 axis) {
  const tolerance = 1.0;
  if (axis == Axis2.vertical) {
    final touching = (a.right - b.left).abs() < tolerance ||
        (b.right - a.left).abs() < tolerance;
    final overlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    return touching && overlap > tolerance;
  }
  final touching = (a.bottom - b.top).abs() < tolerance ||
      (b.bottom - a.top).abs() < tolerance;
  final overlap = math.min(a.right, b.right) - math.max(a.left, b.left);
  return touching && overlap > tolerance;
}

/// The section an instruction is about, or the reason it cannot be pinned down.
typedef _Target = ({String? id, String? problem});

_Target _resolveTarget(
  OpeningModel model,
  RegionSelector selector,
  String? selectedId,
) {
  final effective =
      selector.isEmpty && selectedId != null ? RegionSelector.selection : selector;
  if (effective.isEmpty) {
    // No selector at all: only sensible when the design is a single section.
    if (model.regions.length == 1) {
      return (id: model.regions.single.id, problem: null);
    }
    return (
      id: null,
      problem: 'There are ${model.regions.length} sections — say which one you '
          'mean, or tap it first.',
    );
  }
  final match = _resolver.resolve(model, effective, selectedId: selectedId);
  return (id: match.id, problem: match.problem);
}

String? _targetId(OpeningModel model, RegionSelector selector, String? selectedId) =>
    _resolveTarget(model, selector, selectedId).id;

String _percent(double fraction) => '${(fraction * 100).round()}%';

/// Millimetres from a number and a unit word.
double millimetresFrom(double value, String? unit) => switch (unit?.toLowerCase()) {
      'cm' => value * 10,
      'm' => value * 1000,
      'in' || 'inch' || 'inches' || '"' => value * 25.4,
      _ => value,
    };
