class BomLine {
  final String partNumber;
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;

  const BomLine({
    required this.partNumber,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;
}
