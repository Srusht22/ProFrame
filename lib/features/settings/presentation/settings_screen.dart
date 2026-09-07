import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/auth/permission.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../../shared/widgets/section_header.dart';
import 'widgets/company_profile_tab.dart';
import 'widgets/pricing_rules_tab.dart';
import 'widgets/preferences_tab.dart';
import 'widgets/users_tab.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.manageSettings,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Settings',
              subtitle: 'Company profile, pricing rules, users and preferences.',
              trailing: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.auditLog),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Audit log'),
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Company'),
                Tab(text: 'Pricing rules'),
                Tab(text: 'Users & roles'),
                Tab(text: 'Preferences'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  CompanyProfileTab(),
                  PricingRulesTab(),
                  UsersTab(),
                  PreferencesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
