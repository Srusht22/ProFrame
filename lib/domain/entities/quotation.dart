enum QuotationStatus {
  draft('Draft'),
  sent('Sent'),
  viewed('Viewed'),
  accepted('Accepted'),
  rejected('Rejected'),
  expired('Expired'),
  cancelled('Cancelled');

  final String label;
  const QuotationStatus(this.label);
}

/// A priced line on a quotation. Price fields are a *snapshot* taken from
/// the [PricingEngine] at the moment the item was added — exactly like a
/// real manufacturer's quote, changing pricing rules afterwards must not
/// silently rewrite quotes that already went out to a customer.
class QuoteItem {
  final String id;
  final String configurationId;
  final String configurationName;
  final String productTypeLabel;
  final String dimensionsLabel;
  final double widthMm;
  final double heightMm;
  final int quantity;
  final double unitPrice;
  final double discountPercent;
  final double discountFixed;
  final String currencyCode;
  final String currencySymbol;

  const QuoteItem({
    required this.id,
    required this.configurationId,
    required this.configurationName,
    required this.productTypeLabel,
    required this.dimensionsLabel,
    this.widthMm = 0,
    this.heightMm = 0,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.discountFixed = 0,
    this.currencyCode = 'USD',
    this.currencySymbol = '\$',
  });

  double get grossTotal => unitPrice * quantity;
  double get discountAmount => (grossTotal * (discountPercent / 100)) + discountFixed;
  double get lineTotal => (grossTotal - discountAmount).clamp(0, double.infinity).toDouble();

  QuoteItem copyWith({
    int? quantity,
    double? unitPrice,
    double? discountPercent,
    double? discountFixed,
  }) {
    return QuoteItem(
      id: id,
      configurationId: configurationId,
      configurationName: configurationName,
      productTypeLabel: productTypeLabel,
      dimensionsLabel: dimensionsLabel,
      widthMm: widthMm,
      heightMm: heightMm,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      discountFixed: discountFixed ?? this.discountFixed,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'configurationId': configurationId,
        'configurationName': configurationName,
        'productTypeLabel': productTypeLabel,
        'dimensionsLabel': dimensionsLabel,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
        'discountFixed': discountFixed,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
      };

  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem(
        id: json['id'] as String,
        configurationId: json['configurationId'] as String,
        configurationName: json['configurationName'] as String? ?? '',
        productTypeLabel: json['productTypeLabel'] as String? ?? '',
        dimensionsLabel: json['dimensionsLabel'] as String? ?? '',
        widthMm: (json['widthMm'] as num?)?.toDouble() ?? 0,
        heightMm: (json['heightMm'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
        discountFixed: (json['discountFixed'] as num?)?.toDouble() ?? 0,
        currencyCode: json['currencyCode'] as String? ?? 'USD',
        currencySymbol: json['currencySymbol'] as String? ?? '\$',
      );
}

class Quotation {
  final String id;
  final String quoteNumber;
  final String projectId;
  final String customerId;
  final List<QuoteItem> items;
  final QuotationStatus status;
  final DateTime issueDate;
  final DateTime expiryDate;
  final double globalDiscountPercent;
  final double globalDiscountFixed;
  final double taxPercent;
  final double installationCostPerUnit;
  final double deliveryCost;
  final String? notes;
  final String termsAndConditions;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Quotation({
    required this.id,
    required this.quoteNumber,
    required this.projectId,
    required this.customerId,
    this.items = const [],
    this.status = QuotationStatus.draft,
    required this.issueDate,
    required this.expiryDate,
    this.globalDiscountPercent = 0,
    this.globalDiscountFixed = 0,
    this.taxPercent = 0,
    this.installationCostPerUnit = 0,
    this.deliveryCost = 0,
    this.notes,
    this.termsAndConditions = '',
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  double get itemsSubtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  double get globalDiscountAmount =>
      (itemsSubtotal * (globalDiscountPercent / 100)) + globalDiscountFixed;

  double get installationTotal => installationCostPerUnit * totalUnits;

  double get subtotalAfterDiscount =>
      (itemsSubtotal - globalDiscountAmount).clamp(0, double.infinity).toDouble();

  double get taxableAmount => subtotalAfterDiscount + installationTotal + deliveryCost;

  double get taxAmount => taxableAmount * (taxPercent / 100);

  double get grandTotal => taxableAmount + taxAmount;

  Quotation copyWith({
    List<QuoteItem>? items,
    QuotationStatus? status,
    DateTime? issueDate,
    DateTime? expiryDate,
    double? globalDiscountPercent,
    double? globalDiscountFixed,
    double? taxPercent,
    double? installationCostPerUnit,
    double? deliveryCost,
    String? notes,
    String? termsAndConditions,
    DateTime? updatedAt,
  }) {
    return Quotation(
      id: id,
      quoteNumber: quoteNumber,
      projectId: projectId,
      customerId: customerId,
      items: items ?? this.items,
      status: status ?? this.status,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
      globalDiscountFixed: globalDiscountFixed ?? this.globalDiscountFixed,
      taxPercent: taxPercent ?? this.taxPercent,
      installationCostPerUnit: installationCostPerUnit ?? this.installationCostPerUnit,
      deliveryCost: deliveryCost ?? this.deliveryCost,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'quoteNumber': quoteNumber,
        'projectId': projectId,
        'customerId': customerId,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status.name,
        'issueDate': issueDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'globalDiscountPercent': globalDiscountPercent,
        'globalDiscountFixed': globalDiscountFixed,
        'taxPercent': taxPercent,
        'installationCostPerUnit': installationCostPerUnit,
        'deliveryCost': deliveryCost,
        'notes': notes,
        'termsAndConditions': termsAndConditions,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Quotation.fromJson(Map<String, dynamic> json) => Quotation(
        id: json['id'] as String,
        quoteNumber: json['quoteNumber'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        customerId: json['customerId'] as String? ?? '',
        items: (json['items'] as List?)
                ?.map((e) => QuoteItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        status: QuotationStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => QuotationStatus.draft,
        ),
        issueDate: DateTime.tryParse(json['issueDate'] as String? ?? '') ?? DateTime.now(),
        expiryDate: DateTime.tryParse(json['expiryDate'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
        globalDiscountPercent: (json['globalDiscountPercent'] as num?)?.toDouble() ?? 0,
        globalDiscountFixed: (json['globalDiscountFixed'] as num?)?.toDouble() ?? 0,
        taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
        installationCostPerUnit: (json['installationCostPerUnit'] as num?)?.toDouble() ?? 0,
        deliveryCost: (json['deliveryCost'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String?,
        termsAndConditions: json['termsAndConditions'] as String? ?? '',
        createdByUserId: json['createdByUserId'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
