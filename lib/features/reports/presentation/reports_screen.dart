import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/quotation.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/providers/quotation_notifier.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotations = ref.watch(quotationNotifierProvider).value ?? const <Quotation>[];
    final orders = ref.watch(orderNotifierProvider).value ?? const <Order>[];
    final customers = ref.watch(customerNotifierProvider).value ?? const <Customer>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SectionHeader(title: 'Reports', subtitle: 'Sales, quotations, orders and customer performance.'),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= AppSpacing.breakpointMedium;
          final revenue = AppCard(child: _RevenueChart(orders: orders));
          final funnel = AppCard(child: _QuotationFunnel(quotations: quotations));
          if (wide) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: revenue),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 2, child: funnel),
            ]);
          }
          return Column(children: [revenue, const SizedBox(height: AppSpacing.md), funnel]);
        }),
        const SizedBox(height: AppSpacing.md),
        AppCard(child: _TopCustomers(orders: orders, customers: customers)),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<Order> orders;
  const _RevenueChart({required this.orders});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(12, (i) => DateTime(now.year, now.month - (11 - i)));
    final totals = months
        .map((m) => orders.where((o) => o.createdAt.year == m.year && o.createdAt.month == m.month).fold(0.0, (s, o) => s + o.grandTotal))
        .toList();
    final spots = [for (var i = 0; i < totals.length; i++) FlSpot(i.toDouble(), totals[i])];
    final maxY = totals.isEmpty ? 100.0 : (totals.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly revenue (last 12 months)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY.toDouble(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.brandDarkGreen,
                  barWidth: 2.6,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.brandCream.withValues(alpha: 0.35)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuotationFunnel extends StatelessWidget {
  final List<Quotation> quotations;
  const _QuotationFunnel({required this.quotations});

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final status in QuotationStatus.values) status: quotations.where((q) => q.status == status).length,
    };
    final total = quotations.isEmpty ? 1 : quotations.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quotation funnel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (final entry in counts.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key.label, style: Theme.of(context).textTheme.bodySmall),
                    Text('${entry.value}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: entry.value / total, minHeight: 5, color: AppColors.brandDarkGreen),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopCustomers extends StatelessWidget {
  final List<Order> orders;
  final List<Customer> customers;
  const _TopCustomers({required this.orders, required this.customers});

  @override
  Widget build(BuildContext context) {
    final byCustomer = groupBy(orders, (Order o) => o.customerId);
    final rows = byCustomer.entries.map((e) {
      final customer = customers.firstWhereOrNull((c) => c.id == e.key);
      final total = e.value.fold(0.0, (s, o) => s + o.grandTotal);
      return (customer?.fullName ?? 'Unknown', total, e.value.length);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top customers by revenue', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Text('No orders yet.'))
        else
          for (final row in rows.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row.$1),
              subtitle: Text('${row.$3} order(s)'),
              trailing: Text('\$${row.$2.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleSmall),
            ),
      ],
    );
  }
}
