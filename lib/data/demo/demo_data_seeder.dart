import '../../domain/auth/app_user.dart';
import '../../domain/auth/permission.dart';
import '../../domain/configuration/config_enums.dart';
import '../../domain/configuration/configuration_value_objects.dart';
import '../../domain/configuration/product_configuration.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/manufacturing_order.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/quotation.dart';
import '../app_repositories.dart';

/// Demo/sample data — clearly fictional company & customer names, seeded
/// once so a fresh install shows a populated, realistic-looking factory
/// rather than an empty shell. Real production data is written by the
/// same repositories once the seed has run, and is never mixed with or
/// reset by this seeder after the first run (each collection tracks its
/// own `__seeded` flag).
///
/// Demo sign-in accounts (password for all: `Demo@123`):
///   admin@proframe.demo · manager@proframe.demo · sales@proframe.demo
///   designer@proframe.demo · engineer@proframe.demo · factory@proframe.demo
///   accountant@proframe.demo · viewer@proframe.demo
class DemoDataSeeder {
  final AppRepositories repos;
  const DemoDataSeeder(this.repos);

  static const demoPassword = 'Demo@123';

  static final Map<String, String> demoCredentials = {
    for (final role in UserRole.values) '${role.name}@proframe.demo': demoPassword,
  };

  Future<void> seedIfNeeded() async {
    await _seedUsers();
    await _seedCustomersAndProjects();
    await _seedInventory();
    await _seedNotifications();
  }

  Future<void> _seedUsers() async {
    final existing = await repos.users.getAll();
    if (existing.isNotEmpty) return;
    final names = {
      UserRole.admin: 'Amina Kareem',
      UserRole.manager: 'Yusuf Rahman',
      UserRole.sales: 'Layla Hassan',
      UserRole.designer: 'Noor Aziz',
      UserRole.engineer: 'Rawand Saleh',
      UserRole.factory: 'Karwan Omar',
      UserRole.accountant: 'Diana Sabir',
      UserRole.viewer: 'Guest Viewer',
    };
    for (final role in UserRole.values) {
      await repos.users.save(AppUser(
        id: 'user_${role.name}',
        fullName: names[role]!,
        email: '${role.name}@proframe.demo',
        role: role,
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
      ));
    }
  }

  Future<void> _seedCustomersAndProjects() async {
    final existingCustomers = await repos.customers.getAll();
    if (existingCustomers.isNotEmpty) return;

    final customers = [
      Customer(
        id: 'cust_1',
        fullName: 'Ahmed Al-Bayati',
        company: 'Bayati Residential Group',
        phone: '+964 750 111 2233',
        email: 'ahmed.bayati@example.com',
        address: '14 Palm Street',
        city: 'Erbil',
        country: 'Iraq',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        updatedAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
      Customer(
        id: 'cust_2',
        fullName: 'Sara Mahmoud',
        company: 'Skyline Interiors',
        phone: '+964 773 444 5566',
        email: 'sara.mahmoud@example.com',
        address: '88 Garden Avenue',
        city: 'Sulaymaniyah',
        country: 'Iraq',
        createdAt: DateTime.now().subtract(const Duration(days: 95)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Customer(
        id: 'cust_3',
        fullName: 'Omar Faris',
        company: null,
        phone: '+964 770 222 8899',
        email: 'omar.faris@example.com',
        address: '3 Riverside Road',
        city: 'Baghdad',
        country: 'Iraq',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      Customer(
        id: 'cust_4',
        fullName: 'Diyar Construction Co.',
        company: 'Diyar Construction Co.',
        phone: '+964 751 909 7070',
        email: 'projects@diyarconstruction.example',
        address: 'Industrial Zone, Block 12',
        city: 'Duhok',
        country: 'Iraq',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
    for (final c in customers) {
      await repos.customers.save(c);
    }

    final projectNumbers = [
      await repos.projects.nextProjectNumber(),
      await repos.projects.nextProjectNumber(),
      await repos.projects.nextProjectNumber(),
    ];

    final projects = [
      Project(
        id: 'proj_1',
        projectNumber: projectNumbers[0],
        name: 'Bayati Villa — Windows Package',
        customerId: 'cust_1',
        location: 'Erbil, 60m Road',
        type: ProjectType.residential,
        status: ProjectStatus.manufacturing,
        description: 'Full window replacement for a 3-floor villa.',
        startDate: DateTime.now().subtract(const Duration(days: 45)),
        expectedCompletionDate: DateTime.now().add(const Duration(days: 15)),
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Project(
        id: 'proj_2',
        projectNumber: projectNumbers[1],
        name: 'Skyline Office Fit-Out',
        customerId: 'cust_2',
        location: 'Sulaymaniyah Business Tower, Floor 6',
        type: ProjectType.commercial,
        status: ProjectStatus.quotation,
        description: 'Glass partitions and entrance doors for a new office floor.',
        startDate: DateTime.now().subtract(const Duration(days: 12)),
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Project(
        id: 'proj_3',
        projectNumber: projectNumbers[2],
        name: 'Faris Apartment — Entrance Door',
        customerId: 'cust_3',
        location: 'Baghdad, Al Mansour',
        type: ProjectType.renovation,
        status: ProjectStatus.design,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
    for (final p in projects) {
      await repos.projects.save(p);
    }

    final now = DateTime.now();
    final config1 = ProductConfiguration(
      id: 'cfg_1',
      projectId: 'proj_1',
      name: 'Living Room Sliding Window',
      category: ProductCategory.window,
      windowType: WindowType.sliding,
      widthMm: 2400,
      heightMm: 1500,
      wallOpeningWidthMm: 2420,
      wallOpeningHeightMm: 1520,
      quantity: 4,
      frame: const FrameSpec(frameDepthMm: 60, frameThicknessMm: 50),
      leaf: const LeafSpec(arrangement: LeafArrangement.custom, openingDirection: OpeningDirection.slideLeft),
      panel: const PanelSpec(type: PanelType.glass),
      glass: const GlassSpec(type: GlassType.doubleGlazed, thicknessMm: 24, panesCount: 2),
      hardware: const HardwareSpec(hingeCount: 0, handleModel: HandleModel.flushLatch, lockType: LockType.none),
      finish: const FinishSpec(frameColor: FrameColor.anthracite),
      sections: 3,
      state: ProductConfigState.productionReady,
      createdAt: now.subtract(const Duration(days: 44)),
      updatedAt: now.subtract(const Duration(days: 20)),
    );
    final config2 = ProductConfiguration(
      id: 'cfg_2',
      projectId: 'proj_2',
      name: 'Office Entrance Door',
      category: ProductCategory.door,
      doorType: DoorType.entrance,
      widthMm: 1200,
      heightMm: 2300,
      wallOpeningWidthMm: 1230,
      wallOpeningHeightMm: 2330,
      quantity: 1,
      frame: const FrameSpec(hasDoorJamb: true, hasThreshold: true, frameDepthMm: 90),
      leaf: const LeafSpec(arrangement: LeafArrangement.unequalDouble, leafCount: 2, primaryLeafRatio: 0.65),
      panel: const PanelSpec(type: PanelType.glass),
      glass: const GlassSpec(type: GlassType.laminated, thicknessMm: 8.8),
      hardware: const HardwareSpec(
        hingeCount: 3,
        handleModel: HandleModel.premiumLever,
        lockType: LockType.multiPointLock,
        doorCloser: DoorCloserType.concealed,
      ),
      finish: const FinishSpec(frameColor: FrameColor.black),
      sections: 1,
      state: ProductConfigState.quoted,
      createdAt: now.subtract(const Duration(days: 11)),
      updatedAt: now.subtract(const Duration(days: 3)),
    );
    final config3 = ProductConfiguration.newDraft(
      name: 'Apartment Entrance Door — Draft',
      category: ProductCategory.door,
      projectId: 'proj_3',
    );
    for (final c in [config1, config2, config3]) {
      await repos.configurations.save(c);
    }

    final quoteNumber = await repos.quotations.nextQuoteNumber();
    final quotation = Quotation(
      id: 'quote_1',
      quoteNumber: quoteNumber,
      projectId: 'proj_2',
      customerId: 'cust_2',
      status: QuotationStatus.sent,
      issueDate: now.subtract(const Duration(days: 3)),
      expiryDate: now.add(const Duration(days: 27)),
      taxPercent: 5,
      installationCostPerUnit: 40,
      deliveryCost: 100,
      termsAndConditions:
          '1. Prices valid until the expiry date shown above.\n2. 50% deposit required to confirm production.',
      createdByUserId: 'user_sales',
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 3)),
      items: [
        QuoteItem(
          id: 'item_1',
          configurationId: config2.id,
          configurationName: config2.name,
          productTypeLabel: config2.productTypeLabel,
          dimensionsLabel: config2.formattedDimensions(),
          quantity: 1,
          unitPrice: 1180,
        ),
      ],
    );
    await repos.quotations.save(quotation);

    final orderNumber = await repos.orders.nextOrderNumber();
    final order = Order.fromQuotation(
      id: 'order_1',
      orderNumber: orderNumber,
      quotation: Quotation(
        id: 'quote_0',
        quoteNumber: 'Q-SEED',
        projectId: 'proj_1',
        customerId: 'cust_1',
        status: QuotationStatus.accepted,
        issueDate: now.subtract(const Duration(days: 40)),
        expiryDate: now.subtract(const Duration(days: 10)),
        installationCostPerUnit: 40,
        deliveryCost: 80,
        createdByUserId: 'user_sales',
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 38)),
        items: [
          QuoteItem(
            id: 'item_0',
            configurationId: config1.id,
            configurationName: config1.name,
            productTypeLabel: config1.productTypeLabel,
            dimensionsLabel: config1.formattedDimensions(),
            quantity: 4,
            unitPrice: 410,
          ),
        ],
      ),
      createdByUserId: 'user_manager',
    ).copyWith(status: OrderStatus.inProduction);
    await repos.orders.save(order);

    await repos.manufacturing.save(ManufacturingOrder(
      id: 'mo_1',
      moNumber: 'MO-${orderNumber.split('-').skip(1).join('-')}',
      orderId: order.id,
      projectId: 'proj_1',
      stage: ManufacturingStage.hardwareInstallation,
      qcChecklist: QcCheckItem.standardChecklist(),
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now.subtract(const Duration(hours: 6)),
    ));
  }

  Future<void> _seedInventory() async {
    final existing = await repos.inventory.getAll();
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    final items = [
      InventoryItem(
        id: 'inv_1',
        sku: 'FRM-ALUMINUM',
        name: 'Aluminum profile — Standard 55',
        category: InventoryCategory.profile,
        unit: 'm',
        currentStock: 420,
        minimumStock: 150,
        reservedStock: 60,
        unitCost: 14.5,
        supplier: 'NorthAlu Supplies',
        updatedAt: now,
      ),
      InventoryItem(
        id: 'inv_2',
        sku: 'GLS-DOUBLE',
        name: 'Double glazed unit stock (generic)',
        category: InventoryCategory.glass,
        unit: 'm²',
        currentStock: 38,
        minimumStock: 40,
        reservedStock: 12,
        unitCost: 72,
        supplier: 'ClearView Glass',
        updatedAt: now,
      ),
      InventoryItem(
        id: 'inv_3',
        sku: 'HNG-STD',
        name: 'Standard hinge',
        category: InventoryCategory.hardware,
        unit: 'pcs',
        currentStock: 640,
        minimumStock: 200,
        unitCost: 4.5,
        supplier: 'Fastline Hardware',
        updatedAt: now,
      ),
      InventoryItem(
        id: 'inv_4',
        sku: 'HDL-PREMIUMLEVER',
        name: 'Premium lever handle',
        category: InventoryCategory.hardware,
        unit: 'pcs',
        currentStock: 24,
        minimumStock: 30,
        unitCost: 63,
        supplier: 'Fastline Hardware',
        updatedAt: now,
      ),
      InventoryItem(
        id: 'inv_5',
        sku: 'SEAL-EPDM',
        name: 'EPDM weather seal',
        category: InventoryCategory.accessory,
        unit: 'm',
        currentStock: 900,
        minimumStock: 200,
        unitCost: 1.2,
        supplier: 'SealTech',
        updatedAt: now,
      ),
      InventoryItem(
        id: 'inv_6',
        sku: 'FIN-ANTHRACITE',
        name: 'Anthracite powder coat batch',
        category: InventoryCategory.finish,
        unit: 'kg',
        currentStock: 55,
        minimumStock: 20,
        unitCost: 9.4,
        supplier: 'ColorCoat Ltd.',
        updatedAt: now,
      ),
    ];
    for (final i in items) {
      await repos.inventory.save(i);
    }
  }

  Future<void> _seedNotifications() async {
    final existing = await repos.notifications.getAll();
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    final items = [
      AppNotification(
        id: 'notif_1',
        type: NotificationType.newOrder,
        title: 'New order confirmed',
        body: 'Order for Bayati Villa — Windows Package moved to production.',
        relatedEntityId: 'order_1',
        createdAt: now.subtract(const Duration(days: 20)),
        isRead: true,
      ),
      AppNotification(
        id: 'notif_2',
        type: NotificationType.lowInventory,
        title: 'Low stock: Double glazed unit stock',
        body: 'Current stock (38 m²) is below the minimum threshold (40 m²).',
        relatedEntityId: 'inv_2',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: 'notif_3',
        type: NotificationType.general,
        title: 'Quotation sent',
        body: 'Quotation for Skyline Office Fit-Out was sent to Sara Mahmoud.',
        relatedEntityId: 'quote_1',
        createdAt: now.subtract(const Duration(days: 3)),
        isRead: true,
      ),
      AppNotification(
        id: 'notif_4',
        type: NotificationType.projectDeadline,
        title: 'Project deadline approaching',
        body: 'Bayati Villa — Windows Package is due in 15 days.',
        relatedEntityId: 'proj_1',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
    for (final n in items) {
      await repos.notifications.add(n);
    }
  }
}
