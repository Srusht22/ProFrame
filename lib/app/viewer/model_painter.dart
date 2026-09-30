import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry/vec2.dart';
import '../../domain/solid/camera.dart';
import '../../domain/solid/mesh.dart';
import '../../domain/solid/shading.dart';
import '../../domain/solid/studio.dart';
import '../theme/app_theme.dart';
import 'display_style.dart';

/// Paints the projected model, far faces first.
///
/// The scale is fixed by the model and the zoom, not by what happens to be
/// on screen. A painter that refits every frame cancels out panning and
/// zooming, and makes the model feel like a picture being resized rather
/// than an object being looked at.
class ModelPainter extends CustomPainter {
  final List<ProjectedFacet> faces;
  final Size size;
  final String? selectedId;

  /// Everything else outlined with the selection.
  ///
  /// An opening is one thing made of several: its sash, the bars drawn in
  /// it, the panes those bars make, its hinges and its handle. Picking it
  /// picks all of that, so all of it is outlined — otherwise the model shows
  /// a sash ring lit up with its own glass and its own panel dark inside it,
  /// which says the opposite of what the design means. The set comes from
  /// the design's own hierarchy; nothing here works out what belongs to what.
  final Set<String> highlighted;

  final DisplayStyle style;
  final bool groundPlane;

  /// The floor the model stands on, as the eye sees it — its grid and its
  /// shadow. Null where there is none to show: seen from beneath, or not
  /// asked for.
  final ProjectedFloor? floor;

  /// The colours of the appearance in effect — for what the application
  /// draws over the model, the outline of what is picked. The model itself
  /// is shown in the [studio], never in these.
  final Palette palette;

  /// View units across the model. Fixed by the model, not by the zoom and
  /// not by what happens to be on screen.
  final double viewSpan;

  const ModelPainter({
    required this.faces,
    required this.size,
    required this.viewSpan,
    required this.style,
    this.groundPlane = true,
    this.floor,
    this.selectedId,
    this.highlighted = const {},
    this.palette = Palette.light,
  });

  /// Pixels per view unit.
  double get _scale {
    final fit = math.min(size.width, size.height);
    if (viewSpan <= 0 || fit <= 0) return 1;
    return fit * Camera.spanShare / viewSpan;
  }

  Offset get _centre => Offset(size.width / 2, size.height / 2);

  Offset _place(Vec2 at) =>
      Offset(_centre.dx + at.x * _scale, _centre.dy + at.y * _scale);

  Path _pathOf(ProjectedFacet face) {
    final path = Path();
    final first = _place(face.corners.first);
    path.moveTo(first.dx, first.dy);
    for (final corner in face.corners.skip(1)) {
      final at = _place(corner);
      path.lineTo(at.dx, at.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _backdrop(canvas, size);
    if (faces.isEmpty) return;
    if (groundPlane && floor != null) _floor(canvas, floor!);

    final lit = {...highlighted, ?selectedId};
    // Each piece of ironmongery's shadow, gathered by what it falls on —
    // the leaf, for a plate; the plate, for what stands on it — and laid
    // down just before the first of what casts it is painted: after what it
    // falls on, and under what casts it.
    final shadows = <String, List<ProjectedFacet>>{};
    final known = <ProjectedFacet, Rect>{};
    if (style.usesFinishes && style.drawsFaces) {
      for (final face in faces) {
        if (face.shadow != null) {
          (shadows[_castOnto(face)] ??= []).add(face);
        }
      }
    }
    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      final path = _pathOf(face);
      if (face.shadow != null) {
        if (shadows.remove(_castOnto(face)) case final cast?) {
          _shadow(canvas, cast, faces.sublist(0, i), known);
        }
      }
      // A sheet of glass is kept off what lies in front of it, whatever
      // order the sort gave the two (see `ProjectedFacet.hiders`).
      final keptOff = style.drawsFaces && face.hiders.isNotEmpty;
      if (keptOff) {
        // One clip for each face in front — the view with that face's
        // outline cut out, filled even-odd — and clips meet, so what is left
        // is the view with all of them cut out. No path difference: the
        // web's renderer does not take one the way the others do.
        canvas.save();
        for (final hider in face.hiders) {
          if (hider.length < 3) continue;
          canvas.clipPath(
            Path()
              ..fillType = PathFillType.evenOdd
              ..addRect(Offset.zero & size)
              ..addPolygon([for (final c in hider) _place(c)], true),
          );
        }
      }
      if (style.drawsFaces) _face(canvas, path, face);
      if (style.drawsEdges && !_isSmooth(face)) _edges(canvas, path, face);
      if (style == DisplayStyle.wireframe && _isSmooth(face)) {
        _edges(canvas, path, face);
      }
      if (keptOff) canvas.restore();
      if (lit.contains(face.elementId)) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = palette.selection,
        );
      }
    }
  }

  /// The studio the model is shown in: light or dark as the application
  /// is, and neutral either way.
  Studio get studio => Studio.of(dark: palette.isDark);

  /// A seamless sweep, lighter above, with no horizon drawn on it: nothing
  /// behind the model to look at but the model.
  void _backdrop(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          Color(studio.backdropTop),
          Color(studio.backdropBottom),
        ]),
    );
  }

  /// The floor the model stands on: its shadow, then its grid, all before
  /// the model, so neither can lie over any part of the design.
  ///
  /// The shadow is laid down point by point across the floor, as dark as
  /// `Floor` says the light it takes away is, and blended between them. The
  /// grid fades as the floor does, and as the floor turns edge on — where
  /// its lines would crowd into one — and its ten-centimetre lines only
  /// show where they are far enough apart to be told from each other.
  void _floor(Canvas canvas, ProjectedFloor floor) {
    final seen = _smoothstep(0.03, 0.25, floor.facing);
    final minorApart = _smoothstep(5, 12, floor.stepSeen * _scale);
    final ink = Color(studio.lines);
    for (final major in [false, true]) {
      final strength =
          seen * (major ? studio.majorLines : studio.minorLines * minorApart);
      if (strength <= 0.002) continue;
      // Gathered by how strongly each piece shows, a few steps of it, and
      // each step drawn at once.
      const steps = 12;
      final paths = List.generate(steps + 1, (_) => Path());
      for (final line in floor.lines) {
        if (line.major != major) continue;
        final from = _place(line.from), to = _place(line.to);
        paths[(line.weight * steps).round()]
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      }
      for (var k = 1; k <= steps; k++) {
        canvas.drawPath(
          paths[k],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = major ? 1.0 : 0.8
            ..color = ink.withValues(alpha: strength * k / steps),
        );
      }
    }

    final across = floor.columns;
    final rows = floor.rows;
    if (across < 2 || rows < 2) return;
    final points = <Offset>[];
    final colours = <Color>[];
    final index = <int, int>{};
    for (var k = 0; k < floor.points.length; k++) {
      final at = floor.points[k];
      if (at == null) continue;
      index[k] = points.length;
      points.add(_place(at));
      colours.add(Color.fromARGB((floor.darkness[k] * 255).round(), 0, 0, 0));
    }
    final triangles = <int>[];
    for (var j = 0; j + 1 < rows; j++) {
      for (var i = 0; i + 1 < across; i++) {
        final a = index[j * across + i], b = index[j * across + i + 1];
        final c = index[(j + 1) * across + i];
        final d = index[(j + 1) * across + i + 1];
        if (a == null || b == null || c == null || d == null) continue;
        triangles.addAll([a, b, d, a, d, c]);
      }
    }
    if (triangles.isEmpty) return;
    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        points,
        colors: colours,
        indices: triangles,
      ),
      BlendMode.dst,
      Paint(),
    );
  }

  static double _smoothstep(double from, double to, double v) {
    final t = ((v - from) / (to - from)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// How [face] looks: its material under the light, from `Shading.of` —
  /// the one place that decides how glass, panel, frame, metal and rubber
  /// look. Nothing here chooses a colour.
  ///
  /// The light is the same in either appearance: the backdrop darkens with
  /// the app, the design's own finishes do not.
  ///
  /// [corner] shades the face as seen at that corner, along the eye's own
  /// ray to it; without it, the face is shaded as seen at its middle.
  Shaded shadeOf(
    ProjectedFacet face, {
    int? corner,
    Vec3? view,
    Vec3? normal,
    double occlusion = 0,
    double shadowed = 0,
  }) {
    final source = face.source;
    return Shading.of(
      surface: style.usesFinishes
          ? source.surface
          : Shading.clay(source.surface),
      colour: style.usesFinishes ? source.colour : _clay,
      normal: normal ?? face.normal,
      environment: Environment.daylight,
      side: source.isSide,
      view:
          view ??
          (corner == null ? _towardsEye(face) : face.towardsEyeFrom(corner)),
      skyward: face.skyward,
      occlusion: occlusion,
      shadowed: shadowed,
      glassFaces: source.glassFaces,
    );
  }

  /// The way to the eye from the middle of [face].
  static Vec3 _towardsEye(ProjectedFacet face) {
    final n = face.eyeCorners.length;
    if (n == 0) return const Vec3(0, 0, 1);
    var sum = Vec3.zero;
    for (var k = 0; k < n; k++) {
      sum = sum + face.towardsEyeFrom(k);
    }
    return sum.normalised;
  }

  /// Whether [face] is seen through — the face of a pane, not its thin side
  /// — and so is shaded at every corner rather than once.
  static bool _seenThrough(ProjectedFacet face) =>
      face.source.surface.isTransparent &&
      !face.source.isSide &&
      face.eyeCorners.length == face.corners.length &&
      face.corners.length >= 3;

  /// The one colour a monochrome view is in: the studio's grey.
  static const _clay = Studio.clay;

  /// A face, in the three layers `Shaded` describes: what it lets through
  /// multiplies what is behind it, what it shows of itself is laid over,
  /// and what it reflects is added.
  void _face(Canvas canvas, Path path, ProjectedFacet face) {
    if (_seenThrough(face)) {
      _pane(canvas, face);
      return;
    }
    if (_setIn(face)) {
      _recessed(canvas, face);
      return;
    }
    if (_isSmooth(face)) {
      _smooth(canvas, face);
      return;
    }
    final shaded = shadeOf(face);
    if (shaded.filter case final filter?) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.multiply
          ..color = Color(filter),
      );
    }
    if (shaded.opacity > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Color(shaded.colour).withValues(alpha: shaded.opacity),
      );
    }
    if (shaded.reflection case final reflection?) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.plus
          ..color = Color(reflection),
      );
    }
  }

  /// A face of a pane, shaded point by point.
  ///
  /// Glass is the one surface whose look changes across a single flat face.
  /// In a perspective view the eye meets each point of it at its own angle,
  /// so what it reflects — the studio's softbox as a sheen, the sky, the
  /// ground — lies across the pane where it really falls, and moves as the
  /// view turns; and how much it reflects rather than lets through, more at
  /// a glance than square on, changes from one side of it to the other.
  /// Shaded once, a pane is a flat tinted card.
  ///
  /// So a four-sided face is shaded at every point of a fine grid across it
  /// and blended between them — in the same three layers as every face
  /// (`Shaded`): what it lets through multiplies what is behind, what it
  /// scatters is laid over, what it reflects is added.
  void _pane(Canvas canvas, ProjectedFacet face) {
    final n = face.corners.length;
    final at = [for (final c in face.corners) _place(c)];
    final List<Offset> points;
    final List<Shaded> shades;
    final List<int> triangles;
    if (n == 4) {
      points = [];
      shades = [];
      final eye = face.viewer;
      final e = face.eyeCorners;
      for (var j = 0; j <= _grid; j++) {
        for (var i = 0; i <= _grid; i++) {
          final u = i / _grid, v = j / _grid;
          Offset flat(List<Offset> c) =>
              (c[0] * (1 - u) + c[1] * u) * (1 - v) +
              (c[3] * (1 - u) + c[2] * u) * v;
          points.add(flat(at));
          final where =
              e[0] * ((1 - u) * (1 - v)) +
              e[1] * (u * (1 - v)) +
              e[2] * (u * v) +
              e[3] * ((1 - u) * v);
          shades.add(
            shadeOf(
              face,
              view: eye == null
                  ? const Vec3(0, 0, 1)
                  : (eye - where).normalised,
            ),
          );
        }
      }
      triangles = [
        for (var j = 0; j < _grid; j++)
          for (var i = 0; i < _grid; i++) ...[
            j * (_grid + 1) + i,
            j * (_grid + 1) + i + 1,
            (j + 1) * (_grid + 1) + i + 1,
            j * (_grid + 1) + i,
            (j + 1) * (_grid + 1) + i + 1,
            (j + 1) * (_grid + 1) + i,
          ],
      ];
    } else {
      points = at;
      shades = [for (var k = 0; k < n; k++) shadeOf(face, corner: k)];
      triangles = [
        for (var k = 1; k + 1 < n; k++) ...[0, k, k + 1],
      ];
    }

    void layer(List<Color> colours, BlendMode mode) => canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        points,
        colors: colours,
        indices: triangles,
      ),
      // The vertices' own colours, laid on the canvas by [mode].
      BlendMode.dst,
      Paint()..blendMode = mode,
    );

    if (shades.every((s) => s.filter != null)) {
      layer([for (final s in shades) Color(s.filter!)], BlendMode.multiply);
    }
    if (shades.any((s) => s.opacity > 0)) {
      layer([
        for (final s in shades) Color(s.colour).withValues(alpha: s.opacity),
      ], BlendMode.srcOver);
    }
    if (shades.every((s) => s.reflection != null)) {
      layer([for (final s in shades) Color(s.reflection!)], BlendMode.plus);
    }
  }

  /// Whether [face] is set below what stands round it — a panel in its
  /// sash — and so is shaded across for the step it is set in.
  static bool _setIn(ProjectedFacet face) =>
      !face.source.surface.isTransparent &&
      face.corners.length == 4 &&
      face.source.recesses.length == 4 &&
      face.source.recesses.any((r) => r > 0) &&
      face.eyeCorners.length == 4;

  /// A face set in a recess — a panel in its sash or its frame — shaded
  /// point by point for the step round it.
  ///
  /// A solid panel reads as one because of what its surroundings do to the
  /// light on it: towards each edge, the sash or the frame standing proud of
  /// it hides part of the sky, so it darkens gently into the corner; and on
  /// the side the light comes from, the step throws a sharp shadow across
  /// it. Neither is painted on: both are worked out at every point from how
  /// far it is from each edge, how high that edge's step is
  /// (`Facet.recesses`) and where the light is. The grid is fine near the
  /// edges, where that changes within millimetres, and coarse across the
  /// middle, where it does not.
  void _recessed(Canvas canvas, ProjectedFacet face) {
    final e = face.eyeCorners;
    final at = [for (final c in face.corners) _place(c)];
    final steps = face.source.recesses;
    final light = Environment.daylight.light;
    final eye = face.viewer;

    // The face's own way out towards the viewer, and each edge's way out of
    // the face, across its step.
    final centre = (e[0] + e[1] + e[2] + e[3]) * 0.25;
    var normal = face.normal.normalised;
    final toViewer = eye == null ? const Vec3(0, 0, 1) : eye - centre;
    if (normal.dot(toViewer) < 0) normal = normal * -1;
    final outs = <Vec3>[];
    for (var k = 0; k < 4; k++) {
      final a = e[k], b = e[(k + 1) % 4];
      final along = (b - a).normalised;
      var out = normal.cross(along).normalised;
      if (out.dot(centre - a) > 0) out = out * -1;
      outs.add(out);
    }

    List<double> spacing(double length) {
      final half = length / 2;
      final near = <double>[
        for (final mm in const [0.0, 0.6, 1.3, 2, 3, 4.5, 6.5, 9, 12, 16, 22,
            30, 42, 60, 85, 120])
          if (mm < half) mm / length,
      ];
      return {
        ...near,
        for (var i = 1; i < 8; i++) i / 8,
        for (final t in near) 1 - t,
      }.toList()
        ..sort();
    }

    final us = spacing((e[1] - e[0]).length);
    final vs = spacing((e[3] - e[0]).length);
    final points = <Offset>[];
    final shades = <Shaded>[];
    for (final v in vs) {
      for (final u in us) {
        Offset flat(List<Offset> c) =>
            (c[0] * (1 - u) + c[1] * u) * (1 - v) +
            (c[3] * (1 - u) + c[2] * u) * v;
        final p =
            e[0] * ((1 - u) * (1 - v)) +
            e[1] * (u * (1 - v)) +
            e[2] * (u * v) +
            e[3] * ((1 - u) * v);
        var occlusion = 0.0, shadowed = 0.0;
        for (var k = 0; k < 4; k++) {
          final step = recess(
            depth: steps[k],
            away: (p - e[k]).dot(outs[k] * -1),
            out: outs[k],
            normal: normal,
            light: light,
          );
          occlusion += step.occlusion;
          shadowed = math.max(shadowed, step.shadowed);
        }
        points.add(flat(at));
        shades.add(
          shadeOf(
            face,
            view: eye == null ? const Vec3(0, 0, 1) : (eye - p).normalised,
            occlusion: math.min(occlusion, 0.75),
            shadowed: shadowed,
          ),
        );
      }
    }
    final across = us.length;
    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        points,
        colors: [for (final s in shades) Color(s.colour)],
        indices: [
          for (var j = 0; j + 1 < vs.length; j++)
            for (var i = 0; i + 1 < across; i++) ...[
              j * across + i,
              j * across + i + 1,
              (j + 1) * across + i + 1,
              j * across + i,
              (j + 1) * across + i + 1,
              (j + 1) * across + i,
            ],
        ],
      ),
      BlendMode.dst,
      Paint(),
    );
  }

  /// How finely a pane is shaded across: a point every tenth of the way,
  /// enough for a sheen to have a shape and too few to cost anything.
  static const _grid = 10;

  /// Which piece of ironmongery [face] is part of — the part, where a piece
  /// is built on both faces of its leaf — and what it casts its shadow on.
  static String _castOnto(ProjectedFacet face) {
    final on = face.source.mountAt;
    return '${face.elementId}|${face.source.part ?? ''}|'
        '${on?.x},${on?.y},${on?.z}';
  }

  /// Whether [face] is one facet of a curved surface — it carries the way
  /// the surface faces at each of its corners, and they differ — and so is
  /// shaded across by them rather than once.
  static bool _isSmooth(ProjectedFacet face) {
    final normals = face.cornerNormals;
    if (normals.length != face.corners.length ||
        face.corners.length < 3 ||
        face.eyeCorners.length != face.corners.length ||
        face.source.surface.isTransparent) {
      return false;
    }
    for (final n in normals) {
      if (n.dot(normals.first) < 0.9999) return true;
    }
    return false;
  }

  /// One facet of a curved surface — a lever, a knuckle, the rounded rim of
  /// a plate — shaded point by point from the way the surface faces there.
  ///
  /// The surface is round; the facet only stands in for part of it. Lit once,
  /// a lever is a prism with a stripe on each flat, and a polished one never
  /// shows the one thing that says it is polished: a highlight running along
  /// it where the light and the eye meet. So the way the surface faces is
  /// blended across the facet from its corners, and every point is lit by
  /// `Shading.of` as it faces — including what it mirrors of the studio.
  void _smooth(Canvas canvas, ProjectedFacet face) {
    final n = face.corners.length;
    final at = [for (final c in face.corners) _place(c)];
    final normals = face.cornerNormals;
    final e = face.eyeCorners;
    final eye = face.viewer;

    Shaded shadeAt(Vec3 where, Vec3 facing) {
      final view = eye == null
          ? const Vec3(0, 0, 1)
          : (eye - where).normalised;
      // At the silhouette the surface turns away from the eye; what is seen
      // there is the surface edge on, not its far side lit from behind.
      var normal = facing.normalised;
      final towards = normal.dot(view);
      if (towards < 0.02) normal = (normal + view * (0.02 - towards)).normalised;
      return shadeOf(face, view: view, normal: normal);
    }

    final List<Offset> points;
    final List<Shaded> shades;
    final List<int> triangles;
    if (n == 4) {
      // As finely as the facet is large on the screen: a cell never finer
      // than [_smoothCell] pixels, and never coarser than [_smoothSteps]
      // across. A knuckle's facet a few pixels wide is lit at its corners;
      // a lever filling the view gets the whole grid, where its highlight is
      // seen. The grid was the whole grid for every facet, and lighting a
      // few thousand points nobody could tell apart was most of what a
      // frame of the model cost.
      var span = 0.0;
      for (var k = 0; k < 4; k++) {
        span = math.max(span, (at[k] - at[(k + 1) % 4]).distance);
      }
      final steps = (span / _smoothCell).ceil().clamp(1, _smoothSteps);
      points = [];
      shades = [];
      for (var j = 0; j <= steps; j++) {
        for (var i = 0; i <= steps; i++) {
          final u = i / steps, v = j / steps;
          final w = [(1 - u) * (1 - v), u * (1 - v), u * v, (1 - u) * v];
          var where = Vec3.zero, facing = Vec3.zero;
          var flat = Offset.zero;
          for (var k = 0; k < 4; k++) {
            where = where + e[k] * w[k];
            facing = facing + normals[k] * w[k];
            flat = flat + at[k] * w[k];
          }
          points.add(flat);
          shades.add(shadeAt(where, facing));
        }
      }
      triangles = [
        for (var j = 0; j < steps; j++)
          for (var i = 0; i < steps; i++) ...[
            j * (steps + 1) + i,
            j * (steps + 1) + i + 1,
            (j + 1) * (steps + 1) + i + 1,
            j * (steps + 1) + i,
            (j + 1) * (steps + 1) + i + 1,
            (j + 1) * (steps + 1) + i,
          ],
      ];
    } else {
      // A fan from the middle, so a many-sided face is shaded from its
      // centre out.
      var middle = Vec3.zero, facing = Vec3.zero;
      var flat = Offset.zero;
      for (var k = 0; k < n; k++) {
        middle = middle + e[k] * (1 / n);
        facing = facing + normals[k];
        flat = flat + at[k] / n.toDouble();
      }
      points = [flat, ...at];
      shades = [
        shadeAt(middle, facing),
        for (var k = 0; k < n; k++) shadeAt(e[k], normals[k]),
      ];
      triangles = [
        for (var k = 0; k < n; k++) ...[0, k + 1, (k + 1) % n + 1],
      ];
    }
    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        points,
        colors: [for (final s in shades) Color(s.colour)],
        indices: triangles,
      ),
      BlendMode.dst,
      Paint(),
    );
  }

  /// How finely a curved facet is shaded across, each way: enough that a
  /// highlight a few degrees wide lands between its corners and is seen.
  static const _smoothSteps = 6;

  /// The smallest cell, in pixels, a curved facet is shaded across in: a
  /// highlight narrower than this is not seen on a screen.
  static const _smoothCell = 4.0;

  /// A piece of ironmongery's shadow on the face of the leaf it is fixed to.
  ///
  /// Where the key light is stopped by the piece, the leaf behind it gets
  /// only the light the rest of the sky gives it — so the shadow takes away
  /// the key light's share of what that face is lit by, and no more: a
  /// multiply, never a painted black. Its edge is soft by the size of the
  /// light, and a piece fixed to a face the light does not reach casts none
  /// (`Camera.project` leaves its shadow out).
  void _shadow(
    Canvas canvas,
    List<ProjectedFacet> cast,
    List<ProjectedFacet> beneath,
    Map<ProjectedFacet, Rect> known,
  ) {
    // What the shadow takes away is the key light's share of what that face
    // is lit by — the same light `Shading.of` lights it with — and no more.
    final environment = Environment.daylight;
    final onto = cast.first.shadowNormal ?? const Vec3(0, 0, 1);
    final up = cast.first.skyward;
    final all = environment.lightOn(onto, up: up);
    final kept = all <= 0
        ? 1.0
        : environment.lightOn(onto, up: up, shadowed: 1) / all;
    final g = (kept * 255).round().clamp(0, 255);
    // Soft by the size of the light: a shadow cast close is crisp, one cast
    // far spreads and fades, because the key light is a window of sky and
    // not a point.
    var reach = 0.0;
    for (final face in cast) {
      reach += face.shadowReach / cast.length;
    }
    final soft =
        (_scale * (_penumbra + reach * environment.keySize / 2)).clamp(
          0.6,
          24.0,
        );

    // The facets of a round part face both ways once flattened, so their
    // shadows are drawn one by one, opaque, into a layer of their own —
    // which makes them one shadow, never two overlapping ones or a hole
    // where a front and a back cancel — and the layer is then laid on the
    // leaf softened, by multiplying.
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    final paths = <Path>[];
    for (final face in cast) {
      final path = Path();
      final corners = face.shadow!;
      final first = _place(corners.first);
      path.moveTo(first.dx, first.dy);
      for (final c in corners) {
        final at = _place(c);
        path.lineTo(at.dx, at.dy);
        left = math.min(left, at.dx);
        top = math.min(top, at.dy);
        right = math.max(right, at.dx);
        bottom = math.max(bottom, at.dy);
      }
      path.close();
      paths.add(path);
    }
    if (!left.isFinite) return;
    final bounds = Rect.fromLTRB(left, top, right, bottom).inflate(soft * 3);

    // **A shadow falls only on what can take one.** Light passes through
    // clear glass, so a pane takes no shadow, and what is seen through it
    // is not in the shadow either. So the shadow is kept to the solid faces
    // already painted where it falls, less any glass painted over them —
    // as a mask, in the order they were painted: each solid face laid into
    // it, each pane of glass cleared out of it. It used to be one clip made
    // by joining and cutting paths (`Path.combine`), which cost more than
    // painting the rest of the model, and which the web's renderer does not
    // take the way the others do.
    var any = false;
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.multiply);
    final solid = Paint()..color = Colors.white;
    final clear = Paint()..blendMode = BlendMode.clear;
    for (final face in beneath) {
      if (!_boundsOf(face, known).overlaps(bounds)) continue;
      if (face.source.surface.isTransparent && !face.source.isSide) {
        if (any) canvas.drawPath(_pathOf(face), clear);
      } else {
        canvas.drawPath(_pathOf(face), solid);
        any = true;
      }
    }
    if (any) {
      canvas.saveLayer(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcIn
          ..imageFilter = ui.ImageFilter.blur(sigmaX: soft, sigmaY: soft),
      );
      canvas.drawRect(bounds, Paint()..color = Colors.white);
      final dark = Paint()..color = Color.fromARGB(255, g, g, g);
      for (final path in paths) {
        canvas.drawPath(path, dark);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  /// Where [face] lands on the screen, kept in [known] — every shadow asks
  /// it of every face painted before it, so each is worked out once a
  /// picture.
  Rect _boundsOf(ProjectedFacet face, Map<ProjectedFacet, Rect> known) =>
      known[face] ??= () {
        var left = double.infinity, top = double.infinity;
        var right = -double.infinity, bottom = -double.infinity;
        for (final c in face.corners) {
          final at = _place(c);
          left = math.min(left, at.dx);
          top = math.min(top, at.dy);
          right = math.max(right, at.dx);
          bottom = math.max(bottom, at.dy);
        }
        return Rect.fromLTRB(left, top, right, bottom);
      }();

  /// How soft a shadow's edge is where it touches what casts it, in
  /// millimetres of the model.
  static const _penumbra = 0.8;


  /// A face's edges, as its material shows them: hard and dark on an
  /// extrusion or a metal, barely there on glass, which is seen through.
  void _edges(Canvas canvas, Path path, ProjectedFacet face) {
    if (style == DisplayStyle.wireframe) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          // A wireframe has no faces; its edges are read against the
          // studio's backdrop.
          ..color = Color(studio.lines).withValues(alpha: 0.5),
      );
      return;
    }
    final darkness = face.source.surface.edge.darkness;
    final own = Color(shadeOf(face).colour);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        // Edges between faces are dark in either appearance, because the
        // faces are the design's own colours — and neutral, because they
        // are the model's and not the application's.
        ..color = Color.lerp(own, const Color(Studio.edgeInk), darkness)!
            .withValues(alpha: 0.35 + 0.45 * darkness),
    );
  }

  /// Which part of the design is under [pixel] — the nearest face, since the
  /// list is painted far to near.
  String? elementAt(Offset pixel) => faceAt(pixel)?.elementId;

  /// The face painted uppermost at [pixel]: the nearest, since the list is
  /// painted far to near — and never a sheet of glass where it is kept off
  /// what lies in front of it.
  ProjectedFacet? faceAt(Offset pixel) {
    for (final face in faces.reversed) {
      if (!_pathOf(face).contains(pixel)) continue;
      if (style.drawsFaces &&
          face.hiders.isNotEmpty &&
          _outlinesOf(face.hiders).contains(pixel)) {
        continue;
      }
      return face;
    }
    return null;
  }

  /// [outlines] as one shape: every one turned the same way round, so where
  /// they overlap is still inside rather than cancelling out.
  Path _outlinesOf(List<List<Vec2>> outlines) {
    final path = Path();
    for (final outline in outlines) {
      if (outline.length < 3) continue;
      var area = 0.0;
      for (var k = 0; k < outline.length; k++) {
        final a = outline[k], b = outline[(k + 1) % outline.length];
        area += a.x * b.y - b.x * a.y;
      }
      final points = [
        for (final c in area < 0 ? outline.reversed : outline) _place(c),
      ];
      path.addPolygon(points, true);
    }
    return path;
  }

  /// How many millimetres of model one pixel covers, for turning a drag into
  /// a pan.
  double get millimetresPerPixel => _scale <= 0 ? 1 : 1 / _scale;

  /// Whether what is on the screen is still this picture.
  ///
  /// Asked of everything painted, face by face. It used to look at the
  /// number of faces and the first face alone, and a change of colour, of
  /// glass, or of where a handle is leaves both of those as they were — so
  /// the model on the screen went on showing the design as it had been. The
  /// comparison is a pass over the faces, far cheaper than painting them.
  @override
  bool shouldRepaint(ModelPainter old) =>
      old.selectedId != selectedId ||
      !setEquals(old.highlighted, highlighted) ||
      old.size != size ||
      old.style != style ||
      old.groundPlane != groundPlane ||
      old.floor != floor ||
      old.palette != palette ||
      old.viewSpan != viewSpan ||
      !_samePicture(old.faces, faces);

  static bool _samePicture(List<ProjectedFacet> a, List<ProjectedFacet> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final p = a[i], q = b[i];
      if (identical(p, q)) continue;
      final f = p.source, g = q.source;
      if (p.depth != q.depth ||
          p.light != q.light ||
          p.hiders.length != q.hiders.length ||
          (p.shadow == null) != (q.shadow == null) ||
          p.corners.length != q.corners.length ||
          f.elementId != g.elementId ||
          f.colour != g.colour ||
          f.surface != g.surface ||
          f.transparency != g.transparency ||
          f.gloss != g.gloss ||
          f.role != g.role ||
          f.part != g.part ||
          f.isSide != g.isSide ||
          f.glassFaces != g.glassFaces) {
        return false;
      }
      for (var k = 0; k < p.corners.length; k++) {
        if (p.corners[k].x != q.corners[k].x ||
            p.corners[k].y != q.corners[k].y) {
          return false;
        }
      }
    }
    return true;
  }
}
