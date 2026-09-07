import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/pricing/currency.dart';
import '../../../../shared/providers/settings_notifier.dart';
import '../../../../shared/widgets/async_value_view.dart';

class PreferencesTab extends ConsumerWidget {
  const PreferencesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    return AsyncValueView(
      value: settingsAsync,
      onRetry: () => ref.invalidate(settingsNotifierProvider),
      builder: (settings) {
        final notifier = ref.read(settingsNotifierProvider.notifier);
        return ListView(
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: AppThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                ButtonSegment(value: AppThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.update((c) => c.copyWith(themeMode: s.first)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Language', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<AppLocale>(
              segments: [for (final l in AppLocale.values) ButtonSegment(value: l, label: Text(l.label))],
              selected: {settings.locale},
              onSelectionChanged: (s) => notifier.update((c) => c.copyWith(locale: s.first)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Currency', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: settings.currency.code,
              items: [
                for (final c in AppCurrency.builtIns) DropdownMenuItem(value: c.code, child: Text('${c.label} (${c.code})')),
              ],
              onChanged: (code) {
                final currency = AppCurrency.builtIns.firstWhere((c) => c.code == code, orElse: () => AppCurrency.usd);
                notifier.update((c) => c.copyWith(currency: currency, pricingRules: c.pricingRules.copyWith(currency: currency)));
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Document numbering', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: settings.quoteNumberPrefix,
                  decoration: const InputDecoration(labelText: 'Quote prefix'),
                  onChanged: (v) => notifier.update((c) => c.copyWith(quoteNumberPrefix: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  initialValue: settings.orderNumberPrefix,
                  decoration: const InputDecoration(labelText: 'Order prefix'),
                  onChanged: (v) => notifier.update((c) => c.copyWith(orderNumberPrefix: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  initialValue: settings.projectNumberPrefix,
                  decoration: const InputDecoration(labelText: 'Project prefix'),
                  onChanged: (v) => notifier.update((c) => c.copyWith(projectNumberPrefix: v)),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: 220,
              child: TextFormField(
                initialValue: settings.quoteValidityDays.toString(),
                decoration: const InputDecoration(labelText: 'Quote validity (days)'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) notifier.update((c) => c.copyWith(quoteValidityDays: parsed));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
