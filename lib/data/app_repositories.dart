import '../domain/repositories/audit_log_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/configuration_repository.dart';
import '../domain/repositories/customer_repository.dart';
import '../domain/repositories/inventory_repository.dart';
import '../domain/repositories/manufacturing_repository.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/repositories/quotation_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/user_repository.dart';
import 'demo/demo_data_seeder.dart';
import 'local/key_value_store.dart';
import 'repositories/local_audit_log_repository.dart';
import 'repositories/local_auth_repository.dart';
import 'repositories/local_configuration_repository.dart';
import 'repositories/local_customer_repository.dart';
import 'repositories/local_inventory_repository.dart';
import 'repositories/local_manufacturing_repository.dart';
import 'repositories/local_notification_repository.dart';
import 'repositories/local_order_repository.dart';
import 'repositories/local_project_repository.dart';
import 'repositories/local_quotation_repository.dart';
import 'repositories/local_settings_repository.dart';
import 'repositories/local_user_repository.dart';

/// Composition root: the one place concrete (local) repository
/// implementations are wired to their domain interfaces. Every feature
/// depends on the interfaces in `domain/repositories`, never on this class
/// or the `Local*Repository` types directly — swapping to a REST backend
/// means replacing the bodies of the `Local*Repository` classes (or adding
/// `Remote*Repository` alternatives and changing only this file).
class AppRepositories {
  final CustomerRepository customers;
  final ProjectRepository projects;
  final ConfigurationRepository configurations;
  final QuotationRepository quotations;
  final OrderRepository orders;
  final ManufacturingRepository manufacturing;
  final InventoryRepository inventory;
  final AuditLogRepository auditLog;
  final NotificationRepository notifications;
  final SettingsRepository settings;
  final UserRepository users;
  final AuthRepository auth;

  AppRepositories._({
    required this.customers,
    required this.projects,
    required this.configurations,
    required this.quotations,
    required this.orders,
    required this.manufacturing,
    required this.inventory,
    required this.auditLog,
    required this.notifications,
    required this.settings,
    required this.users,
    required this.auth,
  });

  factory AppRepositories.local(IKeyValueStore keyValueStore) {
    final users = LocalUserRepository(keyValueStore);
    return AppRepositories._(
      customers: LocalCustomerRepository(keyValueStore),
      projects: LocalProjectRepository(keyValueStore),
      configurations: LocalConfigurationRepository(keyValueStore),
      quotations: LocalQuotationRepository(keyValueStore),
      orders: LocalOrderRepository(keyValueStore),
      manufacturing: LocalManufacturingRepository(keyValueStore),
      inventory: LocalInventoryRepository(keyValueStore),
      auditLog: LocalAuditLogRepository(keyValueStore),
      notifications: LocalNotificationRepository(keyValueStore),
      settings: LocalSettingsRepository(keyValueStore),
      users: users,
      auth: LocalAuthRepository(
        userRepository: users,
        keyValueStore: keyValueStore,
        demoCredentials: DemoDataSeeder.demoCredentials,
      ),
    );
  }

  Future<void> seedDemoDataIfNeeded() => DemoDataSeeder(this).seedIfNeeded();
}
