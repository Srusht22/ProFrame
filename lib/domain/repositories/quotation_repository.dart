import '../entities/quotation.dart';

abstract class QuotationRepository {
  Future<List<Quotation>> getAll();
  Future<Quotation?> getById(String id);
  Future<void> save(Quotation quotation);
  Future<void> delete(String id);
  Future<String> nextQuoteNumber();
}
