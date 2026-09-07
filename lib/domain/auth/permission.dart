/// Fine-grained capabilities checked both by the router (to hide/guard
/// routes) and inside widgets (to hide actions a role cannot perform).
/// Keeping these as an enum — rather than stringly-typed checks scattered
/// through the UI — is what lets [RolePermissions] stay the single place
/// that defines "what MANAGER can do".
enum Permission {
  viewDashboard,
  manageCustomers,
  manageProjects,
  useConfigurator,
  manageQuotations,
  approveQuotations,
  manageOrders,
  manageManufacturing,
  performQualityControl,
  manageInventory,
  manageProducts,
  managePricingRules,
  viewReports,
  manageUsers,
  manageSettings,
  viewAuditLog,
}

enum UserRole {
  admin('Administrator'),
  manager('Manager'),
  sales('Sales'),
  designer('Designer'),
  engineer('Engineer'),
  factory('Factory'),
  accountant('Accountant'),
  viewer('Viewer');

  final String label;
  const UserRole(this.label);
}

/// Central role → permission matrix (spec §5). Editable in one place; the
/// rest of the app never hard-codes "if role == admin".
class RolePermissions {
  RolePermissions._();

  static const Map<UserRole, Set<Permission>> _matrix = {
    UserRole.admin: {
      Permission.viewDashboard,
      Permission.manageCustomers,
      Permission.manageProjects,
      Permission.useConfigurator,
      Permission.manageQuotations,
      Permission.approveQuotations,
      Permission.manageOrders,
      Permission.manageManufacturing,
      Permission.performQualityControl,
      Permission.manageInventory,
      Permission.manageProducts,
      Permission.managePricingRules,
      Permission.viewReports,
      Permission.manageUsers,
      Permission.manageSettings,
      Permission.viewAuditLog,
    },
    UserRole.manager: {
      Permission.viewDashboard,
      Permission.manageCustomers,
      Permission.manageProjects,
      Permission.useConfigurator,
      Permission.manageQuotations,
      Permission.approveQuotations,
      Permission.manageOrders,
      Permission.manageProducts,
      Permission.managePricingRules,
      Permission.viewReports,
    },
    UserRole.sales: {
      Permission.viewDashboard,
      Permission.manageCustomers,
      Permission.manageProjects,
      Permission.useConfigurator,
      Permission.manageQuotations,
    },
    UserRole.designer: {
      Permission.viewDashboard,
      Permission.useConfigurator,
      Permission.manageProjects,
    },
    UserRole.engineer: {
      Permission.viewDashboard,
      Permission.useConfigurator,
      Permission.manageProducts,
    },
    UserRole.factory: {
      Permission.viewDashboard,
      Permission.manageManufacturing,
      Permission.performQualityControl,
      Permission.manageInventory,
    },
    UserRole.accountant: {
      Permission.viewDashboard,
      Permission.manageQuotations,
      Permission.managePricingRules,
      Permission.viewReports,
    },
    UserRole.viewer: {
      Permission.viewDashboard,
      Permission.viewReports,
    },
  };

  static Set<Permission> of(UserRole role) => _matrix[role] ?? const {};

  static bool can(UserRole role, Permission permission) => of(role).contains(permission);
}
