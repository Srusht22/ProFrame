import 'dart:convert';

import 'design.dart';

/// Whether a design is completed: the user pressed **Complete!** on it, and
/// it is still the design they completed.
///
/// A design is a **draft** until then, and again after any change to it —
/// a line drawn, a size given, a pane made glass, an extra added — because
/// what was completed was the design as it stood. Nothing has to remember
/// to say so: completing keeps a fingerprint of the design
/// ([Design.completedAs]), and a design is completed only while its
/// fingerprint is still that one. Each design has its own; a customer's
/// job is not completed because one of their designs is.
///
/// Completing is not quoting and not paying: it changes no price, makes no
/// quotation and records no payment.
abstract final class DesignCompletion {
  /// What the fingerprint leaves out: who the design is (its id, its name,
  /// whose it is), when it was made and changed, the ink — a reading builds
  /// the design from it, and the design is what is completed — and the
  /// fingerprint itself.
  static const _notTheDesign = {
    'id',
    'name',
    'customer',
    'customerId',
    'createdAt',
    'updatedAt',
    'sketch',
    'sketchUnread',
    'completedAs',
  };

  static final _fingerprints = Expando<String>();

  /// A short fingerprint of everything [design] is, apart from
  /// [_notTheDesign]. The same design gives the same fingerprint on every
  /// platform.
  static String fingerprintOf(Design design) =>
      _fingerprints[design] ??= _key(jsonEncode(_content(design)));

  static Map<String, Object?> _content(Design design) {
    final json = Map<String, Object?>.of(design.toJson())
      ..removeWhere((key, _) => _notTheDesign.contains(key));
    if (json['pricing'] case final Map<String, Object?> pricing) {
      json['pricing'] = Map<String, Object?>.of(pricing)..remove('snapshot');
    }
    return json;
  }

  /// Whether [design] is completed: completed once, unchanged since, and
  /// with no lines drawn that have not been read.
  static bool isCompleted(Design design) =>
      design.completedAs != null &&
      !design.sketchUnread &&
      design.completedAs == fingerprintOf(design);

  /// [design], completed as it stands. The caller has checked that it is
  /// complete; this only says it was completed.
  static Design complete(Design design, {DateTime? at}) {
    final stamped = design.copyWith(updatedAt: at);
    return stamped.copyWith(
      completedAs: fingerprintOf(stamped),
      updatedAt: stamped.updatedAt,
    );
  }

  static String _key(String text) =>
      '${_fnv(text, 0x811C9DC5)}${_fnv(text, 0x050C5D1F)}-${text.length}';

  /// FNV-1a over the text's code units, 32 bits, written the same on every
  /// platform: the multiply is split so no step leaves the 53 bits a web
  /// number holds exactly.
  static String _fnv(String text, int seed) {
    var h = seed;
    for (final c in text.codeUnits) {
      h = (h ^ c) & 0xFFFFFFFF;
      h = (h * 0x193 + ((h & 0xFF) << 24)) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
