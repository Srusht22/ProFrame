import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/configuration/product_configuration.dart';
import '../models/scene_messages.dart';

typedef WebMessageSender = void Function(String action, Map<String, dynamic> data);

class WebGLBridge {
  InAppWebViewController? _controller;
  WebMessageSender? _webSender;
  bool _isReady = false;
  ProductConfiguration? _pendingConfig;
  Function(String snapshotBase64)? onSnapshotReceived;

  bool get isReady => _isReady;

  void attachController(InAppWebViewController controller) {
    _controller = controller;

    _controller?.addJavaScriptHandler(
      handlerName: 'onEngineReady',
      callback: (args) {
        markReady();
      },
    );

    _controller?.addJavaScriptHandler(
      handlerName: 'onSnapshotData',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final map = args[0] as Map;
          final dataUrl = map['dataUrl'] as String?;
          if (dataUrl != null && onSnapshotReceived != null) {
            onSnapshotReceived!(dataUrl);
          }
        }
      },
    );
  }

  void attachWebSender(WebMessageSender sender) {
    _webSender = sender;
  }

  void markReady() {
    _isReady = true;
    debugPrint('[WebGLBridge] 3D Engine is ready!');
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
    if (_webSender != null) {
      _webSender!('setCameraPreset', {'preset': preset.id});
      return;
    }

    if (!_isReady || _controller == null) return;
    _controller?.evaluateJavascript(
      source: 'window.ConfiguratorBridge && window.ConfiguratorBridge.setCameraPreset("${preset.id}");',
    );
  }

  void toggleDimensions(bool visible) {
    if (_webSender != null) {
      _webSender!('toggleDimensions', {'visible': visible});
      return;
    }

    if (!_isReady || _controller == null) return;
    _controller?.evaluateJavascript(
      source: 'window.ConfiguratorBridge && window.ConfiguratorBridge.toggleDimensions($visible);',
    );
  }

  void toggleAutoRotate(bool enabled) {
    if (_webSender != null) {
      _webSender!('toggleAutoRotate', {'enabled': enabled});
      return;
    }

    if (!_isReady || _controller == null) return;
    _controller?.evaluateJavascript(
      source: 'window.ConfiguratorBridge && window.ConfiguratorBridge.toggleAutoRotate($enabled);',
    );
  }

  void resetView() {
    if (_webSender != null) {
      _webSender!('resetView', {});
      return;
    }

    if (!_isReady || _controller == null) return;
    _controller?.evaluateJavascript(
      source: 'window.ConfiguratorBridge && window.ConfiguratorBridge.resetView();',
    );
  }

  void requestSnapshot() {
    if (_webSender != null) {
      _webSender!('requestSnapshot', {});
      return;
    }

    if (!_isReady || _controller == null) return;
    _controller?.evaluateJavascript(
      source: 'window.ConfiguratorBridge && window.ConfiguratorBridge.requestSnapshot();',
    );
  }
}
