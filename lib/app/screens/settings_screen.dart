import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/units/length_unit.dart';
import '../../domain/product/finish.dart';
import '../../domain/product/product_basics.dart';
import '../../domain/product/profile_system.dart';
import '../state/settings_controller.dart';
import '../widgets/dimension_input.dart';
import '../widgets/notice.dart';

/// Factory settings (spec section 9).
///
/// The technical answers a factory gives once, so a salesperson drawing a
/// window never has to. Everything here is a *starting point* for a new
/// design; nothing here changes a project that already exists.
class SettingsScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const SettingsScreen({required this.onBack, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(factorySettingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onBack,
        ),
        actions: [
          TextButton(
            onPressed: controller.restoreDefaults,
            child: const Text('Restore defaults'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const Notice(
              message: 'These are the starting points for a new design. '
                  'Designs already saved are not changed.',
            ),
            const SizedBox(height: AppSpacing.md),

            Text('Defaults for a new design', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _Choice<FrameMaterial>(
              label: 'Material',
              options: FrameMaterial.values,
              labelOf: (m) => m.label,
              selected: settings.defaultMaterial,
              onSelected: (m) =>
                  controller.save(settings.copyWith(defaultMaterial: m)),
            ),
            _Choice<Finish>(
              label: 'Colour',
              options: StockFinishes.all,
              labelOf: (f) => f.name,
              selected: settings.defaultFinish,
              onSelected: (f) =>
                  controller.save(settings.copyWith(defaultFinishId: f.id)),
            ),
            _Choice<LengthUnit>(
              label: 'Staff type and read',
              options: LengthUnit.values,
              labelOf: (u) => '${u.name} (${u.symbol})',
              selected: settings.displayUnit,
              onSelected: (u) =>
                  controller.save(settings.copyWith(displayUnit: u)),
            ),

            const SizedBox(height: AppSpacing.md),
            Text('How this factory measures', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _Choice<ViewingSide>(
              label: 'Drawings are read from',
              options: ViewingSide.values,
              labelOf: (v) => v.label,
              selected: settings.defaultViewingSide,
              onSelected: (v) =>
                  controller.save(settings.copyWith(defaultViewingSide: v)),
            ),
            _Choice<DimensionReference>(
              label: 'Sizes mean',
              options: DimensionReference.values,
              labelOf: (r) => r.label,
              selected: settings.defaultDimensionReference,
              onSelected: (r) => controller
                  .save(settings.copyWith(defaultDimensionReference: r)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fitting gap'),
              subtitle: Text(
                'Left each side when a size is a wall opening. '
                'Currently ${settings.fittingGapMm.round()} mm.',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final millimetres = await askForLengthMm(
                  context,
                  title: 'Fitting gap',
                  helper: 'The gap left on each side between the frame and the '
                      'wall opening. It is always shown in the design, never '
                      'applied invisibly.',
                  currentMm: settings.fittingGapMm,
                  unit: LengthUnit.millimetre,
                );
                if (millimetres == null) return;
                await controller
                    .save(settings.copyWith(fittingGapMm: millimetres));
              },
            ),

            const SizedBox(height: AppSpacing.md),
            Text('Profile systems', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            for (final profile in GenericProfiles.all)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Frame ${profile.frameFaceMm.round()} × '
                        '${profile.frameDepthMm.round()} mm · '
                        'sash ${profile.sashFaceMm.round()} mm · '
                        'divider ${profile.dividerFaceMm.round()} mm · '
                        'rebate ${profile.glazingRebateMm.round()} mm',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                      Text(
                        'Largest opening leaf '
                        '${profile.maxSashWidthMm.round()} × '
                        '${profile.maxSashHeightMm.round()} mm',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                      if (profile.isGeneric) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Notice(
                          tone: NoticeTone.caution,
                          title: 'Generic preview profile',
                          message: profile.assumptions,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const Notice(
              tone: NoticeTone.caution,
              title: 'Replacing these with real data',
              message: 'The profile systems above are built into this version. '
                  'They are read through one interface, so a supplier '
                  'catalogue can replace them without the rest of the app '
                  'changing — but that work has not been done, because no '
                  'catalogue has been supplied.',
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// A labelled row of choices.
class _Choice<T> extends StatelessWidget {
  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  const _Choice({
    required this.label,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in options)
                  ChoiceChip(
                    label: Text(labelOf(option)),
                    selected: option == selected,
                    onSelected: (_) => onSelected(option),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
