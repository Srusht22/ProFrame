import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/configuration/config_enums.dart';
import '../../../domain/configuration/product_configuration.dart';
import '../../../domain/entities/manufacturing_order.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/quotation.dart';
import '../../../shared/providers/auth_notifier.dart';
import '../../../shared/providers/configuration_notifier.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/manufacturing_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/providers/project_notifier.dart';
import '../../../shared/providers/quotation_notifier.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final customers = ref.watch(customerNotifierProvider).value ?? const [];
    final projects = ref.watch(projectNotifierProvider).value ?? const [];
    final quotations = ref.watch(quotationNotifierProvider).value ?? const [];
    final orders = ref.watch(orderNotifierProvider).value ?? const [];
    final manufacturingOrders = ref.watch(manufacturingNotifierProvider).value ?? const [];
    final configurations = ref.watch(configurationNotifierProvider).value ?? const [];

    final activeProjects = projects.where((p) =>
        p.status != ProjectStatus.completed && p.status != ProjectStatus.cancelled).length;
    final draftQuotes = quotations.where((q) => q.status == QuotationStatus.draft).length;
    final pendingQuotes =
        quotations.where((q) => q.status == QuotationStatus.sent || q.status == QuotationStatus.viewed).length;
    final approvedQuotes = quotations.where((q) => q.status == QuotationStatus.accepted).length;
    final activeOrders = orders
        .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
        .length;
    final inProduction = manufacturingOrders.where((m) => m.stage != ManufacturingStage.completed).length;

    final now = DateTime.now();
    final monthlySales = orders
        .where((o) => o.createdAt.year == now.year && o.createdAt.month == now.month)
        .fold(0.0, (sum, o) => sum + o.grandTotal);
    final todaySales = orders
        .where((o) =>
            o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day)
        .fold(0.0, (sum, o) => sum + o.grandTotal);

    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppSpacing.breakpointExpanded
        ? 4
        : width >= AppSpacing.breakpointMedium
            ? 3
            : width >= AppSpacing.breakpointCompact
                ? 2
                : 1;

    final stats = [
      _StatCardData('Total customers', customers.length.toString(), Icons.people_rounded, AppColors.info),
      _StatCardData('Active projects', activeProjects.toString(), Icons.folder_rounded, AppColors.brandDarkGreen),
      _StatCardData('Draft quotations', draftQuotes.toString(), Icons.edit_note_rounded, AppColors.textMuted),
      _StatCardData('Pending quotations', pendingQuotes.toString(), Icons.hourglass_top_rounded, AppColors.warning),
      _StatCardData('Approved quotations', approvedQuotes.toString(), Icons.check_circle_rounded, AppColors.success),
      _StatCardData('Active orders', activeOrders.toString(), Icons.local_shipping_rounded, AppColors.info),
      _StatCardData('In production', inProduction.toString(), Icons.precision_manufacturing_rounded, AppColors.warning),
      _StatCardData("Today's sales", '\$${todaySales.toStringAsFixed(0)}', Icons.today_rounded, AppColors.brandDarkGreen),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Welcome back, ${user?.fullName.split(' ').first ?? 'there'}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Here is what is happening across the factory today.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 2.1,
          children: [for (final s in stats) _StatCard(data: s)],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Monthly sales: \$${monthlySales.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppSpacing.breakpointMedium;
          final salesCard = AppCard(child: _SalesChart(orders: orders));
          final mixCard = AppCard(child: _ProductMixChart(configurations: configurations));
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: salesCard),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: mixCard),
              ],
            );
          }
          return Column(children: [salesCard, const SizedBox(height: AppSpacing.md), mixCard]);
        }),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppSpacing.breakpointMedium;
          final recentQuotes = AppCard(child: _RecentQuotations(quotations: quotations));
          final recentDesigns = AppCard(child: _RecentDesigns(configurations: configurations));
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: recentQuotes),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: recentDesigns),
              ],
            );
          }
          return Column(children: [recentQuotes, const SizedBox(height: AppSpacing.md), recentDesigns]);
        }),
      ],
    );
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCardData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: data.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.value, style: Theme.of(context).textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
                Text(
                  data.label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  final List<Order> orders;
  const _SalesChart({required this.orders});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));
    final totals = months.map((m) {
      return orders
          .where((o) => o.createdAt.year == m.year && o.createdAt.month == m.month)
          .fold(0.0, (sum, o) => sum + o.grandTotal);
    }).toList();
    final maxY = (totals.isEmpty ? 0.0 : totals.reduce((a, b) => a > b ? a : b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sales over time', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 100 : maxY * 1.25,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) return const SizedBox.shrink();
                      final m = months[index];
                      const labels = [
                        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[m.month - 1], style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < totals.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: totals[i],
                      color: AppColors.brandDarkGreen,
                      width: 22,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductMixChart extends StatelessWidget {
  final List<ProductConfiguration> configurations;
  const _ProductMixChart({required this.configurations});

  @override
  Widget build(BuildContext context) {
    final doors = configurations.where((c) => c.category == ProductCategory.door).length;
    final windows = configurations.where((c) => c.category == ProductCategory.window).length;
    final total = doors + windows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Door vs window mix', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (total == 0)
          const SizedBox(height: 160, child: Center(child: Text('No configurations yet')))
        else
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 32,
                      sections: [
                        PieChartSectionData(
                          value: doors.toDouble(),
                          color: AppColors.brandDarkGreen,
                          title: '',
                          radius: 26,
                        ),
                        PieChartSectionData(
                          value: windows.toDouble(),
                          color: AppColors.brandCreamDeep,
                          title: '',
                          radius: 26,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: AppColors.brandDarkGreen, label: 'Doors ($doors)'),
                    const SizedBox(height: 6),
                    _LegendDot(color: AppColors.brandCreamDeep, label: 'Windows ($windows)'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RecentQuotations extends StatelessWidget {
  final List<Quotation> quotations;
  const _RecentQuotations({required this.quotations});

  @override
  Widget build(BuildContext context) {
    final sorted = [...quotations]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recent = sorted.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recently updated quotations', style: Theme.of(context).textTheme.titleMedium),
            TextButton(onPressed: () => context.go(AppRoutes.quotations), child: const Text('View all')),
          ],
        ),
        if (recent.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Text('No quotations yet.'))
        else
          for (final q in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(q.quoteNumber),
              subtitle: Text('${q.items.length} item(s) · \$${q.grandTotal.toStringAsFixed(0)}'),
              trailing: StatusBadge(statusKey: q.status.name, label: q.status.label),
              onTap: () => context.go(AppRoutes.quotation(q.id)),
            ),
      ],
    );
  }
}

class _RecentDesigns extends StatelessWidget {
  final List<ProductConfiguration> configurations;
  const _RecentDesigns({required this.configurations});

  @override
  Widget build(BuildContext context) {
    final sorted = [...configurations]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recent = sorted.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recently created designs', style: Theme.of(context).textTheme.titleMedium),
        if (recent.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Text('No designs yet.'))
        else
          for (final c in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(c.category.icon, color: AppColors.brandDarkGreen),
              title: Text(c.name),
              subtitle: Text('${c.productTypeLabel} · ${c.formattedDimensions()}'),
              onTap: () => context.push(AppRoutes.configurator(c.id)),
            ),
      ],
    );
  }
}
