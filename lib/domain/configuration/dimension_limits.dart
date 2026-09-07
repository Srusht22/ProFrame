import 'config_enums.dart';

class DimensionRange {
  final double minMm;
  final double maxMm;
  final double defaultMm;

  const DimensionRange({required this.minMm, required this.maxMm, required this.defaultMm});

  bool contains(double valueMm) => valueMm >= minMm && valueMm <= maxMm;
}

/// Factory-configurable min/max dimensions per product type. This is the
/// "configurable rules system" the spec asks for: swap this table (or load
/// it from Settings/backend) per factory instead of hard-coding one
/// universal formula.
class ProductLimits {
  final DimensionRange width;
  final DimensionRange height;
  final DimensionRange frameDepth;
  final int minSections;
  final int maxSections;

  const ProductLimits({
    required this.width,
    required this.height,
    required this.frameDepth,
    this.minSections = 1,
    this.maxSections = 6,
  });

  static const Map<DoorType, ProductLimits> doorLimits = {
    DoorType.interior: ProductLimits(
      width: DimensionRange(minMm: 600, maxMm: 1100, defaultMm: 800),
      height: DimensionRange(minMm: 1900, maxMm: 2400, defaultMm: 2050),
      frameDepth: DimensionRange(minMm: 35, maxMm: 90, defaultMm: 45),
      minSections: 1,
      maxSections: 2,
    ),
    DoorType.exterior: ProductLimits(
      width: DimensionRange(minMm: 700, maxMm: 1400, defaultMm: 950),
      height: DimensionRange(minMm: 1950, maxMm: 2600, defaultMm: 2150),
      frameDepth: DimensionRange(minMm: 45, maxMm: 120, defaultMm: 70),
      minSections: 1,
      maxSections: 2,
    ),
    DoorType.entrance: ProductLimits(
      width: DimensionRange(minMm: 900, maxMm: 2200, defaultMm: 1200),
      height: DimensionRange(minMm: 2100, maxMm: 3000, defaultMm: 2300),
      frameDepth: DimensionRange(minMm: 60, maxMm: 150, defaultMm: 90),
      minSections: 1,
      maxSections: 3,
    ),
    DoorType.sliding: ProductLimits(
      width: DimensionRange(minMm: 1400, maxMm: 6000, defaultMm: 2400),
      height: DimensionRange(minMm: 1900, maxMm: 3200, defaultMm: 2200),
      frameDepth: DimensionRange(minMm: 60, maxMm: 160, defaultMm: 85),
      minSections: 2,
      maxSections: 6,
    ),
    DoorType.folding: ProductLimits(
      width: DimensionRange(minMm: 1600, maxMm: 7000, defaultMm: 2800),
      height: DimensionRange(minMm: 1900, maxMm: 3000, defaultMm: 2200),
      frameDepth: DimensionRange(minMm: 55, maxMm: 140, defaultMm: 75),
      minSections: 2,
      maxSections: 10,
    ),
    DoorType.custom: ProductLimits(
      width: DimensionRange(minMm: 400, maxMm: 8000, defaultMm: 1000),
      height: DimensionRange(minMm: 400, maxMm: 4000, defaultMm: 2100),
      frameDepth: DimensionRange(minMm: 30, maxMm: 200, defaultMm: 60),
      minSections: 1,
      maxSections: 12,
    ),
  };

  static const Map<WindowType, ProductLimits> windowLimits = {
    WindowType.fixed: ProductLimits(
      width: DimensionRange(minMm: 300, maxMm: 4000, defaultMm: 1200),
      height: DimensionRange(minMm: 300, maxMm: 3000, defaultMm: 1200),
      frameDepth: DimensionRange(minMm: 35, maxMm: 100, defaultMm: 50),
      minSections: 1,
      maxSections: 8,
    ),
    WindowType.sliding: ProductLimits(
      width: DimensionRange(minMm: 600, maxMm: 4000, defaultMm: 1500),
      height: DimensionRange(minMm: 400, maxMm: 2400, defaultMm: 1300),
      frameDepth: DimensionRange(minMm: 40, maxMm: 110, defaultMm: 55),
      minSections: 2,
      maxSections: 6,
    ),
    WindowType.casement: ProductLimits(
      width: DimensionRange(minMm: 400, maxMm: 1600, defaultMm: 900),
      height: DimensionRange(minMm: 400, maxMm: 2200, defaultMm: 1200),
      frameDepth: DimensionRange(minMm: 40, maxMm: 100, defaultMm: 60),
      minSections: 1,
      maxSections: 4,
    ),
    WindowType.tiltAndTurn: ProductLimits(
      width: DimensionRange(minMm: 400, maxMm: 1600, defaultMm: 1000),
      height: DimensionRange(minMm: 400, maxMm: 2200, defaultMm: 1300),
      frameDepth: DimensionRange(minMm: 55, maxMm: 120, defaultMm: 70),
      minSections: 1,
      maxSections: 4,
    ),
    WindowType.awning: ProductLimits(
      width: DimensionRange(minMm: 400, maxMm: 1800, defaultMm: 900),
      height: DimensionRange(minMm: 300, maxMm: 1400, defaultMm: 700),
      frameDepth: DimensionRange(minMm: 40, maxMm: 100, defaultMm: 55),
      minSections: 1,
      maxSections: 3,
    ),
    WindowType.doubleWindow: ProductLimits(
      width: DimensionRange(minMm: 1000, maxMm: 4500, defaultMm: 2000),
      height: DimensionRange(minMm: 400, maxMm: 2400, defaultMm: 1300),
      frameDepth: DimensionRange(minMm: 40, maxMm: 110, defaultMm: 55),
      minSections: 2,
      maxSections: 2,
    ),
    WindowType.tripleWindow: ProductLimits(
      width: DimensionRange(minMm: 1500, maxMm: 6000, defaultMm: 2700),
      height: DimensionRange(minMm: 400, maxMm: 2400, defaultMm: 1300),
      frameDepth: DimensionRange(minMm: 40, maxMm: 110, defaultMm: 55),
      minSections: 3,
      maxSections: 3,
    ),
    WindowType.custom: ProductLimits(
      width: DimensionRange(minMm: 300, maxMm: 8000, defaultMm: 1200),
      height: DimensionRange(minMm: 300, maxMm: 4000, defaultMm: 1500),
      frameDepth: DimensionRange(minMm: 30, maxMm: 200, defaultMm: 55),
      minSections: 1,
      maxSections: 12,
    ),
  };

  static ProductLimits forDoor(DoorType type) => doorLimits[type] ?? doorLimits[DoorType.custom]!;

  static ProductLimits forWindow(WindowType type) =>
      windowLimits[type] ?? windowLimits[WindowType.custom]!;
}
