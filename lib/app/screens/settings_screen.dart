import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/design/tokens.dart';
import '../../core/i18n/app_language.dart';
import '../../core/i18n/numerals.dart';
import '../../core/i18n/product_labels.dart';
import '../../core/i18n/strings.dart';
import '../../core/units/length_unit.dart';
import '../../domain/product/finish.dart';
import '../../domain/product/product_basics.dart';
import '../../domain/product/profile_system.dart';
import '../state/preferences_controller.dart';
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
    final preferences = ref.watch(appPreferencesProvider);
    final preferencesController =
        ref.read(preferencesControllerProvider.notifier);
    final theme = Theme.of(context);
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s(T.factorySettings)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: s(T.back),
          onPressed: onBack,
        ),
        actions: [
          TextButton(
            onPressed: controller.restoreDefaults,
            child: Text(s(T.restoreDefaults)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Notice(message: s(T.settingsNotice)),
            const SizedBox(height: AppSpacing.md),

            Text(s(T.defaultsForNewDesign), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _Choice<FrameMaterial>(
              label: s(T.material),
              options: FrameMaterial.values,
              labelOf: s.frameMaterial,
              selected: settings.defaultMaterial,
              onSelected: (m) =>
                  controller.save(settings.copyWith(defaultMaterial: m)),
            ),
            _Choice<Finish>(
              label: s(T.colour),
              options: StockFinishes.all,
              labelOf: s.finishName,
              selected: settings.defaultFinish,
              onSelected: (f) =>
                  controller.save(settings.copyWith(defaultFinishId: f.id)),
            ),
            _Choice<LengthUnit>(
              label: s(T.staffTypeAndRead),
              options: LengthUnit.values,
              labelOf: (u) => '${s.unitName(u)} (${s.unitSymbol(u)})',
              selected: settings.displayUnit,
              onSelected: (u) =>
                  controller.save(settings.copyWith(displayUnit: u)),
            ),

            const SizedBox(height: AppSpacing.md),
            Text(
              s(T.howThisFactoryMeasures),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            _Choice<ViewingSide>(
              label: s(T.drawingsReadFrom),
              options: ViewingSide.values,
              labelOf: s.viewingSide,
              selected: settings.defaultViewingSide,
              onSelected: (v) =>
                  controller.save(settings.copyWith(defaultViewingSide: v)),
            ),
            _Choice<DimensionReference>(
              label: s(T.sizesMean),
              options: DimensionReference.values,
              labelOf: s.dimensionReference,
              selected: settings.defaultDimensionReference,
              onSelected: (r) => controller
                  .save(settings.copyWith(defaultDimensionReference: r)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s(T.fittingGap)),
              subtitle: Text(
                s(T.fittingGapNow, {
                  'gap': s.length(settings.fittingGapMm, LengthUnit.millimetre),
                }),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final millimetres = await askForLengthMm(
                  context,
                  title: s(T.fittingGap),
                  helper: s(T.fittingGapHelp),
                  currentMm: settings.fittingGapMm,
                  unit: LengthUnit.millimetre,
                );
                if (millimetres == null) return;
                await controller
                    .save(settings.copyWith(fittingGapMm: millimetres));
              },
            ),

            const SizedBox(height: AppSpacing.md),
            Text(s(T.profileSystems), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            for (final profile in GenericProfiles.all)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.profileName(profile),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        s(T.profileSizes, {
                          'face': s.number(profile.frameFaceMm),
                          'depth': s.number(profile.frameDepthMm),
                          'sash': s.number(profile.sashFaceMm),
                          'divider': s.number(profile.dividerFaceMm),
                          'rebate': s.number(profile.glazingRebateMm),
                        }),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                      Text(
                        s(T.largestLeaf, {
                          'width': s.number(profile.maxSashWidthMm),
                          'height': s.number(profile.maxSashHeightMm),
                        }),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                      if (profile.isGeneric) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Notice(
                          tone: NoticeTone.caution,
                          title: s(T.genericPreviewProfile),
                          message: s.profileAssumptions(profile),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            Notice(
              tone: NoticeTone.caution,
              title: s(T.replacingWithRealData),
              message: s(T.replacingWithRealDataHelp),
            ),

            const SizedBox(height: AppSpacing.md),
            Text(s(T.appLanguageSection), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            // Each language names itself in its own script, so it can be found
            // by someone who does not read the current one.
            _Choice<AppLanguage>(
              label: s(T.language),
              options: AppLanguage.values,
              labelOf: (l) => l.nativeName,
              selected: preferences.language,
              onSelected: preferencesController.setLanguage,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                s(T.languageHelp),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedText),
              ),
            ),
            _Choice<NumeralSystem>(
              label: s(T.numerals),
              options: NumeralSystem.values,
              labelOf: (n) => s(switch (n) {
                NumeralSystem.western => T.numeralsWestern,
                NumeralSystem.arabicIndic => T.numeralsArabicIndic,
              }),
              selected: preferences.numerals,
              onSelected: preferencesController.setNumerals,
            ),
            Text(
              s(T.numeralsHelp),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedText),
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
