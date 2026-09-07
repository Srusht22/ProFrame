import '../../core/utils/id_generator.dart';
import 'key_value_store.dart';

/// Backs the human-facing `PRJ-2026-000001` / `Q-2026-000001` /
/// `ORD-2026-000001` numbering (spec §67). Persists the last-used sequence
/// per prefix+year so numbers stay sequential across app restarts.
class SequenceCounter {
  final IKeyValueStore keyValueStore;

  SequenceCounter(this.keyValueStore);

  Future<String> next(String prefix, {int padding = 6}) async {
    final year = DateTime.now().year;
    final key = 'seq_${prefix}_$year';
    final current = int.tryParse(await keyValueStore.read(key) ?? '0') ?? 0;
    final nextValue = current + 1;
    await keyValueStore.write(key, nextValue.toString());
    final sequence = DocumentNumberSequence(prefix: prefix, padding: padding);
    return sequence.format(year: year, sequence: nextValue);
  }
}
