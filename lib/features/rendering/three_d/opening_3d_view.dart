import 'package:flutter/material.dart';

import '../../../shared/models/scene_3d.dart';
import 'opening_3d_view_io.dart'
    if (dart.library.html) 'opening_3d_view_web.dart' as platform;
import 'scene_bridge.dart';

/// Real procedural 3D — never a picture of a door.
///
/// The widget is a thin platform shim: a WebView on mobile and desktop, an
/// iframe on the web, both running the same three.js engine and both fed the
/// same [Scene3D] built in Dart.
class Opening3DView extends StatelessWidget {
  final Scene3D scene;
  final SceneBridge bridge;
  final bool autoRotate;
  final bool showDimensions;

  const Opening3DView({
    super.key,
    required this.scene,
    required this.bridge,
    this.autoRotate = false,
    this.showDimensions = false,
  });

  @override
  Widget build(BuildContext context) => platform.buildOpening3DView(
        scene: scene,
        bridge: bridge,
        autoRotate: autoRotate,
        showDimensions: showDimensions,
      );
}
