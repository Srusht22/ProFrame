class CuttingListLine {
  final String component;
  final double lengthMm;
  final int quantity;
  final String material;
  final String? notes;

  const CuttingListLine({
    required this.component,
    required this.lengthMm,
    required this.quantity,
    required this.material,
    this.notes,
  });

  double get totalLengthMm => lengthMm * quantity;
}
