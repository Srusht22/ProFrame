import '../entities/order.dart';

abstract class OrderRepository {
  Future<List<Order>> getAll();
  Future<Order?> getById(String id);
  Future<void> save(Order order);
  Future<String> nextOrderNumber();
}
