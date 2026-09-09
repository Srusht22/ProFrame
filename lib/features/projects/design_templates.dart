import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';

/// A ready-made starting point.
///
/// Templates are a shortcut, never a limit: a template produces an ordinary
/// [OpeningModel] that can be edited freely, and drawing from scratch always
/// supports geometry no template covers (§31).
class DesignTemplate {
  final String id;
  final String name;
  final String description;
  final OpeningKind kind;
  final OpeningModel Function(String id) build;

  const DesignTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.build,
  });
}

LayoutCell _fixed(String id, {double widthRatio = 1, GlassType glass = GlassType.clearDouble}) =>
    LayoutCell(id: id, widthRatio: widthRatio, glass: glass);

LayoutCell _sash(
  String id,
  CellOperation operation, {
  double widthRatio = 1,
  SwingDirection swing = SwingDirection.outward,
  HandleStyle handle = HandleStyle.lever,
  bool hasLock = false,
  CellInfill infill = CellInfill.glass,
}) =>
    LayoutCell(
      id: id,
      widthRatio: widthRatio,
      operation: operation,
      swing: swing,
      handle: handle,
      hasLock: hasLock,
      infill: infill,
    );

OpeningModel _window(String id, double width, double height, OpeningLayout layout) =>
    OpeningModel(
      id: id,
      kind: OpeningKind.window,
      widthMm: width,
      heightMm: height,
      hasSill: true,
      layout: layout,
    );

OpeningModel _door(String id, double width, double height, OpeningLayout layout) =>
    OpeningModel(
      id: id,
      kind: OpeningKind.door,
      widthMm: width,
      heightMm: height,
      hasThreshold: true,
      layout: layout,
    );

/// The configurations people actually ask for most often.
const List<DesignTemplate> designTemplates = [
  DesignTemplate(
    id: 'fixed-light',
    name: 'Fixed light',
    description: 'One pane, no opening',
    kind: OpeningKind.window,
    build: _buildFixedLight,
  ),
  DesignTemplate(
    id: 'single-casement',
    name: 'Single casement',
    description: 'One leaf, hinged right',
    kind: OpeningKind.window,
    build: _buildSingleCasement,
  ),
  DesignTemplate(
    id: 'casement-plus-fixed',
    name: 'Casement + fixed',
    description: 'Opening leaf beside a fixed pane',
    kind: OpeningKind.window,
    build: _buildCasementPlusFixed,
  ),
  DesignTemplate(
    id: 'transom-two-sash',
    name: 'Transom over two sashes',
    description: 'Fixed light on top, two casements below',
    kind: OpeningKind.window,
    build: _buildTransomTwoSash,
  ),
  DesignTemplate(
    id: 'sliding-two-panel',
    name: 'Two-panel slider',
    description: 'Two leaves in separate tracks',
    kind: OpeningKind.window,
    build: _buildSlidingTwoPanel,
  ),
  DesignTemplate(
    id: 'single-door',
    name: 'Single door',
    description: 'One leaf, hinged right, glazed',
    kind: OpeningKind.door,
    build: _buildSingleDoor,
  ),
  DesignTemplate(
    id: 'door-glass-panel',
    name: 'Door, glass over panel',
    description: 'Upper light with a solid lower panel',
    kind: OpeningKind.door,
    build: _buildDoorGlassOverPanel,
  ),
  DesignTemplate(
    id: 'double-door',
    name: 'Double door',
    description: 'Two leaves meeting in the middle',
    kind: OpeningKind.door,
    build: _buildDoubleDoor,
  ),
  DesignTemplate(
    id: 'door-with-transom',
    name: 'Door with transom',
    description: 'Fixed light above a single leaf',
    kind: OpeningKind.door,
    build: _buildDoorWithTransom,
  ),
];

OpeningModel _buildFixedLight(String id) => _window(
      id,
      1200,
      1400,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', cells: [_fixed('r0.c0')]),
      ]),
    );

OpeningModel _buildSingleCasement(String id) => _window(
      id,
      800,
      1400,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', cells: [_sash('r0.c0', CellOperation.casementRight)]),
      ]),
    );

OpeningModel _buildCasementPlusFixed(String id) => _window(
      id,
      1800,
      1400,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', cells: [
          _sash('r0.c0', CellOperation.casementLeft),
          _fixed('r0.c1'),
        ]),
      ]),
    );

OpeningModel _buildTransomTwoSash(String id) => _window(
      id,
      1800,
      1800,
      OpeningLayout(rows: [
        LayoutRow(
          id: 'r0',
          heightRatio: 0.3,
          cells: [_fixed('r0.c0')],
        ),
        LayoutRow(id: 'r1', heightRatio: 0.7, cells: [
          _sash('r1.c0', CellOperation.casementLeft),
          _sash('r1.c1', CellOperation.casementRight),
        ]),
      ]),
    );

OpeningModel _buildSlidingTwoPanel(String id) => _window(
      id,
      2000,
      1400,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', cells: [
          _sash('r0.c0', CellOperation.slidingLeft,
              swing: SwingDirection.none, handle: HandleStyle.pullBar),
          _sash('r0.c1', CellOperation.slidingRight,
              swing: SwingDirection.none, handle: HandleStyle.pullBar),
        ]),
      ]),
    );

OpeningModel _buildSingleDoor(String id) => _door(
      id,
      900,
      2100,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', cells: [
          _sash('r0.c0', CellOperation.doorLeafRight,
              swing: SwingDirection.inward, hasLock: true),
        ]),
      ]),
    );

OpeningModel _buildDoorGlassOverPanel(String id) => _door(
      id,
      900,
      2100,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', cells: [
          LayoutCell(
            id: 'r0.c0',
            operation: CellOperation.doorLeafRight,
            swing: SwingDirection.inward,
            handle: HandleStyle.lever,
            hasLock: true,
            subLayout: OpeningLayout(rows: [
              LayoutRow(id: 'r0.c0.s0', heightRatio: 0.6, cells: [
                LayoutCell(id: 'r0.c0.s0.c0'),
              ]),
              LayoutRow(id: 'r0.c0.s1', heightRatio: 0.4, cells: [
                LayoutCell(id: 'r0.c0.s1.c0', infill: CellInfill.panel),
              ]),
            ]),
          ),
        ]),
      ]),
    );

OpeningModel _buildDoubleDoor(String id) => _door(
      id,
      1600,
      2200,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', cells: [
          _sash('r0.c0', CellOperation.doorLeafLeft, swing: SwingDirection.inward),
          _sash('r0.c1', CellOperation.doorLeafRight,
              swing: SwingDirection.inward, hasLock: true),
        ]),
      ]),
    );

OpeningModel _buildDoorWithTransom(String id) => _door(
      id,
      1000,
      2600,
      OpeningLayout(rows: [
        LayoutRow(id: 'r0', heightRatio: 0.18, cells: [_fixed('r0.c0')]),
        LayoutRow(id: 'r1', heightRatio: 0.82, cells: [
          _sash('r1.c0', CellOperation.doorLeafRight,
              swing: SwingDirection.inward, hasLock: true),
        ]),
      ]),
    );
