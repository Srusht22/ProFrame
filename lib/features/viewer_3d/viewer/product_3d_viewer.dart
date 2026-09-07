import 'package:flutter/material.dart';
import '../../../domain/configuration/product_configuration.dart';
import '../bridge/webgl_bridge.dart';

import 'product_3d_viewer_mobile.dart' if (dart.library.html) 'product_3d_viewer_web.dart' as platform_viewer;

/// Real, procedurally-generated 3D — never a static image. Delegates to a
/// WebView (mobile/desktop) or an iframe (web) running the same three.js
/// parametric engine, chosen at compile time via conditional import.
class Product3DViewer extends StatelessWidget {
  final ProductConfiguration configuration;
  final WebGLBridge bridge;
  final bool autoRotate;

  const Product3DViewer({
    super.key,
    required this.configuration,
    required this.bridge,
    this.autoRotate = false,
  });

  @override
  Widget build(BuildContext context) {
    return platform_viewer.buildPlatform3DViewer(
      key: key,
      configuration: configuration,
      bridge: bridge,
      autoRotate: autoRotate,
    );
  }
}
