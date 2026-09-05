import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../data/repositories/project_repository_impl.dart';
import '../../../../domain/configuration/product_configuration.dart';
import '../../../../three_d/bridge/webgl_bridge.dart';
import '../../../../three_d/viewer/product_3d_viewer.dart';
import '../controllers/configurator_controller.dart';
import 'widgets/camera_hud.dart';
import 'widgets/live_edit_panel.dart';

class ConfiguratorScreen extends StatefulWidget {
  final ProductConfiguration initialConfig;

  const ConfiguratorScreen({
    super.key,
    required this.initialConfig,
  });

  @override
  State<ConfiguratorScreen> createState() => _ConfiguratorScreenState();
}

class _ConfiguratorScreenState extends State<ConfiguratorScreen> {
  late final WebGLBridge _bridge;
  late final ConfiguratorController _controller;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bridge = WebGLBridge();
    _controller = ConfiguratorController(
      initialConfig: widget.initialConfig,
      repository: ProjectRepositoryImpl(),
      bridge: _bridge,
    );
    _titleController.text = widget.initialConfig.projectName;

    _controller.addListener((state) {
      if (mounted) {
        setState(() {});
        if (state.statusMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.statusMessage!),
              backgroundColor: AppTheme.accentSuccess,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _bridge.detach();
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    _controller.setProjectName(_titleController.text.trim());
    await _controller.saveProject();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.currentState;
    final isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: SizedBox(
          width: 300,
          child: TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              hintText: 'Project Name',
              border: InputBorder.none,
            ),
            onSubmitted: (val) => _controller.setProjectName(val),
          ),
        ),
        actions: [
          // Undo Button
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: state.canUndo ? () => _controller.undo() : null,
            color: state.canUndo ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
          // Redo Button
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Redo',
            onPressed: state.canRedo ? () => _controller.redo() : null,
            color: state.canRedo ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          // Primary Save Action
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: state.isSaving ? null : _handleSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout(state) : _buildMobileLayout(state),
    );
  }

  Widget _buildDesktopLayout(ConfiguratorState state) {
    return Row(
      children: [
        // 3D VIEWER & VIEWPORT CONTROLS
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Expanded(
                child: Product3DViewer(
                  configuration: state.config,
                  bridge: _bridge,
                  autoRotate: state.autoRotate,
                ),
              ),
              // Dedicated Bottom Viewport Controls Dock (Outside iframe - 100% click safe)
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(
                    top: BorderSide(color: AppTheme.surfaceBorder, width: 1),
                  ),
                ),
                child: Center(
                  child: CameraHUD(
                    onPresetSelected: (preset) => _controller.setCameraPreset(preset),
                    onResetView: () => _controller.resetView(),
                    onToggleAutoRotate: () => _controller.toggleAutoRotate(),
                    onToggleDimensions: () => _controller.toggleDimensions(),
                    isAutoRotateActive: state.autoRotate,
                    areDimensionsActive: state.config.showDimensions,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Vertical divider
        Container(width: 1, color: AppTheme.surfaceBorder),

        // PARAMETER EDIT SIDEBAR (Right area)
        SizedBox(
          width: 380,
          child: LiveEditPanel(
            state: state,
            controller: _controller,
            onSave: _handleSave,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ConfiguratorState state) {
    return Column(
      children: [
        // 3D VIEWER & CONTROLS (Top half)
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Expanded(
                child: Product3DViewer(
                  configuration: state.config,
                  bridge: _bridge,
                  autoRotate: state.autoRotate,
                ),
              ),
              Container(
                height: 50,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(
                    top: BorderSide(color: AppTheme.surfaceBorder, width: 1),
                  ),
                ),
                child: Center(
                  child: CameraHUD(
                    onPresetSelected: (preset) => _controller.setCameraPreset(preset),
                    onResetView: () => _controller.resetView(),
                    onToggleAutoRotate: () => _controller.toggleAutoRotate(),
                    onToggleDimensions: () => _controller.toggleDimensions(),
                    isAutoRotateActive: state.autoRotate,
                    areDimensionsActive: state.config.showDimensions,
                  ),
                ),
              ),
            ],
          ),
        ),

        Container(height: 1, color: AppTheme.surfaceBorder),

        // CONTROLS (Bottom half)
        Expanded(
          flex: 5,
          child: LiveEditPanel(
            state: state,
            controller: _controller,
            onSave: _handleSave,
          ),
        ),
      ],
    );
  }
}
