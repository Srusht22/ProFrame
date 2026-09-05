import '../../core/constants/app_constants.dart';
import '../../core/units/unit_converter.dart';
import 'configuration_options.dart';

class ProductConfiguration {
  final String id;
  final String projectName;
  final ProductType productType;
  final double widthMm;
  final double heightMm;
  final double depthMm;
  final WindowStyle style;
  final int sections;
  final FrameColorType frameColor;
  final String? customHexColor;
  final GlassType glassType;
  final HandleType handleType;
  final FrameColorType handleColor;
  final OpeningDirection openingDirection;
  final bool showDimensions;
  final String? notes;
  final String? thumbnailBase64;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductConfiguration({
    required this.id,
    required this.projectName,
    this.productType = ProductType.window,
    this.widthMm = AppConstants.defaultWidthMm,
    this.heightMm = AppConstants.defaultHeightMm,
    this.depthMm = AppConstants.defaultDepthMm,
    this.style = WindowStyle.sliding,
    this.sections = AppConstants.defaultSections,
    this.frameColor = FrameColorType.black,
    this.customHexColor,
    this.glassType = GlassType.clear,
    this.handleType = HandleType.standardPull,
    this.handleColor = FrameColorType.black,
    this.openingDirection = OpeningDirection.left,
    this.showDimensions = true,
    this.notes,
    this.thumbnailBase64,
    required this.createdAt,
    required this.updatedAt,
  });

  ProductConfiguration copyWith({
    String? id,
    String? projectName,
    ProductType? productType,
    double? widthMm,
    double? heightMm,
    double? depthMm,
    WindowStyle? style,
    int? sections,
    FrameColorType? frameColor,
    String? customHexColor,
    GlassType? glassType,
    HandleType? handleType,
    FrameColorType? handleColor,
    OpeningDirection? openingDirection,
    bool? showDimensions,
    String? notes,
    String? thumbnailBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductConfiguration(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      productType: productType ?? this.productType,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      depthMm: depthMm ?? this.depthMm,
      style: style ?? this.style,
      sections: sections ?? this.sections,
      frameColor: frameColor ?? this.frameColor,
      customHexColor: customHexColor ?? this.customHexColor,
      glassType: glassType ?? this.glassType,
      handleType: handleType ?? this.handleType,
      handleColor: handleColor ?? this.handleColor,
      openingDirection: openingDirection ?? this.openingDirection,
      showDimensions: showDimensions ?? this.showDimensions,
      notes: notes ?? this.notes,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String formattedDimensions([LengthUnit unit = LengthUnit.mm]) {
    final w = unit.format(widthMm);
    final h = unit.format(heightMm);
    return '$w × $h';
  }

  String get summaryDescription {
    return '${style.label} • ${frameColor.label} • ${glassType.label}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectName': projectName,
      'productType': productType.id,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'depthMm': depthMm,
      'style': style.name,
      'sections': sections,
      'frameColor': frameColor.name,
      'customHexColor': customHexColor,
      'glassType': glassType.name,
      'handleType': handleType.name,
      'handleColor': handleColor.name,
      'openingDirection': openingDirection.name,
      'showDimensions': showDimensions,
      'notes': notes,
      'thumbnailBase64': thumbnailBase64,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductConfiguration.fromJson(Map<String, dynamic> json) {
    return ProductConfiguration(
      id: json['id'] as String,
      projectName: json['projectName'] as String? ?? 'Untitled Project',
      productType: json['productType'] != null
          ? ProductType.fromString(json['productType'] as String)
          : ProductType.window,
      widthMm: (json['widthMm'] as num?)?.toDouble() ?? AppConstants.defaultWidthMm,
      heightMm: (json['heightMm'] as num?)?.toDouble() ?? AppConstants.defaultHeightMm,
      depthMm: (json['depthMm'] as num?)?.toDouble() ?? AppConstants.defaultDepthMm,
      style: WindowStyle.values.firstWhere(
        (e) => e.name == json['style'],
        orElse: () => WindowStyle.sliding,
      ),
      sections: (json['sections'] as num?)?.toInt() ?? AppConstants.defaultSections,
      frameColor: FrameColorType.values.firstWhere(
        (e) => e.name == json['frameColor'],
        orElse: () => FrameColorType.black,
      ),
      customHexColor: json['customHexColor'] as String?,
      glassType: GlassType.values.firstWhere(
        (e) => e.name == json['glassType'],
        orElse: () => GlassType.clear,
      ),
      handleType: HandleType.values.firstWhere(
        (e) => e.name == json['handleType'],
        orElse: () => HandleType.standardPull,
      ),
      handleColor: FrameColorType.values.firstWhere(
        (e) => e.name == json['handleColor'],
        orElse: () => FrameColorType.black,
      ),
      openingDirection: OpeningDirection.values.firstWhere(
        (e) => e.name == json['openingDirection'],
        orElse: () => OpeningDirection.left,
      ),
      showDimensions: json['showDimensions'] as bool? ?? true,
      notes: json['notes'] as String?,
      thumbnailBase64: json['thumbnailBase64'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Direct bridge parameters payload for Three.js WebGL engine
  Map<String, dynamic> to3DParams() {
    return {
      'productType': productType.id,
      'width': widthMm,
      'height': heightMm,
      'depth': depthMm,
      'sections': sections,
      'style': style.name,
      'frameColor': frameColor.name,
      'customHexColor': customHexColor,
      'glassType': glassType.name,
      'handleType': handleType.name,
      'handleColor': handleColor.name,
      'openingDirection': openingDirection.name,
      'showDimensions': showDimensions,
    };
  }
}
