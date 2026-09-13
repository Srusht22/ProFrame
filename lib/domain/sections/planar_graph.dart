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
  }) {
    final pieces = _split(segments, weldTolerance);
    if (pieces.isEmpty) return const [];

    final nodes = <_Node>[];
    _Node nodeAt(Vec2 point) {
      for (final n in nodes) {
        if (n.at.distanceTo(point) <= weldTolerance) return n;
      }
      final created = _Node(point);
      nodes.add(created);
      return created;
    }

    for (final piece in pieces) {
      final from = nodeAt(piece.a);
      final to = nodeAt(piece.b);
      if (identical(from, to)) continue;
      if (_alreadyJoined(from, to)) continue;

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
    for (final node in nodes) {
      for (final start in node.out) {
        if (start.used) continue;
        final face = _walk(start);
        if (face == null) continue;
        // Every bounded face comes out of this traversal with the same
        // orientation, and the one unbounded face that wraps the whole
        // drawing comes out with the other. Dropping that one leaves exactly
        // the areas the user enclosed.
        if (face.signedArea <= 0) continue;
        if (face.area < minAreaMmSq) continue;
        faces.add(face);
      }
    }
    return faces;
  }

  static bool _alreadyJoined(_Node from, _Node to) {
    for (final edge in from.out) {
      if (identical(edge.to, to)) return true;
    }
    return false;
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
