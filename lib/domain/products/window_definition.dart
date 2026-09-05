import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/id_generator.dart';
import '../configuration/configuration_options.dart';
import '../configuration/product_configuration.dart';
import 'product_definition.dart';

class WindowDefinition extends ProductDefinition {
  const WindowDefinition()
      : super(
          type: ProductType.window,
          title: 'Window',
          description: 'High-performance sliding, casement, and fixed window assemblies',
          icon: Icons.window_rounded,
          isAvailable: true,
        );

  @override
  DimensionRange get widthLimits => const DimensionRange(
        minMm: AppConstants.minWidthMm,
        maxMm: AppConstants.maxWidthMm,
        defaultMm: AppConstants.defaultWidthMm,
      );

  @override
  DimensionRange get heightLimits => const DimensionRange(
        minMm: AppConstants.minHeightMm,
        maxMm: AppConstants.maxHeightMm,
        defaultMm: AppConstants.defaultHeightMm,
      );

  @override
  DimensionRange get depthLimits => const DimensionRange(
        minMm: AppConstants.minDepthMm,
        maxMm: AppConstants.maxDepthMm,
        defaultMm: AppConstants.defaultDepthMm,
      );

  @override
  int get minSections => AppConstants.minSections;

  @override
  int get maxSections => AppConstants.maxSections;

  @override
  List<WindowStyle> get supportedStyles => WindowStyle.values;

  @override
  List<FrameColorType> get supportedColors => FrameColorType.values;

  @override
  List<GlassType> get supportedGlassTypes => GlassType.values;

  @override
  List<HandleType> get supportedHandles => HandleType.values;

  @override
  ProductConfiguration createDefaultConfiguration(String projectName) {
    final now = DateTime.now();
    return ProductConfiguration(
      id: IdGenerator.generate(),
      projectName: projectName,
      productType: ProductType.window,
      widthMm: AppConstants.defaultWidthMm,
      heightMm: AppConstants.defaultHeightMm,
      depthMm: AppConstants.defaultDepthMm,
      style: WindowStyle.sliding,
      sections: AppConstants.defaultSections,
      frameColor: FrameColorType.black,
      glassType: GlassType.clear,
      handleType: HandleType.standardPull,
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  String? validate(ProductConfiguration config) {
    if (!widthLimits.isValid(config.widthMm)) {
      return 'Width must be between ${widthLimits.minMm.toInt()} mm and ${widthLimits.maxMm.toInt()} mm';
    }
    if (!heightLimits.isValid(config.heightMm)) {
      return 'Height must be between ${heightLimits.minMm.toInt()} mm and ${heightLimits.maxMm.toInt()} mm';
    }
    if (config.sections < minSections || config.sections > maxSections) {
      return 'Sections must be between $minSections and $maxSections';
    }
    // Check minimal physical section width
    final netWidth = config.widthMm - 110; // Minus frame jambs
    final minSectionWidth = netWidth / config.sections;
    if (minSectionWidth < 200) {
      return '${config.sections} sections cannot fit within ${config.widthMm.toInt()} mm width';
    }
    return null;
  }
}
