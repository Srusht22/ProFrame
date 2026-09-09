// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/scene_3d.dart';
import 'scene_bridge.dart';

Widget buildOpening3DView({
  required Scene3D scene,
  required SceneBridge bridge,
  required bool autoRotate,
  required bool showDimensions,
}) =>
    _IframeOpening3DView(
      scene: scene,
      bridge: bridge,
      autoRotate: autoRotate,
      showDimensions: showDimensions,
    );

class _IframeOpening3DView extends StatefulWidget {
  final Scene3D scene;
  final SceneBridge bridge;
  final bool autoRotate;
  final bool showDimensions;

  const _IframeOpening3DView({
    required this.scene,
    required this.bridge,
    required this.autoRotate,
    required this.showDimensions,
  });

  @override
  State<_IframeOpening3DView> createState() => _IframeOpening3DViewState();
}

class _IframeOpening3DViewState extends State<_IframeOpening3DView> {
  static int _counter = 0;
  late final String _viewType;
  html.IFrameElement? _frame;
  StreamSubscription<html.MessageEvent>? _messages;
  Timer? _fallback;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _counter++;
    _viewType = 'proframe-3d-$_counter';

    widget.bridge.attachWebSender(_post);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final frame = html.IFrameElement()
        ..src = 'assets/assets/web_3d/index.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#F3F2EC';
      frame.onLoad.listen((_) => _publish());
      _frame = frame;
      return frame;
    });

    _messages = html.window.onMessage.listen(_onMessage);
    _fallback = Timer(const Duration(milliseconds: 1500), _publish);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _messages?.cancel();
    widget.bridge.detach();
    super.dispose();
  }

  void _onMessage(html.MessageEvent event) {
    dynamic data = event.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return;
      }
    }
    if (data is! Map) return;
    switch (data['handler']) {
      case 'onEngineReady':
        _publish();
      case 'onSnapshotData':
        final payload = data['data'];
        if (payload is Map && payload['dataUrl'] is String) {
          widget.bridge.onSnapshot?.call(payload['dataUrl'] as String);
        }
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

  void _post(String action, Map<String, dynamic> data) {
    final target = _frame?.contentWindow;
    if (target == null) return;
    target.postMessage(jsonEncode({'action': action, ...data}), '*');
  }

  @override
  void didUpdateWidget(covariant _IframeOpening3DView oldWidget) {
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
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          if (_loading)
            const ColoredBox(
              color: AppColors.neutralSurface,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.brandDarkGreen,
                  ),
                ),
              ),
            ),
        ],
      );
}
