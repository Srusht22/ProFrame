import 'package:flutter/material.dart';
import '../configuration/configuration_options.dart';
import '../configuration/product_configuration.dart';

class DimensionRange {
  final double minMm;
  final double maxMm;
  final double defaultMm;
  final double stepMm;

  const DimensionRange({
    required this.minMm,
    required this.maxMm,
    required this.defaultMm,
    this.stepMm = 10.0,
  });

  bool isValid(double valueMm) => valueMm >= minMm && valueMm <= maxMm;
}

abstract class ProductDefinition {
  final ProductType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isAvailable;

  const ProductDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.isAvailable = true,
  });

  DimensionRange get widthLimits;
  DimensionRange get heightLimits;
  DimensionRange get depthLimits;
  int get minSections;
  int get maxSections;

  List<WindowStyle> get supportedStyles;
  List<FrameColorType> get supportedColors;
  List<GlassType> get supportedGlassTypes;
  List<HandleType> get supportedHandles;

  ProductConfiguration createDefaultConfiguration(String projectName);

  String? validate(ProductConfiguration config);
}

class CustomProductDefinition extends ProductDefinition {
  final DimensionRange _widthLimits;
  final DimensionRange _heightLimits;
  final DimensionRange _depthLimits;
  final int _minSections;
  final int _maxSections;
  final List<WindowStyle> _supportedStyles;
  final List<FrameColorType> _supportedColors;
  final List<GlassType> _supportedGlassTypes;
  final List<HandleType> _supportedHandles;

  const CustomProductDefinition({
    required super.type,
    required super.title,
    required super.description,
    required super.icon,
    super.isAvailable = true,
    DimensionRange widthLimits = const DimensionRange(minMm: 300, maxMm: 6000, defaultMm: 1200),
    DimensionRange heightLimits = const DimensionRange(minMm: 300, maxMm: 4000, defaultMm: 1500),
    DimensionRange depthLimits = const DimensionRange(minMm: 30, maxMm: 200, defaultMm: 50),
    int minSections = 1,
    int maxSections = 10,
    List<WindowStyle>? supportedStyles,
    List<FrameColorType>? supportedColors,
    List<GlassType>? supportedGlassTypes,
    List<HandleType>? supportedHandles,
  })  : _widthLimits = widthLimits,
        _heightLimits = heightLimits,
        _depthLimits = depthLimits,
        _minSections = minSections,
        _maxSections = maxSections,
        _supportedStyles = supportedStyles ?? WindowStyle.values,
        _supportedColors = supportedColors ?? FrameColorType.values,
        _supportedGlassTypes = supportedGlassTypes ?? GlassType.values,
        _supportedHandles = supportedHandles ?? HandleType.values;

  @override
  DimensionRange get widthLimits => _widthLimits;

  @override
  DimensionRange get heightLimits => _heightLimits;

  @override
  DimensionRange get depthLimits => _depthLimits;

  @override
  int get minSections => _minSections;

  @override
  int get maxSections => _maxSections;

  @override
  List<WindowStyle> get supportedStyles => _supportedStyles;

  @override
  List<FrameColorType> get supportedColors => _supportedColors;

  @override
  List<GlassType> get supportedGlassTypes => _supportedGlassTypes;

  @override
  List<HandleType> get supportedHandles => _supportedHandles;

  @override
  ProductConfiguration createDefaultConfiguration(String projectName) {
    return ProductConfiguration(
      id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
      projectName: projectName.isNotEmpty ? projectName : 'New $title',
      productType: type,
      widthMm: _widthLimits.defaultMm,
      heightMm: _heightLimits.defaultMm,
      depthMm: _depthLimits.defaultMm,
      style: _supportedStyles.isNotEmpty ? _supportedStyles.first : WindowStyle.sliding,
      sections: _minSections > 1 ? _minSections : 2,
      frameColor: FrameColorType.black,
      glassType: GlassType.clear,
      handleType: _supportedHandles.contains(HandleType.standardPull)
          ? HandleType.standardPull
          : (_supportedHandles.isNotEmpty ? _supportedHandles.first : HandleType.none),
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String? validate(ProductConfiguration config) {
    if (config.widthMm < _widthLimits.minMm || config.widthMm > _widthLimits.maxMm) {
      return 'Width must be between ${_widthLimits.minMm.toInt()} and ${_widthLimits.maxMm.toInt()} mm';
    }
    if (config.heightMm < _heightLimits.minMm || config.heightMm > _heightLimits.maxMm) {
      return 'Height must be between ${_heightLimits.minMm.toInt()} and ${_heightLimits.maxMm.toInt()} mm';
    }
    if (config.sections < _minSections || config.sections > _maxSections) {
      return 'Sections must be between $_minSections and $_maxSections';
    }
    return null;
  }
}
