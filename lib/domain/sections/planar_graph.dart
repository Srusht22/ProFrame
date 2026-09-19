import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';

/// A node where lines meet.
class _Node {
  final Vec2 at;
  final List<_HalfEdge> out = [];
  _Node(this.at);
}

/// One direction along one edge. Every edge gets two, pointing opposite ways.
class _HalfEdge {
  final _Node from;
  final _Node to;
  late final _HalfEdge twin;
  bool used = false;

  _HalfEdge(this.from, this.to);

  /// The direction this half-edge leaves its node in.
  double get heading => math.atan2(to.at.y - from.at.y, to.at.x - from.at.x);
}

/// What the lines enclose: the areas inside, and the outline around them.
class PlanarFaces {
  /// Every area the lines enclose.
  final List<Polygon> faces;

  /// The outline of everything the lines enclose, as drawn — five-sided if
  /// the user drew five sides. Null when the lines enclose nothing.
  final Polygon? outline;

  const PlanarFaces({required this.faces, this.outline});
}

/// Turns a pile of line segments into the areas they enclose.
///
/// This is what makes the drawing the design. The user's lines are split
/// wherever they cross, the pieces are joined into a graph, and the faces of
/// that graph are the sections. Nothing is assumed about how many there are,
/// where they sit, or whether they are equal: a diagonal makes triangles, a
/// line stopping short of another still divides, and an unequal split stays
/// unequal.
abstract final class PlanarSubdivision {
  /// The closed areas enclosed by [segments], smallest-first ordering left to
  /// the caller.
  ///
  /// Returns an empty list when the lines enclose nothing.
  static List<Polygon> facesOf(
    List<Segment> segments, {
    double weldTolerance = Tol.samePointMm,
    double minAreaMmSq = Tol.minSectionAreaMmSq,
  }) =>
      subdivide(
        segments,
        weldTolerance: weldTolerance,
        minAreaMmSq: minAreaMmSq,
      ).faces;

  /// The areas enclosed by [segments], and the outline around all of them.
  static PlanarFaces subdivide(
    List<Segment> segments, {
    double weldTolerance = Tol.samePointMm,
    double minAreaMmSq = Tol.minSectionAreaMmSq,
  }) {
    final pieces = _split(segments, weldTolerance);
    if (pieces.isEmpty) return const PlanarFaces(faces: []);

    final nodes = <_Node>[];
    _Node nodeAt(Vec2 point) {
      for (final n in nodes) {
        if (n.at.distanceTo(point) <= weldTolerance) return n;
      }
      final created = _Node(point);
      nodes.add(created);
      return created;
    }

    final links = <(_Node, _Node)>[];
    for (final piece in pieces) {
      final from = nodeAt(piece.a);
      final to = nodeAt(piece.b);
      if (identical(from, to)) continue;
      if (links.any((l) =>
          (identical(l.$1, from) && identical(l.$2, to)) ||
          (identical(l.$1, to) && identical(l.$2, from)))) {
        continue;
      }
      links.add((from, to));
    }

    // A line drawn past the corner it was heading for leaves a stub sticking
    // out, and a line that reaches nothing at all is a stub the whole way.
    // Neither encloses anything, and both would otherwise be walked out and
    // back again as part of the outline, putting a spike in the frame. Take
    // them off until only the parts that close remain.
    _pruneLooseEnds(links);
    if (links.isEmpty) return const PlanarFaces(faces: []);

    for (final (from, to) in links) {
      final forward = _HalfEdge(from, to);
      final backward = _HalfEdge(to, from);
      forward.twin = backward;
      backward.twin = forward;
      from.out.add(forward);
      to.out.add(backward);
    }

    // Order the half-edges leaving each node by angle, so "the next edge
    // clockwise" is a lookup rather than a search.
    for (final node in nodes) {
      node.out.sort((a, b) => a.heading.compareTo(b.heading));
    }

    final faces = <Polygon>[];
    Polygon? outline;
    for (final node in nodes) {
      for (final start in node.out) {
        if (start.used) continue;
        final face = _walk(start);
        if (face == null) continue;
        // Every bounded face comes out of this traversal with one
        // orientation, and the unbounded face that wraps the whole drawing
        // comes out with the other. That one is the outline.
        if (face.signedArea <= 0) {
          if (outline == null || face.area > outline.area) {
            outline = face.reversed;
          }
          continue;
        }
        if (face.area < minAreaMmSq) continue;
        faces.add(face);
      }
    }
    return PlanarFaces(faces: faces, outline: outline);
  }

  /// Repeatedly drops every link with a free end, until every link that is
  /// left is part of something closed.
  static void _pruneLooseEnds(List<(_Node, _Node)> links) {
    while (true) {
      final degree = <_Node, int>{};
      for (final (from, to) in links) {
        degree[from] = (degree[from] ?? 0) + 1;
        degree[to] = (degree[to] ?? 0) + 1;
      }
      final loose = [
        for (final link in links)
          if ((degree[link.$1] ?? 0) < 2 || (degree[link.$2] ?? 0) < 2) link,
      ];
      if (loose.isEmpty) return;
      links.removeWhere((link) => loose.any((l) => identical(l, link)));
      if (links.isEmpty) return;
    }
  }

  /// Walks one face by always taking the next edge clockwise from the one we
  /// arrived on — the standard face traversal of a planar graph.
  static Polygon? _walk(_HalfEdge start) {
    final corners = <Vec2>[];
    var edge = start;
    for (var guard = 0; guard < 4096; guard++) {
      if (edge.used) return null;
      edge.used = true;
      corners.add(edge.from.at);

      final arriving = edge.twin;
      final ring = arriving.from.out;
      final index = ring.indexWhere((e) => identical(e, arriving));
      if (index < 0) return null;
      final next = ring[(index - 1 + ring.length) % ring.length];

      if (identical(next, start)) {
        return corners.length >= 3 ? Polygon(corners) : null;
      }
      edge = next;
    }
    return null;
  }

  /// Cuts every segment at every point another segment meets it, so the
  /// pieces only ever touch at their ends.
  static List<Segment> _split(List<Segment> segments, double tolerance) {
    final pieces = <Segment>[];
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.length < tolerance) continue;

      final cuts = <double>[0, 1];
      for (var j = 0; j < segments.length; j++) {
        if (i == j) continue;
        final other = segments[j];
        final crossing = segment.crossing(other, tolerance: tolerance);
        if (crossing != null) {
          cuts.add(crossing.onA);
          continue;
        }
        // Parallel lines never "cross", but a bar running along another one
        // still has to be cut where that one ends, or the face walk finds a
        // corner that is not in the ring.
        for (final end in [other.a, other.b]) {
          if (segment.distanceTo(end) <= tolerance) {
            cuts.add(segment.parameterOf(end).clamp(0.0, 1.0));
          }
        }
      }

      cuts.sort();
      final minStep = tolerance / math.max(segment.length, 1e-9);
      var previous = cuts.first;
      for (final cut in cuts.skip(1)) {
        if (cut - previous <= minStep) continue;
        pieces.add(Segment(segment.pointAt(previous), segment.pointAt(cut)));
        previous = cut;
      }
    }
    return pieces;
  }
}
