import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/dimension_handles.dart';
import 'package:proframe/app/canvas/dimension_layout.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/frame_sides.dart';
import 'package:proframe/domain/dimensions/measurements.dart';

import '../domain/angled_dimensions_test.dart' as angled;
import 'editable_figures_test.dart' show viewOf;

// The side of a frame that is not a rectangle, on the technical drawing:
// written down the side it measures, tappable where it is written, named
// for that side, and typing over it is the size the form gives.

void main() {
  test('the right side\'s figure is written down the right, `?` until it is '
      'given, and can be tapped where it is written', () {
    final d = angled.drawn();
    final view = viewOf(d);
    final placed = DimensionLayout.of(
      d,
      view,
    ).figures.where((f) => f.run.of == ChainRunOf.side).toList();
    expect(placed, hasLength(1));
    final figure = placed.single;
    expect(figure.chain.side, DimensionSide.right);
    expect(figure.text, '? cm');
    // To the right of the drawing, beside the right side's own span.
    final box = view.toScreen(d.frame!.outline.corners[2]);
    expect(figure.figure.dx, greaterThan(box.dx));

    final handles = CadDimensions.of(d, view, const CadLayers());
    final hit = CadDimensions.at(handles, figure.figure);
    expect(hit, isNotNull);
    expect(hit!.of, DimensionOf.side);
    expect(hit.label, 'Right jamb height');
    expect(hit.valueMm, 1500);
    expect(hit.known, isFalse);

    // What the drawing does when a figure is typed over it: the side's
    // size, through the one way a size is put into a design.
    final after = Measurements.apply(d, {hit.elementId!: 1700}).design;
    final again = DimensionLayout.of(
      after,
      viewOf(after),
    ).figures.singleWhere((f) => f.run.of == ChainRunOf.side);
    expect(again.text, '170.0 cm');
    expect(angled.heightAt(after, 1000), closeTo(1700, 1e-9));
    expect(angled.heightAt(after, 0), 2000);
  });

  test('the overall figures stay outside the sides\' rows, and no two '
      'figures overlap', () {
    final d = angled.drawn();
    final layout = DimensionLayout.of(d, viewOf(d));
    final rects = [for (final f in layout.figures) f.rect];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
    final chains = DimensionChains.of(d);
    final overallLeft = chains.singleWhere(
      (c) =>
          c.side == DimensionSide.left && c.runs.first.of == ChainRunOf.overall,
    );
    for (final c in chains) {
      if (c.side == DimensionSide.left && c != overallLeft) {
        expect(c.row, lessThan(overallLeft.row));
      }
    }
  });

  test('on a phone, where the right is kept for the drawing, room is still '
      'kept for the side down the right — and only for a frame that has '
      'one', () {
    final d = angled.drawn();
    expect(DimensionLayout.roomFor(d, rightToo: false).right, greaterThan(0));
    final square = Measurements.apply(d, {
      FrameSides.of(d).single.key: 2000,
    }).design;
    expect(FrameSides.of(square), isEmpty);
    expect(DimensionLayout.roomFor(square, rightToo: false).right, 0);
  });
}
