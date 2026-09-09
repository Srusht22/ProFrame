import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/features/geometry/model_editor.dart';
import 'package:proframe/shared/models/materials.dart';
import 'package:proframe/shared/models/opening_model.dart';

OpeningModel window({
  double width = 1800,
  double height = 1400,
  int columns = 3,
  int rows = 1,
}) {
  final layout = OpeningLayout(
    rows: [
      for (var r = 0; r < rows; r++)
        LayoutRow(
          id: 'r$r',
          cells: [
            for (var c = 0; c < columns; c++) LayoutCell(id: 'r$r.c$c'),
          ],
        ),
    ],
  );
  return OpeningModel(
    id: 'test',
    kind: OpeningKind.window,
    widthMm: width,
    heightMm: height,
    layout: layout,
  );
}

void main() {
  group('the solver turns proportions into millimetres', () {
    test('sections plus mullions exactly fill the frame', () {
      final model = window();
      final solved = OpeningSolver.solve(model);
      final frameFace = model.material.frameFaceMm;
      final barFace = model.material.mullionFaceMm;

      final cellWidth =
          solved.topCells.fold<double>(0, (sum, c) => sum + c.aperture.width);
      final barWidth = solved.bars
          .where((b) => b.vertical)
          .fold<double>(0, (sum, b) => sum + b.rect.width);

      expect(cellWidth + barWidth + 2 * frameFace, closeTo(model.widthMm, 0.001));
      expect(barWidth, closeTo(2 * barFace, 0.001));
    });

    test('equal sections come out equal', () {
      final solved = OpeningSolver.solve(window());
      final widths = solved.topCells.map((c) => c.aperture.width).toList();

      expect(widths, hasLength(3));
      expect(widths[1], closeTo(widths[0], 0.001));
      expect(widths[2], closeTo(widths[0], 0.001));
    });

    test('a proportion drawn twice as wide stays twice as wide', () {
      final model = OpeningModel(
        id: 'test',
        kind: OpeningKind.window,
        widthMm: 3000,
        heightMm: 1400,
        layout: OpeningLayout(rows: [
          LayoutRow(id: 'r0', cells: const [
            LayoutCell(id: 'r0.c0', widthRatio: 2),
            LayoutCell(id: 'r0.c1', widthRatio: 1),
          ]),
        ]),
      );
      final solved = OpeningSolver.solve(model);

      expect(
        solved.topCells[0].aperture.width / solved.topCells[1].aperture.width,
        closeTo(2, 0.001),
      );
    });

    test('a pinned millimetre size is honoured and the rest shares the remainder', () {
      final model = ModelEditor.setCellWidthMm(window(columns: 2), 'r0.c0', 700);
      final solved = OpeningSolver.solve(model);

      expect(solved.topCells[0].aperture.width, closeTo(700, 0.001));
      final total = solved.topCells.fold<double>(0, (s, c) => s + c.aperture.width);
      expect(
        total + model.material.mullionFaceMm + 2 * model.material.frameFaceMm,
        closeTo(model.widthMm, 0.001),
      );
    });

    test('rows stack without gaps or overlaps', () {
      final solved = OpeningSolver.solve(window(rows: 2, columns: 1));
      final cells = solved.topCells;
      final transom = solved.bars.firstWhere((b) => !b.vertical);

      expect(cells[0].aperture.bottom, closeTo(transom.rect.top, 0.001));
      expect(cells[1].aperture.top, closeTo(transom.rect.bottom, 0.001));
    });

    test('glass sits inside the sash, and the sash inside the aperture', () {
      final model = ModelEditor.setCellOperation(
        window(columns: 1),
        'r0.c0',
        CellOperation.casementRight,
      );
      final cell = OpeningSolver.solve(model).leaves.single;

      expect(cell.glazingRect.left, greaterThan(cell.sashRect.left));
      expect(cell.glazingRect.right, lessThan(cell.sashRect.right));
      expect(cell.glazingRect.top, greaterThan(cell.sashRect.top));
      expect(cell.glazingRect.bottom, lessThan(cell.sashRect.bottom));
      expect(cell.sashRect.width, lessThanOrEqualTo(cell.aperture.width));
    });

    test('a leaf can be divided into glass over a panel', () {
      final door = OpeningModel.blank(OpeningKind.door);
      final split = ModelEditor.splitCellHorizontally(door, 'c0');
      final solved = OpeningSolver.solve(split);

      expect(solved.leaves, hasLength(2));
      expect(solved.leaves[0].spec.infill, CellInfill.glass);
      expect(solved.leaves[1].spec.infill, CellInfill.panel);
      expect(solved.allBars.where((b) => !b.vertical), hasLength(1));
    });
  });

  group('editing keeps the model consistent', () {
    test('adding a mullion adds a section without changing the overall size', () {
      final before = window(columns: 1);
      final after = ModelEditor.addMullion(before, 0);
      final solved = OpeningSolver.solve(after);

      expect(after.layout.rows.single.cells, hasLength(2));
      expect(after.widthMm, before.widthMm);
      final total = solved.topCells.fold<double>(0, (s, c) => s + c.aperture.width) +
          after.material.mullionFaceMm +
          2 * after.material.frameFaceMm;
      expect(total, closeTo(after.widthMm, 0.001));
    });

    test('removing a mullion gives the space back to the neighbour', () {
      final model = ModelEditor.removeMullion(window(columns: 2), 0);
      final solved = OpeningSolver.solve(model);

      expect(model.layout.rows.single.cells, hasLength(1));
      expect(
        solved.topCells.single.aperture.width,
        closeTo(model.widthMm - 2 * model.material.frameFaceMm, 0.001),
      );
    });

    test('changing the operation gives the leaf a handle and drops it when fixed', () {
      var model = ModelEditor.setCellOperation(
        window(columns: 1),
        'r0.c0',
        CellOperation.casementLeft,
      );
      expect(model.layout.allCells.single.handle, isNot(HandleStyle.none));

      model = ModelEditor.setCellOperation(model, 'r0.c0', CellOperation.fixed);
      expect(model.layout.allCells.single.handle, HandleStyle.none);
      expect(model.layout.allCells.single.swing, SwingDirection.none);
    });

    test('a different frame material changes the profile sizes', () {
      final aluminium = OpeningSolver.solve(window(columns: 1));
      final upvc = OpeningSolver.solve(
        window(columns: 1).copyWith(material: FrameMaterial.upvc),
      );

      expect(upvc.innerRect.width, lessThan(aluminium.innerRect.width));
    });
  });

  group('validation warns instead of silently accepting', () {
    test('a section too small to fabricate is reported', () {
      final model = window(width: 400, columns: 3);
      expect(model.validate().any((i) => i.contains('too small to fabricate')), isTrue);
    });

    test('an over-wide opening leaf is flagged', () {
      final model = ModelEditor.setCellOperation(
        window(width: 2000, columns: 1),
        'r0.c0',
        CellOperation.casementLeft,
      );
      expect(model.validate().any((i) => i.contains('need reinforcement')), isTrue);
    });

    test('a sensible unit reports nothing', () {
      expect(window().validate(), isEmpty);
    });
  });
}
