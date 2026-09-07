import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../../../../../domain/manufacturing/bom_line.dart';
import '../../../../../domain/manufacturing/cutting_list_line.dart';
import '../../../../../domain/pricing/price_breakdown.dart';
import '../../../../../domain/services/validation_engine.dart';
import '../../../../../shared/widgets/price_breakdown_view.dart';
import '../step_scaffold.dart';

class SummaryStep extends StatelessWidget {
  final ProductConfiguration config;
  final ValidationResult validation;
  final PriceBreakdown breakdown;
  final List<BomLine> bom;
  final List<CuttingListLine> cuttingList;

  const SummaryStep({
    super.key,
    required this.config,
    required this.validation,
    required this.breakdown,
    required this.bom,
    required this.cuttingList,
  });

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      title: 'Summary & price',
      helperText: 'Full configuration, transparent pricing and manufacturing paperwork — generated from one source of truth.',
      children: [
        if (validation.errors.isNotEmpty)
          _IssueBanner(
            color: AppColors.error,
            icon: Icons.error_outline_rounded,
            title: 'Fix before saving',
            issues: validation.errors,
          ),
        if (validation.warnings.isNotEmpty)
          _IssueBanner(
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
            title: 'Worth checking',
            issues: validation.warnings,
          ),
        FieldGroup(
          label: 'Configuration',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _SummaryChip('${config.productTypeLabel}'),
              _SummaryChip(config.formattedDimensions()),
              _SummaryChip('Qty ${config.quantity}'),
              _SummaryChip(config.frame.material.label),
              _SummaryChip(config.finish.frameColor.label),
              if (config.panel.type.name == 'glass') _SummaryChip(config.glass.type.label),
            ],
          ),
        ),
        FieldGroup(label: 'Price breakdown', child: PriceBreakdownView(breakdown: breakdown)),
        FieldGroup(
          label: 'Bill of materials',
          child: _BomTable(bom: bom),
        ),
        FieldGroup(
          label: 'Cutting list',
          child: _CuttingListTable(cuttingList: cuttingList),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  const _SummaryChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _IssueBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<ValidationIssue> issues;

  const _IssueBanner({required this.color, required this.icon, required this.title, required this.issues});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('• ${issue.message}', style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _BomTable extends StatelessWidget {
  final List<BomLine> bom;
  const _BomTable({required this.bom});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Part #')),
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Qty'), numeric: true),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Unit price'), numeric: true),
          DataColumn(label: Text('Total'), numeric: true),
        ],
        rows: [
          for (final line in bom)
            DataRow(cells: [
              DataCell(Text(line.partNumber)),
              DataCell(Text(line.description)),
              DataCell(Text(line.quantity.toStringAsFixed(2))),
              DataCell(Text(line.unit)),
              DataCell(Text('\$${line.unitPrice.toStringAsFixed(2)}')),
              DataCell(Text('\$${line.totalPrice.toStringAsFixed(2)}')),
            ]),
        ],
      ),
    );
  }
}

class _CuttingListTable extends StatelessWidget {
  final List<CuttingListLine> cuttingList;
  const _CuttingListTable({required this.cuttingList});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Component')),
          DataColumn(label: Text('Length (mm)'), numeric: true),
          DataColumn(label: Text('Qty'), numeric: true),
          DataColumn(label: Text('Material')),
        ],
        rows: [
          for (final line in cuttingList)
            DataRow(cells: [
              DataCell(Text(line.component)),
              DataCell(Text(line.lengthMm.toStringAsFixed(0))),
              DataCell(Text('${line.quantity}')),
              DataCell(Text(line.material)),
            ]),
        ],
      ),
    );
  }
}
