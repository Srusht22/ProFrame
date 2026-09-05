import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../domain/configuration/configuration_options.dart';
import '../../../../domain/products/product_definition.dart';
import '../../../../domain/products/product_registry.dart';

class CreateProductTypeDialog extends StatefulWidget {
  const CreateProductTypeDialog({super.key});

  @override
  State<CreateProductTypeDialog> createState() => _CreateProductTypeDialogState();
}

class _CreateProductTypeDialogState extends State<CreateProductTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  final double _minWidth = 500;
  final double _maxWidth = 5000;
  double _defaultWidth = 1500;

  final double _minHeight = 500;
  final double _maxHeight = 3500;
  double _defaultHeight = 2000;

  int _maxSections = 6;
  String _selectedEmoji = '📐';

  final List<String> _emojiOptions = ['📐', '🚪', '🪟', '🏢', '🗄️', '🏠', '🪜', '🛖', '📦', '🏗️'];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final typeId = 'type_${DateTime.now().millisecondsSinceEpoch}';
    final productType = ProductType(
      id: typeId,
      label: _nameController.text.trim(),
      icon: _selectedEmoji,
      description: _descController.text.trim(),
      isCustom: true,
    );

    final definition = CustomProductDefinition(
      type: productType,
      title: _nameController.text.trim(),
      description: _descController.text.trim(),
      icon: Icons.category_rounded,
      widthLimits: DimensionRange(minMm: _minWidth, maxMm: _maxWidth, defaultMm: _defaultWidth),
      heightLimits: DimensionRange(minMm: _minHeight, maxMm: _maxHeight, defaultMm: _defaultHeight),
      maxSections: _maxSections,
    );

    ProductRegistry.register(definition);
    Navigator.of(context).pop(productType);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.surfaceBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_box_rounded, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Product Type',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Define a custom product category for workers',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Icon & Name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji Picker Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedEmoji,
                            dropdownColor: AppTheme.surfaceElevated,
                            items: _emojiOptions.map((e) {
                              return DropdownMenuItem(
                                value: e,
                                child: Text(e, style: const TextStyle(fontSize: 24)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedEmoji = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Product Type Name *',
                            hintText: 'e.g. Glass Balustrade, Skylight, Pergola',
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                            ),
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Short Description',
                      hintText: 'e.g. Architectural glass railing with aluminum base shoe',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Default Measurements (mm)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Width & Height Defaults
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _defaultWidth.toInt().toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Default Width (mm)',
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                            ),
                          ),
                          onChanged: (v) => _defaultWidth = double.tryParse(v) ?? 1500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _defaultHeight.toInt().toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Default Height (mm)',
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                            ),
                          ),
                          onChanged: (v) => _defaultHeight = double.tryParse(v) ?? 2000,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Max Sections
                  Row(
                    children: [
                      const Text(
                        'Max Panels / Sections:',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: _maxSections,
                        dropdownColor: AppTheme.surfaceElevated,
                        items: [2, 3, 4, 5, 6, 8, 10].map((n) {
                          return DropdownMenuItem(value: n, child: Text('$n panels'));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _maxSections = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submit,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'Save & Start Designing',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
