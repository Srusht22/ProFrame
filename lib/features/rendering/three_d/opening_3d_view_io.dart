import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/scene_3d.dart';
import 'scene_bridge.dart';

/// flutter_inappwebview — and therefore the WebGL renderer — supports
/// Android, iOS, macOS and Windows. On any other platform the viewer says so
/// plainly and shows what the model contains, rather than pretending to
/// render something it cannot.
bool get _webViewSupported {
  if (kIsWeb) return true;
  try {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows;
  } catch (_) {
    return false;
  }
}

Widget buildOpening3DView({
  required Scene3D scene,
  required SceneBridge bridge,
  required bool autoRotate,
  required bool showDimensions,
}) =>
    _webViewSupported
        ? _WebViewOpening3DView(
            scene: scene,
            bridge: bridge,
            autoRotate: autoRotate,
            showDimensions: showDimensions,
          )
        : _UnsupportedPlatformNotice(scene: scene);

class _UnsupportedPlatformNotice extends StatelessWidget {
  final Scene3D scene;

  const _UnsupportedPlatformNotice({required this.scene});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.neutralSurface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar_outlined, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                '3D preview is not available on this platform',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'The model is fully generated — ${scene.parts.length} parts, '
                '${scene.widthMm.round()} x ${scene.heightMm.round()} mm — '
                'and renders on Android, iOS, macOS, Windows and the web.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebViewOpening3DView extends StatefulWidget {
  final Scene3D scene;
  final SceneBridge bridge;
  final bool autoRotate;
  final bool showDimensions;

  const _WebViewOpening3DView({
    required this.scene,
    required this.bridge,
    required this.autoRotate,
    required this.showDimensions,
  });

  @override
  State<_WebViewOpening3DView> createState() => _WebViewOpening3DViewState();
}

class _WebViewOpening3DViewState extends State<_WebViewOpening3DView> {
  String? _html;
  bool _loading = true;
  Timer? _readyTimeout;

  @override
  void initState() {
    super.initState();
    _inlineAssets();
    // If onLoadStop never fires (some embedded webviews), publish anyway so a
    // blank viewer is never left on screen.
    _readyTimeout = Timer(const Duration(seconds: 4), _publish);
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    widget.bridge.detach();
    super.dispose();
  }

  Future<void> _inlineAssets() async {
    try {
      final html = await rootBundle.loadString('assets/web_3d/index.html');
      final three = await rootBundle.loadString('assets/web_3d/three.min.js');
      final controls = await rootBundle.loadString('assets/web_3d/OrbitControls.js');
      final engine = await rootBundle.loadString('assets/web_3d/opening_engine.js');
      final inlined = html
          .replaceFirst('<script src="three.min.js"></script>', '<script>$three</script>')
          .replaceFirst('<script src="OrbitControls.js"></script>', '<script>$controls</script>')
          .replaceFirst('<script src="opening_engine.js"></script>', '<script>$engine</script>');
      if (mounted) setState(() => _html = inlined);
    } catch (error) {
      debugPrint('[Opening3DView] could not load 3D assets: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _publish() {
    if (!mounted) return;
    if (_loading) setState(() => _loading = false);
    widget.bridge.markReady();
    widget.bridge.updateScene(widget.scene);
    widget.bridge.toggleAutoRotate(widget.autoRotate);
    widget.bridge.toggleDimensions(widget.showDimensions);
  }

  @override
  void didUpdateWidget(covariant _WebViewOpening3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scene, widget.scene)) {
      widget.bridge.updateScene(widget.scene);
    }
    if (oldWidget.autoRotate != widget.autoRotate) {
      widget.bridge.toggleAutoRotate(widget.autoRotate);
    }
    if (oldWidget.showDimensions != widget.showDimensions) {
      widget.bridge.toggleDimensions(widget.showDimensions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final html = _html;
    if (html == null) return const _ViewerPlaceholder();

    return Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          initialData: InAppWebViewInitialData(
            data: html,
            mimeType: 'text/html',
            encoding: 'utf-8',
            baseUrl: WebUri('http://localhost/'),
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: false,
            disableContextMenu: true,
            supportZoom: false,
            useWideViewPort: true,
            javaScriptEnabled: true,
          ),
          onWebViewCreated: widget.bridge.attachController,
          onLoadStop: (_, _) => _publish(),
          onConsoleMessage: (_, message) => debugPrint('[three.js] ${message.message}'),
        ),
        if (_loading) const _ViewerPlaceholder(),
      ],
    );
  }
}

class _ViewerPlaceholder extends StatelessWidget {
  const _ViewerPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: AppColors.neutralSurface,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.brandDarkGreen),
          ),
        ),
      );
}
