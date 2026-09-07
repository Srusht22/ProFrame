import '../entities/manufacturing_order.dart';

abstract class ManufacturingRepository {
  Future<List<ManufacturingOrder>> getAll();
  Future<ManufacturingOrder?> getByOrderId(String orderId);
  Future<void> save(ManufacturingOrder manufacturingOrder);
}
