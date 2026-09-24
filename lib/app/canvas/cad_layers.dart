import 'package:flutter/foundation.dart';

/// What the technical drawing is showing.
///
/// Layers are a way of looking at one drawing, not versions of it. Turning
/// the hatching off does not change what anything is made of, and turning
/// the dimensions off does not change a single size.
@immutable
class CadLayers {
  final bool grid;
  final bool dimensions;
  final bool hatching;
  final bool openings;
  final bool centreLines;
  final bool annotations;

  /// The user's own marks, faint underneath, so the drawing can be checked
  /// against the hand that made it.
  final bool sketch;

  /// The handles for changing a boundary.
  final bool grips;

  /// Whether a drag lands on the geometry that is already there.
  final bool snap;

  /// What is on the face the drawing is not of — a door's hinges, which
  /// are round the back — drawn dashed, as a joiner's hidden detail.
  ///
  /// Off unless asked for: the drawing is of the face you are standing at,
  /// and from there those pieces cannot be seen.
  final bool hiddenDetail;

  const CadLayers({
    this.grid = true,
    this.dimensions = true,
    this.hatching = true,
    this.openings = true,
    this.centreLines = false,
    this.annotations = true,
    this.sketch = false,
    this.grips = true,
    this.snap = true,
    this.hiddenDetail = false,
  });

  CadLayers copyWith({
    bool? grid,
    bool? dimensions,
    bool? hatching,
    bool? openings,
    bool? centreLines,
    bool? annotations,
    bool? sketch,
    bool? grips,
    bool? snap,
    bool? hiddenDetail,
  }) =>
      CadLayers(
        grid: grid ?? this.grid,
        dimensions: dimensions ?? this.dimensions,
        hatching: hatching ?? this.hatching,
        openings: openings ?? this.openings,
        centreLines: centreLines ?? this.centreLines,
        annotations: annotations ?? this.annotations,
        sketch: sketch ?? this.sketch,
        grips: grips ?? this.grips,
        snap: snap ?? this.snap,
        hiddenDetail: hiddenDetail ?? this.hiddenDetail,
      );

  @override
  bool operator ==(Object other) =>
      other is CadLayers &&
      other.grid == grid &&
      other.dimensions == dimensions &&
      other.hatching == hatching &&
      other.openings == openings &&
      other.centreLines == centreLines &&
      other.annotations == annotations &&
      other.sketch == sketch &&
      other.grips == grips &&
      other.snap == snap &&
      other.hiddenDetail == hiddenDetail;

  @override
  int get hashCode => Object.hash(
        grid,
        dimensions,
        hatching,
        openings,
        centreLines,
        annotations,
        sketch,
        grips,
        snap,
        hiddenDetail,
      );
}
