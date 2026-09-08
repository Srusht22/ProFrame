import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/auth/permission.dart';
import '../providers/auth_notifier.dart';
import '../providers/notification_notifier.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final Permission permission;

  const _NavItem(this.label, this.icon, this.selectedIcon, this.route, this.permission);
}

const _navItems = [
  _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded, AppRoutes.dashboard, Permission.viewDashboard),
  _NavItem('Customers', Icons.people_outline_rounded, Icons.people_rounded, AppRoutes.customers, Permission.manageCustomers),
  _NavItem('Projects', Icons.folder_outlined, Icons.folder_rounded, AppRoutes.projects, Permission.manageProjects),
  _NavItem('Quotations', Icons.request_quote_outlined, Icons.request_quote_rounded, AppRoutes.quotations, Permission.manageQuotations),
  _NavItem('Orders', Icons.local_shipping_outlined, Icons.local_shipping_rounded, AppRoutes.orders, Permission.manageOrders),
  _NavItem('Manufacturing', Icons.precision_manufacturing_outlined, Icons.precision_manufacturing_rounded, AppRoutes.manufacturing, Permission.manageManufacturing),
  _NavItem('Inventory', Icons.inventory_2_outlined, Icons.inventory_2_rounded, AppRoutes.inventory, Permission.manageInventory),
  _NavItem('Reports', Icons.insights_outlined, Icons.insights_rounded, AppRoutes.reports, Permission.viewReports),
  _NavItem('Settings', Icons.settings_outlined, Icons.settings_rounded, AppRoutes.settings, Permission.manageSettings),
];

/// Adaptive shell: a permanent labeled rail on desktop, a collapsed rail on
/// tablet, and a drawer + app bar on phones — one shell, three densities
/// (spec §42), not three separate UIs.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  List<_NavItem> _visibleItems(WidgetRef ref) {
    return _navItems.where((i) => ref.watch(hasPermissionProvider(i.permission))).toList();
  }

  int _selectedIndex(BuildContext context, List<_NavItem> items) {
    final location = GoRouterState.of(context).uri.toString();
    var bestIndex = 0;
    var bestLength = -1;
    for (var i = 0; i < items.length; i++) {
      final route = items[i].route;
      final matches = route == AppRoutes.dashboard ? location == '/' : location.startsWith(route);
      if (matches && route.length > bestLength) {
        bestIndex = i;
        bestLength = route.length;
      }
    }
    return bestIndex;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final items = _visibleItems(ref);
    final selectedIndex = _selectedIndex(context, items);
    final unread = ref.watch(unreadNotificationCountProvider);

    final topBar = _TopBar(unreadCount: unread);

    if (width < AppSpacing.breakpointCompact) {
      return Scaffold(
        appBar: AppBar(title: topBar, actions: const [_NotificationBellSpacer()]),
        drawer: _NavDrawer(items: items, selectedIndex: selectedIndex),
        body: SafeArea(child: child),
      );
    }

    final extended = width >= AppSpacing.breakpointMedium;
    return Scaffold(
      body: Row(
        children: [
          _SideRail(items: items, selectedIndex: selectedIndex, extended: extended),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  ),
                  child: Row(children: [Expanded(child: topBar), const _NotificationBell()]),
                ),
                Expanded(child: SafeArea(top: false, child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int unreadCount;
  const _TopBar({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final item = _navItems.firstWhere(
      (i) => location == i.route || (i.route != '/' && location.startsWith(i.route)),
      orElse: () => _navItems.first,
    );
    return Text(item.label, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _NotificationBellSpacer extends ConsumerWidget {
  const _NotificationBellSpacer();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const _NotificationBell();
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push(AppRoutes.notifications),
      icon: Badge(
        label: Text('$unread'),
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final bool extended;

  const _SideRail({required this.items, required this.selectedIndex, required this.extended});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandDarkGreen,
      width: extended ? 232 : 84,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          _Brand(extended: extended),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              extended: extended,
              minExtendedWidth: 232,
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => context.go(items[i].route),
              labelType: extended ? null : NavigationRailLabelType.none,
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          _UserFooter(extended: extended),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool extended;
  const _Brand({required this.extended});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: extended ? AppSpacing.lg : 0),
      child: Row(
        mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandCream,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(Icons.window_rounded, color: AppColors.brandDarkGreenDeep, size: 20),
          ),
          if (extended) ...[
            const SizedBox(width: AppSpacing.sm),
            const Flexible(
              child: Text(
                'ProFrame',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.brandCream, fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserFooter extends ConsumerWidget {
  final bool extended;
  const _UserFooter({required this.extended});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox(height: AppSpacing.md);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _showLogoutSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.brandCream,
                child: Text(user.initials,
                    style: const TextStyle(color: AppColors.brandDarkGreenDeep, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              if (extended) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(user.role.label,
                          style: const TextStyle(color: AppColors.textOnDarkMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
                const Icon(Icons.logout_rounded, color: AppColors.textOnDarkMuted, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showLogoutSheet(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Log out'),
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          ListTile(
            leading: const Icon(Icons.close_rounded),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  if (shouldLogout == true) {
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }
}

class _NavDrawer extends ConsumerWidget {
  final List<_NavItem> items;
  final int selectedIndex;

  const _NavDrawer({required this.items, required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.brandDarkGreen,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _Brand(extended: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < items.length; i++)
                    ListTile(
                      leading: Icon(
                        i == selectedIndex ? items[i].selectedIcon : items[i].icon,
                        color: i == selectedIndex ? AppColors.brandCream : AppColors.textOnDarkMuted,
                      ),
                      title: Text(
                        items[i].label,
                        style: TextStyle(
                          color: i == selectedIndex ? AppColors.brandCream : Colors.white,
                          fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: i == selectedIndex,
                      selectedTileColor: Colors.white.withValues(alpha: 0.08),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(items[i].route);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const _UserFooter(extended: true),
          ],
        ),
      ),
    );
  }
}
