import '../../domain/entities/quotation.dart';
import '../../domain/repositories/quotation_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';
import '../local/sequence_counter.dart';

class LocalQuotationRepository implements QuotationRepository {
  final JsonCollectionStore<Quotation> _store;
  final SequenceCounter _sequence;
  final String _prefix;

  LocalQuotationRepository(IKeyValueStore keyValueStore, {String prefix = 'Q'})
      : _prefix = prefix,
        _sequence = SequenceCounter(keyValueStore),
        _store = JsonCollectionStore<Quotation>(
          keyValueStore: keyValueStore,
          collectionKey: 'quotations',
          toJson: (q) => q.toJson(),
          fromJson: Quotation.fromJson,
        );

  @override
  Future<List<Quotation>> getAll() => _store.readAll();

  @override
  Future<Quotation?> getById(String id) async {
    final all = await _store.readAll();
    for (final q in all) {
      if (q.id == id) return q;
    }
    return null;
  }

  @override
  Future<void> save(Quotation quotation) async {
    final all = await _store.readAll();
    final index = all.indexWhere((q) => q.id == quotation.id);
    if (index >= 0) {
      all[index] = quotation;
    } else {
      all.add(quotation);
    }
    await _store.writeAll(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = await _store.readAll();
    all.removeWhere((q) => q.id == id);
    await _store.writeAll(all);
  }

  @override
  Future<String> nextQuoteNumber() => _sequence.next(_prefix);
}
