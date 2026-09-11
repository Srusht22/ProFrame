import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../shared/models/scene_3d.dart';

typedef WebMessageSender = void Function(String action, Map<String, dynamic> data);

/// What the user tapped in the 3D view.
class TappedPart {
  final String? role;
  final String? cellPath;
  final String? partId;

  const TappedPart({this.role, this.cellPath, this.partId});

  bool get isNothing => role == null;

  /// The component's name in plain words, for "Selected: ...".
  String get label => switch (role) {
        null => 'Nothing',
        'frameHead' => 'Frame — head',
        'frameSill' => 'Frame — sill',
        'frameJambLeft' => 'Frame — left jamb',
        'frameJambRight' => 'Frame — right jamb',
        'mullion' => 'Mullion',
        'transom' => 'Transom',
        'sashStile' => 'Sash stile',
        'sashRail' => 'Sash rail',
        'glazingBead' => 'Glazing bead',
        'glass' => 'Glass',
        'panel' => 'Panel',
        'louvreBlade' => 'Louvre blade',
        'mesh' => 'Insect mesh',
        'hinge' => 'Hinge',
        'handle' => 'Handle',
        'handleRose' => 'Handle rose',
        'lockCylinder' => 'Lock',
        'threshold' => 'Threshold',
        'windowSill' => 'Window sill',
        _ => role!,
      };

  factory TappedPart.fromJson(Map<String, dynamic> json) => TappedPart(
        role: json['role'] as String?,
        cellPath: json['cellPath'] as String?,
        partId: json['partId'] as String?,
      );
}

/// Talks to `assets/web_3d/opening_engine.js`.
///
/// One API, two transports: `evaluateJavascript` inside the WebView on
/// mobile/desktop, `postMessage` into the iframe on the web. The payload is
/// identical in both cases — the serialised [Scene3D].
class SceneBridge {
  InAppWebViewController? _controller;
  WebMessageSender? _webSender;
  bool _isReady = false;
  Scene3D? _pendingScene;
  final Map<String, Object?> _pendingCommands = {};

  void Function(String pngDataUrl)? onSnapshot;

  /// A part the user tapped in the 3D view. [cellPath] is null for parts that
  /// belong to the frame rather than to a section.
  void Function(TappedPart part)? onPartTapped;

  bool get isReady => _isReady;

  void attachController(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'onEngineReady',
      callback: (_) => markReady(),
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPartTapped',
      callback: (args) {
        if (args.isNotEmpty && args.first is Map) {
          onPartTapped?.call(TappedPart.fromJson(Map<String, dynamic>.from(
            args.first as Map,
          )));
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onSnapshotData',
      callback: (args) {
        if (args.isNotEmpty && args.first is Map) {
          final url = (args.first as Map)['dataUrl'];
          if (url is String) onSnapshot?.call(url);
        }
      },
    );
  }

  void attachWebSender(WebMessageSender sender) => _webSender = sender;

  void markReady() {
    if (_isReady) return;
    _isReady = true;
    final pending = _pendingScene;
    if (pending != null) {
      _pendingScene = null;
      updateScene(pending);
    }
    _pendingCommands.forEach((action, value) => _send(action, _payloadFor(action, value)));
    _pendingCommands.clear();
  }

  void detach() {
    _controller = null;
    _webSender = null;
    _isReady = false;
  }

  void updateScene(Scene3D scene) {
    if (!_isReady && _webSender == null) {
      _pendingScene = scene;
      return;
    }
    _send('updateScene', {'scene': scene.toJson()});
  }

  void setCameraPreset(CameraPreset preset) =>
      _queueOrSend('setCameraPreset', preset.name);

  void setStyle(RenderStyle style) => _queueOrSend('setStyle', style.name);

  void toggleDimensions(bool visible) => _queueOrSend('toggleDimensions', visible);

  void toggleAutoRotate(bool enabled) => _queueOrSend('toggleAutoRotate', enabled);

  void highlightCell(String? cellPath) => _queueOrSend('highlightCell', cellPath);

  void resetView() => _send('resetView', const {});

  void requestSnapshot() => _send('requestSnapshot', const {});

  void _queueOrSend(String action, Object? value) {
    if (!_isReady && _webSender == null) {
      _pendingCommands[action] = value;
      return;
    }
    _send(action, _payloadFor(action, value));
  }

  Map<String, dynamic> _payloadFor(String action, Object? value) => switch (action) {
        'setCameraPreset' => {'preset': value},
        'setStyle' => {'style': value},
        'toggleDimensions' => {'visible': value},
        'toggleAutoRotate' => {'enabled': value},
        'highlightCell' => {'cellPath': value},
        _ => const {},
      };

  void _send(String action, Map<String, dynamic> data) {
    final sender = _webSender;
    if (sender != null) {
      sender(action, data);
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    final js = switch (action) {
      'updateScene' =>
        'window.OpeningViewer && window.OpeningViewer.updateScene(${jsonEncode(data['scene'])});',
      'setCameraPreset' =>
        'window.OpeningViewer && window.OpeningViewer.setCameraPreset(${jsonEncode(data['preset'])});',
      'setStyle' =>
        'window.OpeningViewer && window.OpeningViewer.setStyle(${jsonEncode(data['style'])});',
      'toggleDimensions' =>
        'window.OpeningViewer && window.OpeningViewer.toggleDimensions(${data['visible']});',
      'toggleAutoRotate' =>
        'window.OpeningViewer && window.OpeningViewer.toggleAutoRotate(${data['enabled']});',
      'highlightCell' =>
        'window.OpeningViewer && window.OpeningViewer.highlightCell(${jsonEncode(data['cellPath'])});',
      'resetView' => 'window.OpeningViewer && window.OpeningViewer.resetView();',
      'requestSnapshot' => 'window.OpeningViewer && window.OpeningViewer.requestSnapshot();',
      _ => '',
    };
    if (js.isEmpty) return;
    controller.evaluateJavascript(source: js).catchError((Object error) {
      debugPrint('[SceneBridge] $action failed: $error');
      return null;
    });
  }
}
