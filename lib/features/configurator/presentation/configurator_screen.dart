import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/auth/permission.dart';
import '../../../domain/configuration/config_enums.dart';
import '../../../domain/configuration/product_configuration.dart';
import '../../../domain/manufacturing/bom_line.dart';
import '../../../domain/manufacturing/cutting_list_line.dart';
import '../../../domain/pricing/price_breakdown.dart';
import '../../../domain/services/validation_engine.dart';
import '../../../shared/providers/auth_notifier.dart';
import '../../../shared/providers/configuration_notifier.dart';
import '../../../shared/providers/project_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../../shared/widgets/price_breakdown_view.dart';
import '../services/export_service.dart';
import 'widgets/steps/accessories_step.dart';
import 'widgets/steps/dimensions_step.dart';
import 'widgets/steps/finish_step.dart';
import 'widgets/steps/frame_step.dart';
import 'widgets/steps/hardware_step.dart';
import 'widgets/steps/panel_glass_step.dart';
import 'widgets/steps/preview_step.dart';
import 'widgets/steps/product_step.dart';
import 'widgets/steps/summary_step.dart';

class ConfiguratorScreen extends ConsumerWidget {
  final String? configurationId;
  final String? projectId;
  final String? categoryParam;

  const ConfiguratorScreen({super.key, this.configurationId, this.projectId, this.categoryParam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      permission: Permission.useConfigurator,
      child: AsyncValueView(
        value: ref.watch(configurationNotifierProvider),
        onRetry: () => ref.invalidate(configurationNotifierProvider),
        builder: (list) {
          final existing = configurationId != null ? list.firstWhereOrNull((c) => c.id == configurationId) : null;
          return _ConfiguratorEditor(
            initial: existing,
            projectId: projectId,
            categoryParam: categoryParam,
          );
        },
      ),
    );
  }
}

const _stepTitles = [
  'Product',
  'Dimensions',
  'Frame & sections',
  'Panel & glass',
  'Hardware',
  'Finish',
  'Accessories',
  'Preview',
  'Summary & price',
];

class _ConfiguratorEditor extends ConsumerStatefulWidget {
  final ProductConfiguration? initial;
  final String? projectId;
  final String? categoryParam;

  const _ConfiguratorEditor({this.initial, this.projectId, this.categoryParam});

  @override
  ConsumerState<_ConfiguratorEditor> createState() => _ConfiguratorEditorState();
}

class _ConfiguratorEditorState extends ConsumerState<_ConfiguratorEditor> {
  late ProductConfiguration _config;
  int _stepIndex = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _config = widget.initial!;
    } else {
      final category = widget.categoryParam == 'door' ? ProductCategory.door : ProductCategory.window;
      _config = ProductConfiguration.newDraft(
        name: category == ProductCategory.door ? 'New Door' : 'New Window',
        category: category,
        projectId: widget.projectId,
        createdByUserId: ref.read(currentUserProvider)?.id,
      );
    }
  }

  void _update(ProductConfiguration next) => setState(() => _config = next);

  Future<void> _save() async {
    setState(() => _saving = true);
    final isNew = widget.initial == null;
    await ref.read(configurationNotifierProvider.notifier).save(_config, isNew: isNew);

    if (widget.projectId != null) {
      final project = ref.read(projectNotifierProvider).value?.firstWhereOrNull((p) => p.id == widget.projectId);
      if (project != null && !project.configurationIds.contains(_config.id)) {
        await ref.read(projectNotifierProvider.notifier).save(
              project.copyWith(configurationIds: [...project.configurationIds, _config.id]),
              isNew: false,
            );
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved.')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final validation = ref.watch(validationEngineProvider).validate(_config);
    final breakdown = ref.watch(pricingEngineProvider).calculate(_config);
    final bom = ref.watch(manufacturingEngineProvider).generateBom(_config, ref.watch(pricingEngineProvider).rules);
    final cuttingList = ref.watch(manufacturingEngineProvider).generateCuttingList(_config);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppSpacing.breakpointMedium;

    final stepContent = _buildStep(context, validation, breakdown, bom, cuttingList);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
        title: Text(_config.name.isEmpty ? 'New configuration' : _config.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (value) {
              const exporter = ExportService();
              switch (value) {
                case 'bom':
                  exporter.shareBom(_config, bom);
                  break;
                case 'cutting':
                  exporter.shareCuttingList(_config, cuttingList);
                  break;
                case 'json':
                  exporter.shareConfigurationJson(_config);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'bom', child: Text('Export BOM (CSV)')),
              PopupMenuItem(value: 'cutting', child: Text('Export cutting list (CSV)')),
              PopupMenuItem(value: 'json', child: Text('Export configuration (JSON)')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_stepIndex + 1) / _stepTitles.length,
            minHeight: 4,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            color: AppColors.brandDarkGreen,
          ),
        ),
      ),
      body: isDesktop ? _desktopLayout(stepContent, breakdown) : stepContent,
      bottomNavigationBar: _bottomBar(context, validation),
    );
  }

  Widget _desktopLayout(Widget stepContent, PriceBreakdown breakdown) {
    return Row(
      children: [
        Expanded(flex: 4, child: stepContent),
        const VerticalDivider(width: 1),
        Expanded(flex: 4, child: PreviewStep(config: _config)),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Live price', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              PriceBreakdownView(breakdown: breakdown),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context,
    ValidationResult validation,
    PriceBreakdown breakdown,
    List<BomLine> bom,
    List<CuttingListLine> cuttingList,
  ) {
    switch (_stepIndex) {
      case 0:
        return ProductStep(config: _config, onChanged: _update);
      case 1:
        return DimensionsStep(config: _config, onChanged: _update);
      case 2:
        return FrameStep(config: _config, onChanged: _update);
      case 3:
        return PanelGlassStep(config: _config, onChanged: _update);
      case 4:
        return HardwareStep(config: _config, onChanged: _update);
      case 5:
        return FinishStep(config: _config, onChanged: _update);
      case 6:
        return AccessoriesStep(config: _config, onChanged: _update);
      case 7:
        return PreviewStep(config: _config);
      case 8:
      default:
        return SummaryStep(config: _config, validation: validation, breakdown: breakdown, bom: bom, cuttingList: cuttingList);
    }
  }

  Widget _bottomBar(BuildContext context, ValidationResult validation) {
    final isLast = _stepIndex == _stepTitles.length - 1;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final backButton = _stepIndex > 0
              ? OutlinedButton(
                  onPressed: () => setState(() => _stepIndex--),
                  child: const Text('Back'),
                )
              : null;
          final nextButton = FilledButton(
            onPressed: _saving
                ? null
                : isLast
                    ? (validation.isValid ? _save : null)
                    : () => setState(() => _stepIndex++),
            child: Text(
              _saving ? 'Saving…' : (isLast ? 'Save configuration' : 'Next'),
              overflow: TextOverflow.ellipsis,
            ),
          );

          // On phones the step label is dropped so the two actions always
          // fit — a "Save configuration" button pushed off-screen would be
          // unreachable.
          if (constraints.maxWidth < 480) {
            return Row(
              children: [
                if (backButton != null) ...[
                  Expanded(child: backButton),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(flex: 2, child: nextButton),
              ],
            );
          }

          return Row(
            children: [
              Flexible(
                child: Text(
                  _stepTitles[_stepIndex],
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (backButton != null) ...[backButton, const SizedBox(width: AppSpacing.sm)],
              nextButton,
            ],
          );
        },
      ),
    );
  }
}
