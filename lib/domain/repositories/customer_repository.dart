import '../entities/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getAll();
  Future<Customer?> getById(String id);
  Future<void> save(Customer customer);
  Future<void> delete(String id);
}
