import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/manufacturing_order.dart';
import '../../../shared/providers/manufacturing_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';

class ManufacturingDetailScreen extends ConsumerWidget {
  final String manufacturingOrderId;
  const ManufacturingDetailScreen({super.key, required this.manufacturingOrderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(manufacturingNotifierProvider).valueOrNull ?? const <ManufacturingOrder>[];
    final mo = list.firstWhereOrNull((m) => m.id == manufacturingOrderId);
    if (mo == null) {
      return const Scaffold(body: EmptyState(icon: Icons.precision_manufacturing_outlined, title: 'Not found', message: ''));
    }
    final order = (ref.watch(orderNotifierProvider).valueOrNull ?? const []).firstWhereOrNull((o) => o.id == mo.orderId);
    final nextStage = mo.stage.next;

    return Scaffold(
      appBar: AppBar(title: Text(mo.moNumber)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order != null) Text(order.orderNumber, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text('Current stage: ${mo.stage.label}'),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: mo.stage.progressFraction, minHeight: 6, color: AppColors.brandDarkGreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final stage in ManufacturingStage.values)
                Chip(
                  label: Text(stage.label),
                  backgroundColor: stage.index <= mo.stage.index ? AppColors.brandDarkGreen.withOpacity(0.12) : null,
                  labelStyle: TextStyle(
                    color: stage.index <= mo.stage.index ? AppColors.brandDarkGreen : null,
                    fontWeight: stage == mo.stage ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (mo.stage == ManufacturingStage.qualityControl) ...[
            Text('Quality control checklist', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final check in mo.qcChecklist)
              Card(
                child: ListTile(
                  title: Text(check.label),
                  trailing: SegmentedButton<QcResult>(
                    segments: const [
                      ButtonSegment(value: QcResult.pass, label: Text('Pass'), icon: Icon(Icons.check_rounded, size: 16)),
                      ButtonSegment(value: QcResult.fail, label: Text('Fail'), icon: Icon(Icons.close_rounded, size: 16)),
                      ButtonSegment(value: QcResult.notApplicable, label: Text('N/A')),
                    ],
                    selected: {check.result == QcResult.pending ? QcResult.notApplicable : check.result},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => ref
                        .read(manufacturingNotifierProvider.notifier)
                        .updateQcResult(mo, check.id, selection.first),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (!mo.qcPassed)
              Text(
                mo.qcHasFailure ? 'One or more checks failed — resolve before proceeding.' : 'Complete every check to proceed.',
                style: const TextStyle(color: AppColors.warning),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (nextStage != null)
            FilledButton.icon(
              onPressed: (mo.stage == ManufacturingStage.qualityControl && !mo.qcPassed)
                  ? null
                  : () => ref.read(manufacturingNotifierProvider.notifier).advanceStage(mo),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text('Advance to ${nextStage.label}'),
            )
          else
            const Text('Production complete.'),
        ],
      ),
    );
  }
}
