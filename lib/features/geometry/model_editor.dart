import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';

/// Structured edits to the parametric model.
///
/// Every editing action in the UI goes through here, so the model stays the
/// one source of truth and the 2D drawing, the 3D view and the price all
/// update from the same change (§18, §27).
class ModelEditor {
  ModelEditor._();

  static OpeningModel setSize(OpeningModel model, {double? widthMm, double? heightMm}) =>
      model.copyWith(
        widthMm: widthMm != null && widthMm > 0 ? widthMm : null,
        heightMm: heightMm != null && heightMm > 0 ? heightMm : null,
      );

  /// Adds a vertical division to a row, splitting the widest cell in two.
  static OpeningModel addMullion(OpeningModel model, int rowIndex) {
    return _mapRow(model, rowIndex, (row) {
      var widest = 0;
      for (var i = 1; i < row.cells.length; i++) {
        if (row.cells[i].widthRatio > row.cells[widest].widthRatio) widest = i;
      }
      final source = row.cells[widest];
      final half = source.widthRatio / 2;
      final left = source.copyWith(widthRatio: half, clearFixedWidth: true);
      final right = LayoutCell(
        id: '${row.id}.c${_nextIndex(row)}',
        widthRatio: half,
        operation: source.operation,
        infill: source.infill,
        glass: source.glass,
        panel: source.panel,
        swing: source.swing,
        handle: source.handle,
      );
      final cells = [...row.cells];
      cells[widest] = left;
      cells.insert(widest + 1, right);
      return row.copyWith(cells: cells);
    });
  }

  /// Removes the last vertical division from a row.
  static OpeningModel removeMullion(OpeningModel model, int rowIndex) {
    return _mapRow(model, rowIndex, (row) {
      if (row.cells.length < 2) return row;
      final cells = [...row.cells];
      final removed = cells.removeLast();
      final last = cells.last;
      cells[cells.length - 1] =
          last.copyWith(widthRatio: last.widthRatio + removed.widthRatio, clearFixedWidth: true);
      return row.copyWith(cells: cells);
    });
  }

  /// Adds a horizontal division, splitting the tallest row.
  static OpeningModel addTransom(OpeningModel model) {
    final rows = [...model.layout.rows];
    if (rows.isEmpty) return model;
    var tallest = 0;
    for (var i = 1; i < rows.length; i++) {
      if (rows[i].heightRatio > rows[tallest].heightRatio) tallest = i;
    }
    final source = rows[tallest];
    final half = source.heightRatio / 2;
    final newIndex = rows.length;
    final upper = source.copyWith(heightRatio: half, clearFixedHeight: true);
    final lower = LayoutRow(
      id: 'r$newIndex',
      heightRatio: half,
      cells: source.cells
          .map((c) => LayoutCell(
                id: 'r$newIndex.${c.id.split('.').last}',
                widthRatio: c.widthRatio,
                operation: c.operation,
                infill: c.infill,
                glass: c.glass,
                panel: c.panel,
                swing: c.swing,
                handle: c.handle,
              ))
          .toList(),
    );
    rows[tallest] = upper;
    rows.insert(tallest + 1, lower);
    return model.copyWith(layout: OpeningLayout(rows: rows));
  }

  static OpeningModel removeTransom(OpeningModel model) {
    final rows = [...model.layout.rows];
    if (rows.length < 2) return model;
    final removed = rows.removeLast();
    final last = rows.last;
    rows[rows.length - 1] =
        last.copyWith(heightRatio: last.heightRatio + removed.heightRatio, clearFixedHeight: true);
    return model.copyWith(layout: OpeningLayout(rows: rows));
  }

  static OpeningModel updateCell(
    OpeningModel model,
    String cellId,
    LayoutCell Function(LayoutCell cell) update,
  ) {
    OpeningLayout mapLayout(OpeningLayout layout) => OpeningLayout(
          rows: layout.rows
              .map((row) => row.copyWith(
                    cells: row.cells.map((cell) {
                      final sub = cell.subLayout;
                      final withSub = sub == null ? cell : cell.copyWith(subLayout: mapLayout(sub));
                      return withSub.id == cellId ? update(withSub) : withSub;
                    }).toList(),
                  ))
              .toList(),
        );

    return model.copyWith(layout: mapLayout(model.layout));
  }

  static OpeningModel setCellOperation(OpeningModel model, String cellId, CellOperation operation) =>
      updateCell(model, cellId, (cell) {
        final swing = operation.isOperable && !operation.isSliding
            ? (cell.swing == SwingDirection.none
                ? (operation.isDoorLeaf ? SwingDirection.inward : SwingDirection.outward)
                : cell.swing)
            : SwingDirection.none;
        return cell.copyWith(
          operation: operation,
          swing: swing,
          handle: operation.isOperable
              ? (cell.handle == HandleStyle.none ? HandleStyle.lever : cell.handle)
              : HandleStyle.none,
          hasLock: operation.isDoorLeaf && cell.hasLock,
        );
      });

  static OpeningModel setRowHeightMm(OpeningModel model, int rowIndex, double? heightMm) =>
      _mapRow(
        model,
        rowIndex,
        (row) => heightMm == null || heightMm <= 0
            ? row.copyWith(clearFixedHeight: true)
            : row.copyWith(fixedHeightMm: heightMm),
      );

  static OpeningModel setCellWidthMm(OpeningModel model, String cellId, double? widthMm) =>
      updateCell(
        model,
        cellId,
        (cell) => widthMm == null || widthMm <= 0
            ? cell.copyWith(clearFixedWidth: true)
            : cell.copyWith(fixedWidthMm: widthMm),
      );

  /// Splits a leaf into an upper light and a lower panel — the classic
  /// entrance door with glass above and a solid panel below.
  static OpeningModel splitCellHorizontally(
    OpeningModel model,
    String cellId, {
    double upperRatio = 0.6,
  }) =>
      updateCell(model, cellId, (cell) {
        if (cell.subLayout != null) return cell;
        return cell.copyWith(
          subLayout: OpeningLayout(rows: [
            LayoutRow(
              id: '$cellId.s0',
              heightRatio: upperRatio,
              cells: [
                LayoutCell(id: '$cellId.s0.c0', glass: cell.glass, infill: CellInfill.glass),
              ],
            ),
            LayoutRow(
              id: '$cellId.s1',
              heightRatio: 1 - upperRatio,
              cells: [
                LayoutCell(id: '$cellId.s1.c0', infill: CellInfill.panel, panel: cell.panel),
              ],
            ),
          ]),
        );
      });

  static OpeningModel mergeCell(OpeningModel model, String cellId) =>
      updateCell(model, cellId, (cell) => cell.copyWith(clearSubLayout: true));

  static OpeningModel _mapRow(
    OpeningModel model,
    int rowIndex,
    LayoutRow Function(LayoutRow row) update,
  ) {
    if (rowIndex < 0 || rowIndex >= model.layout.rows.length) return model;
    final rows = [...model.layout.rows];
    rows[rowIndex] = update(rows[rowIndex]);
    return model.copyWith(layout: OpeningLayout(rows: rows));
  }

  static int _nextIndex(LayoutRow row) {
    var maxIndex = -1;
    for (final cell in row.cells) {
      final tail = cell.id.split('.').last;
      final parsed = int.tryParse(tail.replaceAll('c', ''));
      if (parsed != null && parsed > maxIndex) maxIndex = parsed;
    }
    return maxIndex + 1;
  }
}
