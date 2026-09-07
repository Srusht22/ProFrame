import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/audit_log/presentation/audit_log_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/configurator/presentation/configurator_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/manufacturing/presentation/manufacturing_detail_screen.dart';
import '../../features/manufacturing/presentation/manufacturing_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/projects/presentation/project_detail_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/quotations/presentation/quotation_detail_screen.dart';
import '../../features/quotations/presentation/quotations_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/providers/auth_notifier.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final isLoggedIn = ref.read(authNotifierProvider).valueOrNull != null;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      if (!isLoggedIn && !isLoggingIn) return AppRoutes.login;
      if (isLoggedIn && isLoggingIn) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (context, state) => const DashboardScreen()),
          GoRoute(path: AppRoutes.customers, builder: (context, state) => const CustomersScreen()),
          GoRoute(
            path: AppRoutes.customerDetail,
            builder: (context, state) => CustomerDetailScreen(customerId: state.pathParameters['id']!),
          ),
          GoRoute(path: AppRoutes.projects, builder: (context, state) => const ProjectsScreen()),
          GoRoute(
            path: AppRoutes.projectDetail,
            builder: (context, state) => ProjectDetailScreen(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: AppRoutes.quotations, builder: (context, state) => const QuotationsScreen()),
          GoRoute(
            path: AppRoutes.quotationDetail,
            builder: (context, state) => QuotationDetailScreen(quotationId: state.pathParameters['id']!),
          ),
          GoRoute(path: AppRoutes.orders, builder: (context, state) => const OrdersScreen()),
          GoRoute(
            path: AppRoutes.orderDetail,
            builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
          GoRoute(path: AppRoutes.manufacturing, builder: (context, state) => const ManufacturingScreen()),
          GoRoute(
            path: AppRoutes.manufacturingDetail,
            builder: (context, state) =>
                ManufacturingDetailScreen(manufacturingOrderId: state.pathParameters['id']!),
          ),
          GoRoute(path: AppRoutes.inventory, builder: (context, state) => const InventoryScreen()),
          GoRoute(path: AppRoutes.reports, builder: (context, state) => const ReportsScreen()),
          GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
          GoRoute(path: AppRoutes.notifications, builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: AppRoutes.auditLog, builder: (context, state) => const AuditLogScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.configuratorNew,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ConfiguratorScreen(
          configurationId: null,
          projectId: state.uri.queryParameters['projectId'],
          categoryParam: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: AppRoutes.configuratorEdit,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ConfiguratorScreen(configurationId: state.pathParameters['id']),
      ),
    ],
  );
});

/// Bridges Riverpod's `authNotifierProvider` into a `Listenable` so
/// `GoRouter` re-evaluates `redirect` immediately on login/logout instead
/// of waiting for the next navigation event.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}
