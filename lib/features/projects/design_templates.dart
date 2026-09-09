import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import '../geometry/region_builder.dart';

/// A ready-made starting point.
///
/// Templates are a shortcut and nothing more. Each one produces ordinary
/// free-form sections that can be dragged, resized, split, deleted or replaced,
/// and drawing from scratch supports arrangements no template covers. Nothing
/// in the app is limited to this list.
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

const GridCellSpec _fixed = GridCellSpec();

GridCellSpec _sash(
  CellOperation operation, {
  double share = 1,
  double? fixedMm,
  SwingDirection swing = SwingDirection.outward,
  HandleStyle handle = HandleStyle.lever,
  bool hasLock = false,
  String? label,
}) =>
    GridCellSpec(
      share: share,
      fixedMm: fixedMm,
      operation: operation,
      swing: swing,
      handle: handle,
      hasLock: hasLock,
      label: label,
    );

OpeningModel _window(String id, double width, double height, List<GridRowSpec> rows) =>
    OpeningModel(
      id: id,
      kind: OpeningKind.window,
      widthMm: width,
      heightMm: height,
      hasSill: true,
      regions: RegionBuilder.fromGrid(rows, Box2.fromLTWH(0, 0, width, height)),
    );

OpeningModel _door(String id, double width, double height, List<GridRowSpec> rows) =>
    OpeningModel(
      id: id,
      kind: OpeningKind.door,
      widthMm: width,
      heightMm: height,
      hasThreshold: true,
      regions: RegionBuilder.fromGrid(rows, Box2.fromLTWH(0, 0, width, height)),
    );

/// The configurations people ask for most often, plus one that exists to show
/// the engine is not limited to grids.
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
    id: 'glass-over-panel',
    name: 'Glass over panel',
    description: 'Upper glass, lower solid panel',
    kind: OpeningKind.window,
    build: _buildGlassOverPanel,
  ),
  DesignTemplate(
    id: 'corner-opening',
    name: 'Corner opening study',
    description: '40 cm side vent, 40 × 40 top-right — not a grid',
    kind: OpeningKind.window,
    build: _buildCornerOpening,
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

OpeningModel _buildFixedLight(String id) => _window(id, 1200, 1400, const [
      GridRowSpec(cells: [_fixed]),
    ]);

OpeningModel _buildSingleCasement(String id) => _window(id, 800, 1400, [
      GridRowSpec(cells: [_sash(CellOperation.casementRight)]),
    ]);

OpeningModel _buildCasementPlusFixed(String id) => _window(id, 1800, 1400, [
      GridRowSpec(cells: [_sash(CellOperation.casementLeft), _fixed]),
    ]);

OpeningModel _buildTransomTwoSash(String id) => _window(id, 1800, 1800, [
      const GridRowSpec(share: 0.3, cells: [_fixed]),
      GridRowSpec(share: 0.7, cells: [
        _sash(CellOperation.casementLeft),
        _sash(CellOperation.casementRight),
      ]),
    ]);

OpeningModel _buildSlidingTwoPanel(String id) => _window(id, 2000, 1400, [
      GridRowSpec(cells: [
        _sash(CellOperation.slidingLeft,
            swing: SwingDirection.none, handle: HandleStyle.pullBar),
        _sash(CellOperation.slidingRight,
            swing: SwingDirection.none, handle: HandleStyle.pullBar),
      ]),
    ]);

OpeningModel _buildGlassOverPanel(String id) => _window(id, 2000, 1600, const [
      GridRowSpec(share: 0.5, cells: [GridCellSpec(label: 'Glass')]),
      GridRowSpec(share: 0.5, cells: [
        GridCellSpec(infill: CellInfill.panel, label: 'Panel'),
      ]),
    ]);

/// The arrangement from the brief: a 400 mm full-height vent on the left, a
/// 400 x 400 opening in the top-right corner, and glass and panel filling the
/// rest. A rows-and-columns layout cannot express this — free-form sections can.
OpeningModel _buildCornerOpening(String id) {
  const width = 2000.0;
  const height = 1600.0;
  return OpeningModel(
    id: id,
    kind: OpeningKind.window,
    widthMm: width,
    heightMm: height,
    hasSill: true,
    regions: [
      DesignRegion(
        id: 's1',
        rect: Box2.fromLTWH(0, 0, 400, height),
        label: 'Side vent',
        operation: CellOperation.casementLeft,
        swing: SwingDirection.outward,
        handle: HandleStyle.lever,
      ),
      DesignRegion(
        id: 's2',
        rect: Box2.fromLTWH(width - 400, 0, 400, 400),
        label: 'Top vent',
        operation: CellOperation.awning,
        swing: SwingDirection.outward,
        handle: HandleStyle.lever,
      ),
      DesignRegion(
        id: 's3',
        rect: Box2.fromLTWH(400, 0, 1200, 400),
        label: 'Upper glass',
      ),
      DesignRegion(
        id: 's4',
        rect: Box2.fromLTWH(400, 400, 1600, 600),
        label: 'Glass',
      ),
      DesignRegion(
        id: 's5',
        rect: Box2.fromLTWH(400, 1000, 1600, 600),
        label: 'Panel',
        infill: CellInfill.panel,
      ),
    ],
  );
}

OpeningModel _buildSingleDoor(String id) => _door(id, 900, 2100, [
      GridRowSpec(cells: [
        _sash(CellOperation.doorLeafRight,
            swing: SwingDirection.inward, hasLock: true),
      ]),
    ]);

OpeningModel _buildDoorGlassOverPanel(String id) => _door(id, 900, 2100, [
      GridRowSpec(cells: [
        GridCellSpec(
          operation: CellOperation.doorLeafRight,
          swing: SwingDirection.inward,
          handle: HandleStyle.lever,
          hasLock: true,
          sub: const [
            GridRowSpec(share: 0.6, cells: [GridCellSpec()]),
            GridRowSpec(share: 0.4, cells: [GridCellSpec(infill: CellInfill.panel)]),
          ],
        ),
      ]),
    ]);

OpeningModel _buildDoubleDoor(String id) => _door(id, 1600, 2200, [
      GridRowSpec(cells: [
        _sash(CellOperation.doorLeafLeft, swing: SwingDirection.inward),
        _sash(CellOperation.doorLeafRight,
            swing: SwingDirection.inward, hasLock: true),
      ]),
    ]);

OpeningModel _buildDoorWithTransom(String id) => _door(id, 1000, 2600, [
      const GridRowSpec(share: 0.18, cells: [_fixed]),
      GridRowSpec(share: 0.82, cells: [
        _sash(CellOperation.doorLeafRight,
            swing: SwingDirection.inward, hasLock: true),
      ]),
    ]);
