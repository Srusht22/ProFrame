import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/configuration/configuration_options.dart';
import '../../../domain/configuration/product_configuration.dart';
import '../../../domain/products/product_registry.dart';
import '../../../domain/repositories/i_project_repository.dart';
import '../../../three_d/bridge/webgl_bridge.dart';
import '../../../three_d/models/scene_messages.dart';

class ConfiguratorState {
  final ProductConfiguration config;
  final bool canUndo;
  final bool canRedo;
  final bool autoRotate;
  final bool isSaving;
  final String? validationError;
  final String? statusMessage;

  const ConfiguratorState({
    required this.config,
    this.canUndo = false,
    this.canRedo = false,
    this.autoRotate = false,
    this.isSaving = false,
    this.validationError,
    this.statusMessage,
  });

  ConfiguratorState copyWith({
    ProductConfiguration? config,
    bool? canUndo,
    bool? canRedo,
    bool? autoRotate,
    bool? isSaving,
    String? validationError,
    String? statusMessage,
    bool clearError = false,
  }) {
    return ConfiguratorState(
      config: config ?? this.config,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      autoRotate: autoRotate ?? this.autoRotate,
      isSaving: isSaving ?? this.isSaving,
      validationError: clearError ? null : (validationError ?? this.validationError),
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class ConfiguratorController extends StateNotifier<ConfiguratorState> {
  final IProjectRepository _repository;
  final WebGLBridge bridge;

  ConfiguratorState get currentState => state;

  final List<ProductConfiguration> _undoStack = [];
  final List<ProductConfiguration> _redoStack = [];

  ConfiguratorController({
    required ProductConfiguration initialConfig,
    required IProjectRepository repository,
    required this.bridge,
  })  : _repository = repository,
        super(ConfiguratorState(config: initialConfig)) {
    // Setup snapshot callback to update thumbnail
    bridge.onSnapshotReceived = (dataUrl) {
      _onSnapshotCaptured(dataUrl);
    };
  }

  void _pushHistory(ProductConfiguration oldConfig) {
    _undoStack.add(oldConfig);
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0); // Limit memory
    }
    _redoStack.clear();
  }

  void _updateConfig(ProductConfiguration newConfig, {bool recordHistory = true}) {
    final validationError = ProductRegistry.get(newConfig.productType).validate(newConfig);
    if (validationError != null) {
      state = state.copyWith(validationError: validationError);
      return;
    }

    if (recordHistory) {
      _pushHistory(state.config);
    }

    state = state.copyWith(
      config: newConfig,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      clearError: true,
    );

    bridge.updateConfiguration(newConfig);
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(state.config);

    state = state.copyWith(
      config: previous,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      clearError: true,
    );

    bridge.updateConfiguration(previous);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(state.config);

    state = state.copyWith(
      config: next,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      clearError: true,
    );

    bridge.updateConfiguration(next);
  }

  void setWidth(double widthMm) {
    _updateConfig(state.config.copyWith(widthMm: widthMm));
  }

  void setHeight(double heightMm) {
    _updateConfig(state.config.copyWith(heightMm: heightMm));
  }

  void setDepth(double depthMm) {
    _updateConfig(state.config.copyWith(depthMm: depthMm));
  }

  void setSections(int sections) {
    _updateConfig(state.config.copyWith(sections: sections));
  }

  void setStyle(WindowStyle style) {
    _updateConfig(state.config.copyWith(style: style));
  }

  void setFrameColor(FrameColorType color, [String? hex]) {
    _updateConfig(state.config.copyWith(frameColor: color, customHexColor: hex));
  }

  void setGlassType(GlassType glass) {
    _updateConfig(state.config.copyWith(glassType: glass));
  }

  void setHandleType(HandleType handle) {
    _updateConfig(state.config.copyWith(handleType: handle));
  }

  void setHandleColor(FrameColorType color) {
    _updateConfig(state.config.copyWith(handleColor: color));
  }

  void setOpeningDirection(OpeningDirection dir) {
    _updateConfig(state.config.copyWith(openingDirection: dir));
  }

  void setProjectName(String name) {
    state = state.copyWith(config: state.config.copyWith(projectName: name));
  }

  void setNotes(String notes) {
    state = state.copyWith(config: state.config.copyWith(notes: notes));
  }

  void toggleDimensions() {
    final next = !state.config.showDimensions;
    _updateConfig(state.config.copyWith(showDimensions: next), recordHistory: false);
    bridge.toggleDimensions(next);
  }

  void toggleAutoRotate() {
    final next = !state.autoRotate;
    state = state.copyWith(autoRotate: next);
    bridge.toggleAutoRotate(next);
  }

  void setCameraPreset(CameraPreset preset) {
    bridge.setCameraPreset(preset);
  }

  void resetView() {
    bridge.resetView();
  }

  void requestSnapshot() {
    bridge.requestSnapshot();
  }

  void _onSnapshotCaptured(String base64) {
    state = state.copyWith(config: state.config.copyWith(thumbnailBase64: base64));
    // Persist immediately with thumbnail
    _repository.saveProject(state.config);
  }

  Future<void> saveProject() async {
    state = state.copyWith(isSaving: true);
    try {
      // Request snapshot from WebGL for fresh thumbnail
      bridge.requestSnapshot();
      await _repository.saveProject(state.config);
      state = state.copyWith(isSaving: false, statusMessage: 'Project saved successfully!');
    } catch (e) {
      state = state.copyWith(isSaving: false, validationError: 'Failed to save: $e');
    }
  }
}
