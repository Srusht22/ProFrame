import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme.dart';
import '../../../../domain/configuration/configuration_options.dart';
import '../../controllers/configurator_controller.dart';
import 'color_palette_bar.dart';
import 'glass_picker_bar.dart';

class LiveEditPanel extends StatefulWidget {
  final ConfiguratorState state;
  final ConfiguratorController controller;
  final VoidCallback onSave;

  const LiveEditPanel({
    super.key,
    required this.state,
    required this.controller,
    required this.onSave,
  });

  @override
  State<LiveEditPanel> createState() => _LiveEditPanelState();
}

class _LiveEditPanelState extends State<LiveEditPanel> {
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(text: widget.state.config.widthMm.round().toString());
    _heightController = TextEditingController(text: widget.state.config.heightMm.round().toString());
    _notesController = TextEditingController(text: widget.state.config.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant LiveEditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.config.widthMm != widget.state.config.widthMm) {
      final currentText = _widthController.text;
      final newText = widget.state.config.widthMm.round().toString();
      if (currentText != newText) {
        _widthController.text = newText;
      }
    }
    if (oldWidget.state.config.heightMm != widget.state.config.heightMm) {
      final currentText = _heightController.text;
      final newText = widget.state.config.heightMm.round().toString();
      if (currentText != newText) {
        _heightController.text = newText;
      }
    }
    if (oldWidget.state.config.notes != widget.state.config.notes &&
        widget.state.config.notes != _notesController.text) {
      _notesController.text = widget.state.config.notes ?? '';
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.state.config;

    return Container(
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // Validation Error Banner
          if (widget.state.validationError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentDanger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentDanger, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.accentDanger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.state.validationError!,
                      style: const TextStyle(color: AppTheme.accentDanger, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // SECTION 1: DIMENSIONS
          _buildSectionHeader('DIMENSIONS', Icons.straighten_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDimensionField(
                  label: 'Width',
                  controller: _widthController,
                  unit: 'mm',
                  onIncrement: () => widget.controller.setWidth(config.widthMm + 50),
                  onDecrement: () => widget.controller.setWidth(config.widthMm - 50),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null && parsed >= 300) {
                      widget.controller.setWidth(parsed);
                    }
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDimensionField(
                  label: 'Height',
                  controller: _heightController,
                  unit: 'mm',
                  onIncrement: () => widget.controller.setHeight(config.heightMm + 50),
                  onDecrement: () => widget.controller.setHeight(config.heightMm - 50),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null && parsed >= 300) {
                      widget.controller.setHeight(parsed);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SECTION 2: WINDOW STYLE
          _buildSectionHeader('WINDOW STYLE', Icons.view_quilt_rounded),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: WindowStyle.values.map((style) {
              final isSelected = config.style == style;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.controller.setStyle(style),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.surfaceElevated : AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          style.icon,
                          size: 20,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          style.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // SECTION 3: NUMBER OF SECTIONS
          _buildSectionHeader('NUMBER OF SECTIONS', Icons.table_chart_outlined),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [1, 2, 3, 4, 5, 6, 8].map((secCount) {
                final isSelected = config.sections == secCount;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.controller.setSections(secCount),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$secCount',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? AppTheme.onPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // SECTION 4: FRAME COLOR
          _buildSectionHeader('FRAME FINISH', Icons.palette_outlined),
          const SizedBox(height: 12),
          ColorPaletteBar(
            selectedColor: config.frameColor,
            customHexColor: config.customHexColor,
            onColorSelected: (color, [hex]) => widget.controller.setFrameColor(color, hex),
          ),

          const SizedBox(height: 24),

          // SECTION 5: GLASS TYPE
          _buildSectionHeader('GLASS TYPE', Icons.auto_awesome_outlined),
          const SizedBox(height: 12),
          GlassPickerBar(
            selectedGlass: config.glassType,
            onGlassSelected: (glass) => widget.controller.setGlassType(glass),
          ),

          const SizedBox(height: 24),

          // SECTION 6: HARDWARE & DETAILS
          _buildSectionHeader('HARDWARE & OPENING', Icons.lock_outline_rounded),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: HandleType.values.map((handle) {
              final isSelected = config.handleType == handle;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.controller.setHandleType(handle),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.surfaceElevated : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          handle.icon,
                          size: 18,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          handle.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // SECTION 7: JOB NOTES & DETAILS
          _buildSectionHeader('JOB NOTES & REFERENCE', Icons.edit_note_rounded),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Master bedroom slider, 2nd floor, tempered glass...',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
            onChanged: (text) => widget.controller.setNotes(text),
          ),

          const SizedBox(height: 32),

          // SAVE BUTTON
          ElevatedButton.icon(
            onPressed: widget.state.isSaving ? null : widget.onSave,
            icon: widget.state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(widget.state.isSaving ? 'Saving...' : 'Save Design'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionField({
    required String label,
    required TextEditingController controller,
    required String unit,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStepButton(Icons.remove_rounded, onDecrement),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                  ),
                  onChanged: onChanged,
                ),
              ),
              _buildStepButton(Icons.add_rounded, onIncrement),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}
