/// Central route path constants — screens and nav widgets both reference
/// these instead of hand-typing path strings.
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const dashboard = '/';
  static const customers = '/customers';
  static const customerDetail = '/customers/:id';
  static const projects = '/projects';
  static const projectDetail = '/projects/:id';
  static const configuratorNew = '/configurator/new';
  static const configuratorEdit = '/configurator/:id';
  static const quotations = '/quotations';
  static const quotationDetail = '/quotations/:id';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const manufacturing = '/manufacturing';
  static const manufacturingDetail = '/manufacturing/:id';
  static const inventory = '/inventory';
  static const reports = '/reports';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const auditLog = '/audit-log';
  static const users = '/users';

  static String customer(String id) => '/customers/$id';
  static String project(String id) => '/projects/$id';
  static String configurator(String id) => '/configurator/$id';
  static String quotation(String id) => '/quotations/$id';
  static String order(String id) => '/orders/$id';
  static String manufacturingOrder(String id) => '/manufacturing/$id';
}
