import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/configuration/product_configuration.dart';
import '../bridge/webgl_bridge.dart';

Widget buildPlatform3DViewer({
  Key? key,
  required ProductConfiguration configuration,
  required WebGLBridge bridge,
  bool autoRotate = false,
}) {
  return MobileProduct3DViewer(
    key: key,
    configuration: configuration,
    bridge: bridge,
    autoRotate: autoRotate,
  );
}

class MobileProduct3DViewer extends StatefulWidget {
  final ProductConfiguration configuration;
  final WebGLBridge bridge;
  final bool autoRotate;

  const MobileProduct3DViewer({
    super.key,
    required this.configuration,
    required this.bridge,
    this.autoRotate = false,
  });

  @override
  State<MobileProduct3DViewer> createState() => _MobileProduct3DViewerState();
}

class _MobileProduct3DViewerState extends State<MobileProduct3DViewer> {
  bool _isLoading = true;
  String? _combinedHtml;
  Timer? _safetyTimeout;

  @override
  void initState() {
    super.initState();
    _loadBundledAssets();
    _safetyTimeout = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
        widget.bridge.markReady();
        widget.bridge.updateConfiguration(widget.configuration);
      }
    });
  }

  @override
  void dispose() {
    _safetyTimeout?.cancel();
    super.dispose();
  }

  Future<void> _loadBundledAssets() async {
    try {
      final html = await rootBundle.loadString('assets/web_3d/index.html');
      final threeJs = await rootBundle.loadString('assets/web_3d/three.min.js');
      final controlsJs = await rootBundle.loadString('assets/web_3d/OrbitControls.js');
      final engineJs = await rootBundle.loadString('assets/web_3d/parametric_engine.js');

      final inlined = html
          .replaceFirst('<script src="three.min.js"></script>', '<script>$threeJs</script>')
          .replaceFirst('<script src="OrbitControls.js"></script>', '<script>$controlsJs</script>')
          .replaceFirst('<script src="parametric_engine.js"></script>', '<script>$engineJs</script>');

      if (mounted) {
        setState(() {
          _combinedHtml = inlined;
        });
      }
    } catch (e) {
      debugPrint('[Product3DViewer] Error loading 3D assets: $e');
    }
  }

  @override
  void didUpdateWidget(covariant MobileProduct3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration != widget.configuration) {
      widget.bridge.updateConfiguration(widget.configuration);
    }
    if (oldWidget.autoRotate != widget.autoRotate) {
      widget.bridge.toggleAutoRotate(widget.autoRotate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_combinedHtml == null) {
      return Container(
        color: const Color(0xFF14161A),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF38BDF8),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Initializing 3D Engine...',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          initialData: InAppWebViewInitialData(
            data: _combinedHtml!,
            mimeType: 'text/html',
            encoding: 'utf-8',
            baseUrl: WebUri('http://localhost/'),
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: false,
            disableContextMenu: true,
            supportZoom: false,
            useWideViewPort: true,
            allowsInlineMediaPlayback: true,
            javaScriptEnabled: true,
          ),
          onWebViewCreated: (controller) {
            widget.bridge.attachController(controller);
          },
          onLoadStop: (controller, url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              widget.bridge.markReady();
              widget.bridge.updateConfiguration(widget.configuration);
            }
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('[ThreeJS Console] ${consoleMessage.message}');
          },
        ),
        if (_isLoading)
          Container(
            color: const Color(0xFF14161A),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF38BDF8),
                strokeWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}
