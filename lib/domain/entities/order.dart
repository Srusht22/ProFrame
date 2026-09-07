import 'quotation.dart';

enum OrderStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  inProduction('In Production'),
  qualityControl('Quality Control'),
  ready('Ready'),
  delivered('Delivered'),
  installed('Installed'),
  completed('Completed'),
  cancelled('Cancelled');

  final String label;
  const OrderStatus(this.label);

  static const List<OrderStatus> progressionOrder = [
    pending,
    confirmed,
    inProduction,
    qualityControl,
    ready,
    delivered,
    installed,
    completed,
  ];

  double get progressFraction {
    final index = progressionOrder.indexOf(this);
    if (index < 0) return 0;
    return (index + 1) / progressionOrder.length;
  }
}

/// Created from an accepted [Quotation] — spec §25/§68: only a validated,
/// quoted configuration is allowed to become a confirmed order.
class Order {
  final String id;
  final String orderNumber;
  final String quotationId;
  final String projectId;
  final String customerId;
  final List<QuoteItem> items;
  final OrderStatus status;
  final double globalDiscountPercent;
  final double globalDiscountFixed;
  final double taxPercent;
  final double installationCostPerUnit;
  final double deliveryCost;
  final String? notes;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.quotationId,
    required this.projectId,
    required this.customerId,
    this.items = const [],
    this.status = OrderStatus.pending,
    this.globalDiscountPercent = 0,
    this.globalDiscountFixed = 0,
    this.taxPercent = 0,
    this.installationCostPerUnit = 0,
    this.deliveryCost = 0,
    this.notes,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);
  double get itemsSubtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);
  double get globalDiscountAmount =>
      (itemsSubtotal * (globalDiscountPercent / 100)) + globalDiscountFixed;
  double get installationTotal => installationCostPerUnit * totalUnits;
  double get taxableAmount =>
      (itemsSubtotal - globalDiscountAmount).clamp(0, double.infinity).toDouble() + installationTotal + deliveryCost;
  double get taxAmount => taxableAmount * (taxPercent / 100);
  double get grandTotal => taxableAmount + taxAmount;

  factory Order.fromQuotation({
    required String id,
    required String orderNumber,
    required Quotation quotation,
    required String createdByUserId,
  }) {
    final now = DateTime.now();
    return Order(
      id: id,
      orderNumber: orderNumber,
      quotationId: quotation.id,
      projectId: quotation.projectId,
      customerId: quotation.customerId,
      items: quotation.items,
      status: OrderStatus.pending,
      globalDiscountPercent: quotation.globalDiscountPercent,
      globalDiscountFixed: quotation.globalDiscountFixed,
      taxPercent: quotation.taxPercent,
      installationCostPerUnit: quotation.installationCostPerUnit,
      deliveryCost: quotation.deliveryCost,
      notes: quotation.notes,
      createdByUserId: createdByUserId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Order copyWith({OrderStatus? status, String? notes, DateTime? updatedAt}) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      quotationId: quotationId,
      projectId: projectId,
      customerId: customerId,
      items: items,
      status: status ?? this.status,
      globalDiscountPercent: globalDiscountPercent,
      globalDiscountFixed: globalDiscountFixed,
      taxPercent: taxPercent,
      installationCostPerUnit: installationCostPerUnit,
      deliveryCost: deliveryCost,
      notes: notes ?? this.notes,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'quotationId': quotationId,
        'projectId': projectId,
        'customerId': customerId,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status.name,
        'globalDiscountPercent': globalDiscountPercent,
        'globalDiscountFixed': globalDiscountFixed,
        'taxPercent': taxPercent,
        'installationCostPerUnit': installationCostPerUnit,
        'deliveryCost': deliveryCost,
        'notes': notes,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String? ?? '',
        quotationId: json['quotationId'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        customerId: json['customerId'] as String? ?? '',
        items: (json['items'] as List?)
                ?.map((e) => QuoteItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        status: OrderStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => OrderStatus.pending,
        ),
        globalDiscountPercent: (json['globalDiscountPercent'] as num?)?.toDouble() ?? 0,
        globalDiscountFixed: (json['globalDiscountFixed'] as num?)?.toDouble() ?? 0,
        taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
        installationCostPerUnit: (json['installationCostPerUnit'] as num?)?.toDouble() ?? 0,
        deliveryCost: (json['deliveryCost'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String?,
        createdByUserId: json['createdByUserId'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
