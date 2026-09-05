import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../domain/configuration/configuration_options.dart';
import '../../../../domain/configuration/product_configuration.dart';
import '../../../../domain/products/product_registry.dart';
import '../../configurator_3d/presentation/configurator_screen.dart';

class QuickWizardScreen extends StatefulWidget {
  final ProductType productType;

  const QuickWizardScreen({
    super.key,
    this.productType = ProductType.window,
  });

  @override
  State<QuickWizardScreen> createState() => _QuickWizardScreenState();
}

class _QuickWizardScreenState extends State<QuickWizardScreen> {
  int _currentStep = 0;

  late final TextEditingController _nameController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;

  WindowStyle _selectedStyle = WindowStyle.sliding;
  int _selectedSections = 2;
  FrameColorType _selectedColor = FrameColorType.black;
  GlassType _selectedGlass = GlassType.clear;

  @override
  void initState() {
    super.initState();
    final def = ProductRegistry.get(widget.productType);
    _nameController = TextEditingController(text: '${def.title} #${IdGenerator.generateShortId()}');
    _widthController = TextEditingController(text: def.widthLimits.defaultMm.toInt().toString());
    _heightController = TextEditingController(text: def.heightLimits.defaultMm.toInt().toString());
    if (def.supportedStyles.isNotEmpty) {
      _selectedStyle = def.supportedStyles.first;
    }
    _selectedSections = def.minSections > 1 ? def.minSections : 2;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _finishWizard() {
    final width = double.tryParse(_widthController.text) ?? AppConstants.defaultWidthMm;
    final height = double.tryParse(_heightController.text) ?? AppConstants.defaultHeightMm;
    final now = DateTime.now();

    final config = ProductConfiguration(
      id: IdGenerator.generate(),
      projectName: _nameController.text.trim().isEmpty ? 'Window #${IdGenerator.generateShortId()}' : _nameController.text.trim(),
      productType: widget.productType,
      widthMm: width,
      heightMm: height,
      depthMm: AppConstants.defaultDepthMm,
      style: _selectedStyle,
      sections: _selectedSections,
      frameColor: _selectedColor,
      glassType: _selectedGlass,
      handleType: _selectedStyle == WindowStyle.fixed ? HandleType.none : HandleType.standardPull,
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      createdAt: now,
      updatedAt: now,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConfiguratorScreen(initialConfig: config),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create New Window'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              // Step Progress Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    _buildStepBadge(0, '1. Size'),
                    _buildStepConnector(0),
                    _buildStepBadge(1, '2. Style'),
                    _buildStepConnector(1),
                    _buildStepBadge(2, '3. Finish'),
                  ],
                ),
              ),

              const Divider(color: AppTheme.surfaceBorder),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildCurrentStepContent(),
                ),
              ),

              // Bottom Navigation Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep--),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentStep < 2) {
                            setState(() => _currentStep++);
                          } else {
                            _finishWizard();
                          }
                        },
                        child: Text(_currentStep < 2 ? 'Next Step' : 'View in 3D 🚀'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBadge(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? AppTheme.accentSuccess : (isActive ? AppTheme.primary : AppTheme.surfaceElevated),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '${stepIndex + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppTheme.onPrimary : AppTheme.textSecondary,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int stepIndex) {
    final isPassed = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: isPassed ? AppTheme.accentSuccess : AppTheme.surfaceBorder,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepSize();
      case 1:
        return _buildStepStyleAndSections();
      case 2:
      default:
        return _buildStepFinish();
    }
  }

  // STEP 1: SIZE
  Widget _buildStepSize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Window Dimensions',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use real factory millimeters (mm). Minimum 400 mm, Maximum 4000 mm.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),

        // Project Name
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Project / Customer Reference',
            prefixIcon: Icon(Icons.bookmark_outline_rounded, color: AppTheme.primary),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _widthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  labelText: 'Width',
                  suffixText: 'mm',
                  prefixIcon: Icon(Icons.swap_horiz_rounded, color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  labelText: 'Height',
                  suffixText: 'mm',
                  prefixIcon: Icon(Icons.swap_vert_rounded, color: AppTheme.primary),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text(
          'Quick Presets:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            _buildPresetChip('Standard 1200 × 1500', 1200, 1500),
            _buildPresetChip('Large 2000 × 1600', 2000, 1600),
            _buildPresetChip('Small 800 × 1000', 800, 1000),
            _buildPresetChip('Panoramic 2400 × 1800', 2400, 1800),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, int w, int h) {
    return ActionChip(
      backgroundColor: AppTheme.surfaceElevated,
      side: const BorderSide(color: AppTheme.surfaceBorder),
      label: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
      onPressed: () {
        setState(() {
          _widthController.text = '$w';
          _heightController.text = '$h';
        });
      },
    );
  }

  // STEP 2: STYLE & SECTIONS
  Widget _buildStepStyleAndSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Style & Sections',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose the opening mechanism and how many panels are required.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),

        // Style Cards
        ...WindowStyle.values.map((style) {
          final isSelected = _selectedStyle == style;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedStyle = style),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.surfaceElevated : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary.withOpacity(0.15) : AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(style.icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style.label,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              style.description,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Radio<WindowStyle>(
                        value: style,
                        groupValue: _selectedStyle,
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStyle = val);
                        },
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 20),
        const Text(
          'How many sections?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [1, 2, 3, 4, 5].map((count) {
            final isSelected = _selectedSections == count;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selectedSections = count),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
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
      ],
    );
  }

  // STEP 3: FINISH (Colors & Glass)
  Widget _buildStepFinish() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frame & Glass Finishes',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pick the aluminum finish and glass type. You can fine-tune in 3D anytime.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),

        const Text(
          'FRAME COLOR',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: FrameColorType.values.where((c) => c != FrameColorType.custom).map((c) {
            final isSelected = _selectedColor == c;
            return ChoiceChip(
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedColor = c),
              backgroundColor: AppTheme.surface,
              selectedColor: AppTheme.surfaceElevated,
              side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder, width: isSelected ? 2 : 1),
              avatar: CircleAvatar(backgroundColor: c.color),
              label: Text(c.label, style: TextStyle(color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        const Text(
          'GLASS TYPE',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: GlassType.values.map((g) {
            final isSelected = _selectedGlass == g;
            return ChoiceChip(
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedGlass = g),
              backgroundColor: AppTheme.surface,
              selectedColor: AppTheme.surfaceElevated,
              side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder, width: isSelected ? 2 : 1),
              avatar: CircleAvatar(backgroundColor: g.previewColor),
              label: Text(g.label, style: TextStyle(color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
