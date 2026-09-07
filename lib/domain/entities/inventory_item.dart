enum InventoryCategory { profile, glass, panel, hardware, accessory, finish }

class InventoryItem {
  final String id;
  final String sku;
  final String name;
  final InventoryCategory category;
  final String unit;
  final double currentStock;
  final double minimumStock;
  final double reservedStock;
  final double incomingStock;
  final double unitCost;
  final String? supplier;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unit,
    this.currentStock = 0,
    this.minimumStock = 0,
    this.reservedStock = 0,
    this.incomingStock = 0,
    this.unitCost = 0,
    this.supplier,
    required this.updatedAt,
  });

  double get availableStock => (currentStock - reservedStock).clamp(0, double.infinity).toDouble();
  bool get isBelowMinimum => currentStock < minimumStock;

  InventoryItem copyWith({
    double? currentStock,
    double? minimumStock,
    double? reservedStock,
    double? incomingStock,
    double? unitCost,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id,
      sku: sku,
      name: name,
      category: category,
      unit: unit,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      reservedStock: reservedStock ?? this.reservedStock,
      incomingStock: incomingStock ?? this.incomingStock,
      unitCost: unitCost ?? this.unitCost,
      supplier: supplier,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'category': category.name,
        'unit': unit,
        'currentStock': currentStock,
        'minimumStock': minimumStock,
        'reservedStock': reservedStock,
        'incomingStock': incomingStock,
        'unitCost': unitCost,
        'supplier': supplier,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        sku: json['sku'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: InventoryCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => InventoryCategory.accessory,
        ),
        unit: json['unit'] as String? ?? 'pcs',
        currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0,
        minimumStock: (json['minimumStock'] as num?)?.toDouble() ?? 0,
        reservedStock: (json['reservedStock'] as num?)?.toDouble() ?? 0,
        incomingStock: (json['incomingStock'] as num?)?.toDouble() ?? 0,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        supplier: json['supplier'] as String?,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
