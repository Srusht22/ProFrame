import '../entities/inventory_item.dart';

abstract class InventoryRepository {
  Future<List<InventoryItem>> getAll();
  Future<void> save(InventoryItem item);
  Future<void> adjustStock(String id, double deltaQuantity);
}
