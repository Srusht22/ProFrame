import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../domain/configuration/product_configuration.dart';
import '../models/camera_preset.dart';

typedef WebMessageSender = void Function(String action, Map<String, dynamic> data);

/// Talks to `assets/web_3d/parametric_engine.js` — on mobile/desktop via
/// `InAppWebView.evaluateJavascript`, on web via `postMessage` into an
/// iframe (wired by [WebMessageSender]). Both transports call the exact
/// same `window.ConfiguratorBridge.*` functions, so the JS engine has a
/// single API regardless of platform.
class WebGLBridge {
  InAppWebViewController? _controller;
  WebMessageSender? _webSender;
  bool _isReady = false;
  ProductConfiguration? _pendingConfig;
  void Function(String snapshotBase64)? onSnapshotReceived;

  bool get isReady => _isReady;

  void attachController(InAppWebViewController controller) {
    _controller = controller;
    _controller?.addJavaScriptHandler(
      handlerName: 'onEngineReady',
      callback: (args) => markReady(),
    );
    _controller?.addJavaScriptHandler(
      handlerName: 'onSnapshotData',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final map = args[0] as Map;
          final dataUrl = map['dataUrl'] as String?;
          if (dataUrl != null) onSnapshotReceived?.call(dataUrl);
        }
      },
    );
  }

  void attachWebSender(WebMessageSender sender) {
    _webSender = sender;
  }

  void markReady() {
    _isReady = true;
    debugPrint('[WebGLBridge] 3D engine ready');
    if (_pendingConfig != null) {
      updateConfiguration(_pendingConfig!);
      _pendingConfig = null;
    }
  }

  void detach() {
    _controller = null;
    _webSender = null;
    _isReady = false;
  }

  void updateConfiguration(ProductConfiguration config) {
    if (_webSender != null) {
      _webSender!('updateConfiguration', {'params': config.to3DParams()});
      return;
    }
    if (!_isReady || _controller == null) {
      _pendingConfig = config;
      return;
    }
    final paramsJson = jsonEncode(config.to3DParams());
    _controller?.evaluateJavascript(
      source: 'window.ConfiguratorBridge && window.ConfiguratorBridge.updateConfiguration($paramsJson);',
    );
  }

  void setCameraPreset(CameraPreset preset) {
    _send('setCameraPreset', {'preset': preset.id},
        js: 'window.ConfiguratorBridge && window.ConfiguratorBridge.setCameraPreset("${preset.id}");');
  }

  void toggleDimensions(bool visible) {
    _send('toggleDimensions', {'visible': visible},
        js: 'window.ConfiguratorBridge && window.ConfiguratorBridge.toggleDimensions($visible);');
  }

  void toggleAutoRotate(bool enabled) {
    _send('toggleAutoRotate', {'enabled': enabled},
        js: 'window.ConfiguratorBridge && window.ConfiguratorBridge.toggleAutoRotate($enabled);');
  }

  void resetView() {
    _send('resetView', {}, js: 'window.ConfiguratorBridge && window.ConfiguratorBridge.resetView();');
  }

  void requestSnapshot() {
    _send('requestSnapshot', {}, js: 'window.ConfiguratorBridge && window.ConfiguratorBridge.requestSnapshot();');
  }

  void _send(String action, Map<String, dynamic> data, {required String js}) {
    if (_webSender != null) {
      _webSender!(action, data);
      return;
    }
    if (!_isReady || _controller == null) return;
    _controller?.evaluateJavascript(source: js);
  }
}
