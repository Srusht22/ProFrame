// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../../domain/configuration/product_configuration.dart';
import '../bridge/webgl_bridge.dart';

Widget buildPlatform3DViewer({
  Key? key,
  required ProductConfiguration configuration,
  required WebGLBridge bridge,
  bool autoRotate = false,
}) {
  return WebProduct3DViewer(
    key: key,
    configuration: configuration,
    bridge: bridge,
    autoRotate: autoRotate,
  );
}

class WebProduct3DViewer extends StatefulWidget {
  final ProductConfiguration configuration;
  final WebGLBridge bridge;
  final bool autoRotate;

  const WebProduct3DViewer({
    super.key,
    required this.configuration,
    required this.bridge,
    this.autoRotate = false,
  });

  @override
  State<WebProduct3DViewer> createState() => _WebProduct3DViewerState();
}

class _WebProduct3DViewerState extends State<WebProduct3DViewer> {
  static int _viewIdCounter = 0;
  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  bool _isLoading = true;
  Timer? _safetyTimeout;

  @override
  void initState() {
    super.initState();
    _viewIdCounter++;
    _viewType = 'proframe-3d-iframe-$_viewIdCounter';

    widget.bridge.attachWebSender((action, data) {
      _sendMessage(action, data);
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..id = 'proframe-3d-iframe-element'
          ..src = 'assets/assets/web_3d/index.html?embedded=true'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#f1f5f9'
          ..allow = 'autoplay; fullscreen';

        iframe.onLoad.listen((_) {
          if (mounted && _isLoading) {
            setState(() {
              _isLoading = false;
            });
            widget.bridge.markReady();
            _sendConfiguration(widget.configuration);
          }
        });

        _iframe = iframe;
        return iframe;
      },
    );

    // Guaranteed fallback: Hide spinner after 1000ms and initialize
    _safetyTimeout = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
        widget.bridge.markReady();
        _sendConfiguration(widget.configuration);
      }
    });

    _messageSubscription = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is Map) {
        final handler = data['handler'];
        if (handler == 'onEngineReady') {
          if (mounted && _isLoading) {
            setState(() {
              _isLoading = false;
            });
          }
          widget.bridge.markReady();
          _sendConfiguration(widget.configuration);
        } else if (handler == 'onSnapshotData') {
          final payload = data['data'];
          if (payload is Map && payload['dataUrl'] is String) {
            widget.bridge.onSnapshotReceived?.call(payload['dataUrl'] as String);
          }
        }
      }
    });
  }

  void _sendMessage(String action, Map<String, dynamic> data) {
    html.IFrameElement? targetIframe = _iframe;
    if (targetIframe == null || targetIframe.contentWindow == null) {
      targetIframe = html.document.getElementById('proframe-3d-iframe-element') as html.IFrameElement?;
    }
    if (targetIframe != null && targetIframe.contentWindow != null) {
      final payload = jsonEncode({'action': action, ...data});
      targetIframe.contentWindow!.postMessage(payload, '*');
    }
  }

  void _sendConfiguration(ProductConfiguration config) {
    _sendMessage('updateConfiguration', {'params': config.to3DParams()});
  }

  @override
  void didUpdateWidget(covariant WebProduct3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration != widget.configuration) {
      _sendConfiguration(widget.configuration);
    }
    if (oldWidget.autoRotate != widget.autoRotate) {
      _sendMessage('toggleAutoRotate', {'enabled': widget.autoRotate});
    }
  }

  @override
  void dispose() {
    _safetyTimeout?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(viewType: _viewType),
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
