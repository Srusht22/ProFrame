/// The explicit, fully-resolved 3D assembly.
///
/// This is deliberately built in Dart, not in JavaScript: the renderer only
/// instantiates the parts listed here, so component placement and proportions
/// are unit-testable and can never drift from the parametric model (§51, §64).
///
/// Coordinate system: millimetres, origin at the centre of the opening,
/// **x** to the right, **y** upwards, **z** towards the exterior.
library;

class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  factory Vec3.fromJson(Map<String, dynamic> json) => Vec3(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        (json['z'] as num).toDouble(),
      );

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, ${z.toStringAsFixed(1)})';
}

enum PartShape { box, cylinder, chamferedBox }

/// What a part *is*. Used by the renderer for material selection and by the
/// tests to assert that the right components exist in the right places.
enum PartRole {
  frameHead,
  frameSill,
  frameJambLeft,
  frameJambRight,
  mullion,
  transom,
  sashStile,
  sashRail,
  glazingBead,
  glass,
  panel,
  louvreBlade,
  mesh,
  hinge,
  handle,
  handleRose,
  lockCylinder,
  threshold,
  windowSill,
  wallReveal,
}

extension PartRoleInfo on PartRole {
  bool get isFrame => switch (this) {
        PartRole.frameHead ||
        PartRole.frameSill ||
        PartRole.frameJambLeft ||
        PartRole.frameJambRight =>
          true,
        _ => false,
      };

  bool get isSash => this == PartRole.sashStile || this == PartRole.sashRail;

  bool get isHardware => switch (this) {
        PartRole.hinge || PartRole.handle || PartRole.handleRose || PartRole.lockCylinder => true,
        _ => false,
      };
}

/// One rigid body in the assembly.
class ScenePart {
  final String id;
  final PartRole role;
  final PartShape shape;

  /// Box: full width/height/depth. Cylinder: x = radius, y = length,
  /// z is unused (kept for a uniform payload).
  final Vec3 size;
  final Vec3 center;
  final Vec3 rotationDeg;
  final String materialKey;

  /// The cell this part belongs to, so the UI can highlight a selected
  /// section in 3D. Null for parts owned by the outer frame.
  final String? cellPath;

  const ScenePart({
    required this.id,
    required this.role,
    required this.shape,
    required this.size,
    required this.center,
    required this.materialKey,
    this.rotationDeg = Vec3.zero,
    this.cellPath,
  });

  double get volumeMm3 => shape == PartShape.cylinder
      ? 3.14159265 * size.x * size.x * size.y
      : size.x * size.y * size.z;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'shape': shape.name,
        'size': size.toJson(),
        'center': center.toJson(),
        'rotation': rotationDeg.toJson(),
        'material': materialKey,
        if (cellPath != null) 'cellPath': cellPath,
      };
}

/// A physically-based material definition handed to the renderer.
class SceneMaterial {
  final String key;
  final int color;
  final double roughness;
  final double metalness;
  final double opacity;

  /// 0 for opaque materials; drives real light transmission through glass.
  final double transmission;
  final double clearcoat;

  const SceneMaterial({
    required this.key,
    required this.color,
    this.roughness = 0.5,
    this.metalness = 0,
    this.opacity = 1,
    this.transmission = 0,
    this.clearcoat = 0,
  });

  bool get isTransparent => transmission > 0 || opacity < 1;

  Map<String, dynamic> toJson() => {
        'key': key,
        'color': color,
        'roughness': roughness,
        'metalness': metalness,
        'opacity': opacity,
        'transmission': transmission,
        'clearcoat': clearcoat,
        'transparent': isTransparent,
      };
}

/// A measurement drawn in 3D space when dimensions are switched on.
class SceneDimension {
  final String label;
  final Vec3 from;
  final Vec3 to;

  const SceneDimension({required this.label, required this.from, required this.to});

  Map<String, dynamic> toJson() =>
      {'label': label, 'from': from.toJson(), 'to': to.toJson()};
}

/// Rendering style. Technical shows flat shaded profiles and edges for
/// checking construction; realistic turns on full materials and reflections.
enum RenderStyle { realistic, technical }

class Scene3D {
  final String modelId;
  final double widthMm;
  final double heightMm;
  final double depthMm;
  final List<ScenePart> parts;
  final Map<String, SceneMaterial> materials;
  final List<SceneDimension> dimensions;
  final RenderStyle style;

  const Scene3D({
    required this.modelId,
    required this.widthMm,
    required this.heightMm,
    required this.depthMm,
    required this.parts,
    required this.materials,
    this.dimensions = const [],
    this.style = RenderStyle.realistic,
  });

  List<ScenePart> partsWithRole(PartRole role) =>
      parts.where((p) => p.role == role).toList();

  List<ScenePart> partsForCell(String cellPath) =>
      parts.where((p) => p.cellPath == cellPath).toList();

  int get glassCount => partsWithRole(PartRole.glass).length;
  int get hingeCount => partsWithRole(PartRole.hinge).length;

  Scene3D withStyle(RenderStyle newStyle) => Scene3D(
        modelId: modelId,
        widthMm: widthMm,
        heightMm: heightMm,
        depthMm: depthMm,
        parts: parts,
        materials: materials,
        dimensions: dimensions,
        style: newStyle,
      );

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'width': widthMm,
        'height': heightMm,
        'depth': depthMm,
        'style': style.name,
        'materials': materials.values.map((m) => m.toJson()).toList(),
        'parts': parts.map((p) => p.toJson()).toList(),
        'dimensions': dimensions.map((d) => d.toJson()).toList(),
      };
}

/// Fixed camera positions offered in the viewer (§25).
enum CameraPreset { front, back, left, right, top, perspective }

extension CameraPresetInfo on CameraPreset {
  String get label => switch (this) {
        CameraPreset.front => 'Front',
        CameraPreset.back => 'Back',
        CameraPreset.left => 'Left',
        CameraPreset.right => 'Right',
        CameraPreset.top => 'Top',
        CameraPreset.perspective => 'Perspective',
      };
}
