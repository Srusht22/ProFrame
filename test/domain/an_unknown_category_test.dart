import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'angled_dimensions_test.dart' as angled;
import 'geometry_normalizer_test.dart' show pen;

// A design whose category this version does not know — one a later version
// of ProFrame added, `future_custom_shape` or `circular`, or a value that is
// not a category at all. It used to load as a window: labelled a window,
// read by a window's rules, and written back as `window` over what it said.
// Now it is `DesignKind.unsupported`, the value it was saved with is kept
// beside it and written back exactly, and nothing in it changes.

const anthracite = Finish(colour: 0xFF383E42, material: MaterialKind.aluminium);

/// The brief's sloped fixture — left side 200 cm, right side 150, a
/// transom, a mullion from the slope, a leaf divided glass over a white
/// panel — in an anthracite aluminium frame, its leaf a window with a
/// silver handle and black hinges.
Design sloped({String id = 'angled'}) {
  var d = angled.drawn();
  d = SectionBuilder.rebuild(
    d.withElement(d.openings.single.copyWith(kind: DesignKind.window)),
  );
  d = d.withElement(d.frame!.copyWith(finish: anthracite));
  for (final piece in d.hardware) {
    final colour = piece.kind.isHandle
        ? HardwareColour.silver.colour
        : HardwareColour.black.colour;
    d = d.withElement(
      piece.copyWith(finish: piece.finish.copyWith(colour: colour)),
    );
  }
  final json = d.toJson()..['id'] = id;
  return Design.fromJson(json);
}

/// [d] as a later version would have kept it: under [category], with a
/// field of that version's own beside the rest.
Map<String, Object?> keptAs(Design d, Object? category, {bool has = true}) {
  final json = jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>;
  json.remove('category');
  if (has) json['category'] = category;
  json['futureShape'] = {'radius': 600, 'segments': 48};
  return json;
}

/// Everything about a design but its category, as text.
String allBut(Design d) => jsonEncode(
  d.toJson()
    ..remove('category')
    ..remove('futureShape'),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reading the category', () {
    test('every category this version knows is read as itself, by '
        '`category` and by the older `kind`', () {
      final d = sloped();
      for (final kind in DesignKind.categories) {
        expect(DesignKind.of(kind.name), kind);
        final now = Design.fromJson(keptAs(d, kind.name));
        expect(now.kind, kind);
        expect(now.savedCategory, isNull);
        expect(now.isUnsupported, isFalse);
        expect(now.toJson()['category'], kind.name);
        final older = keptAs(d, null, has: false)..['kind'] = kind.name;
        expect(Design.fromJson(older).kind, kind);
      }
    });

    test('a category this version does not know is Unsupported — never '
        'a window, nor any other category it knows', () {
      final d = sloped();
      for (final saved in <Object?>[
        'future_custom_shape',
        'circular',
        'Window',
        'unsupported',
        '',
        12345,
        3.5,
        true,
        const ['door'],
        const {'name': 'window'},
        null,
      ]) {
        final read = Design.fromJson(keptAs(d, saved));
        expect(read.kind, DesignKind.unsupported, reason: '$saved');
        expect(read.kind, isNot(DesignKind.window), reason: '$saved');
        expect(DesignKind.categories, isNot(contains(read.kind)));
        expect(read.isUnsupported, isTrue);
      }
      // No category at all: not an old design given a default, because
      // every version has written one.
      final none = Design.fromJson(keptAs(d, null, has: false));
      expect(none.kind, DesignKind.unsupported);
      expect(none.savedCategory, isNull);
    });

    test('the category it was saved with is kept, and written back '
        'exactly — through a save and a load as many times as you like', () {
      final d = sloped();
      for (final saved in <Object?>[
        'future_custom_shape',
        'circular',
        12345,
        const {'name': 'window'},
      ]) {
        final first = Design.fromJson(keptAs(d, saved));
        expect(first.savedCategory, saved);
        expect(first.toJson()['category'], saved);
        final text = jsonEncode(first.toJson());
        var again = first;
        for (var i = 0; i < 3; i++) {
          again = Design.fromJson(jsonDecode(jsonEncode(again.toJson())));
          expect(jsonEncode(again.toJson()), text, reason: '$saved, $i');
          expect(again.savedCategory, saved);
        }
        // An edit through the model still keeps it.
        expect(first.copyWith(name: 'Renamed').savedCategory, saved);
        // Saying it is a category this version knows is that category, and
        // only that.
        final known = first.copyWith(kind: DesignKind.door);
        expect(known.savedCategory, isNull);
        expect(known.toJson()['category'], 'door');
      }
      // Missing stays missing — nothing is written in its place.
      final none = Design.fromJson(keptAs(d, null, has: false));
      expect(none.toJson().containsKey('category'), isFalse);
      expect(none.toJson().containsKey('kind'), isFalse);
    });

    test('the list keeps it too: a line of the index round-trips with its '
        'category exactly', () {
      final d = Design.fromJson(keptAs(sloped(), 'future_custom_shape'));
      final line = DesignSummary.of(d);
      expect(line.kind, DesignKind.unsupported);
      expect(line.toJson()['category'], 'future_custom_shape');
      final back = DesignSummary.fromJson(line.toJson());
      expect(back.kind, DesignKind.unsupported);
      expect(back.savedCategory, 'future_custom_shape');
      expect(jsonEncode(back.toJson()), jsonEncode(line.toJson()));
      final odd = DesignSummary.fromJson({...line.toJson(), 'category': 12345});
      expect(odd.kind, DesignKind.unsupported);
      expect(odd.toJson()['category'], 12345);
    });
  });

  group('the design itself', () {
    test('the sloped fixture loaded as `future_custom_shape` keeps all of '
        'its geometry — left 200, right 150 — and every part and material', () {
      final d = sloped();
      final unknown = Design.fromJson(keptAs(d, 'future_custom_shape'));
      // Everything but the category is what was kept.
      expect(allBut(unknown), allBut(d));

      final outline = unknown.frame!.outline;
      final left = outline.corners.where((p) => p.x == outline.left);
      final right = outline.corners.where((p) => p.x == outline.right);
      double span(Iterable<Vec2> ps) =>
          ps.map((p) => p.y).reduce((a, b) => a > b ? a : b) -
          ps.map((p) => p.y).reduce((a, b) => a < b ? a : b);
      expect(span(left), closeTo(2000, 1e-6));
      expect(span(right), closeTo(1500, 1e-6));

      expect(unknown.frame!.finish.material, MaterialKind.aluminium);
      expect(unknown.frame!.finish.colour, anthracite.colour);
      final opening = unknown.openings.single;
      expect(opening.kind, DesignKind.window);
      expect(unknown.childDividersOf(opening.sectionId), hasLength(1));
      final panes = unknown.childSectionsOf(opening.sectionId);
      expect(panes, hasLength(2));
      expect(
        panes.map((p) => PanelColour.of(p.finish)),
        contains(PanelColour.white),
      );
      expect(panes.where((p) => p.finish.material.isGlazing), hasLength(1));
      final handles = unknown.hardware.where((h) => h.kind.isHandle);
      final hinges = unknown.hardware.where(
        (h) => h.kind == HardwareKind.hinge,
      );
      expect(handles, isNotEmpty);
      expect(hinges, isNotEmpty);
      for (final h in handles) {
        expect(h.finish.colour, HardwareColour.silver.colour);
      }
      for (final h in hinges) {
        expect(h.finish.colour, HardwareColour.black.colour);
      }
      for (final h in unknown.hardware) {
        expect(unknown.openingHolding(h.parentId), opening);
      }
    });

    test('the solid is built from that geometry exactly as the angled '
        'design it was builds it', () {
      final d = sloped();
      final unknown = Design.fromJson(keptAs(d, 'circular'));
      String facets(Design x) => [
        for (final f in MeshBuilder.build(x).facets)
          '${f.part} ${f.role} ${f.corners}',
      ].join('\n');
      expect(facets(unknown), facets(d));
    });

    test('it is never squared: its policy keeps slopes, and a sheet read '
        'by it keeps a lean a window squares', () {
      expect(DesignKind.unsupported.geometryPolicy, GeometryPolicy.preserve);
      expect(
        NormalizationContext(kind: DesignKind.unsupported).isStandard,
        isFalse,
      );
      // A right side drawn 7° out of upright.
      final sheet = Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000 + 2000 * 0.1228, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
        ],
      );
      Design read(DesignKind kind) => SketchInterpreter.interpret(
        Design.empty(id: 'lean', kind: kind).copyWith(sketch: sheet),
      ).design;
      bool square(Design x) =>
          x.frame!.outline.edges.every((e) => e.a.x == e.b.x || e.a.y == e.b.y);
      expect(square(read(DesignKind.window)), isTrue);
      expect(square(read(DesignKind.unsupported)), isFalse);
      expect(
        SketchInterpreter.interpret(
          Design.empty(
            id: 'lean',
            kind: DesignKind.unsupported,
          ).copyWith(sketch: sheet),
        ).noticeablyCorrected,
        isEmpty,
      );
    });
  });

  group('kept on the device', () {
    /// [design] kept for Adam, then rewritten on the device as a later
    /// version would have left it: under [category], with a field of its
    /// own, in the file and in the index.
    Future<(DesignStore, String)> seed(Design design, Object? category) async {
      final people = CustomerStore();
      final adam = await people.create(name: 'Adam');
      final store = DesignStore(customers: people);
      final kept = await store.save(design.copyWith(customerId: adam.id));
      final prefs = await SharedPreferences.getInstance();
      final key = '${DesignStore.designKeyPrefix}${kept.id}';
      await prefs.setString(key, jsonEncode(keptAs(kept, category)));
      final index =
          jsonDecode(prefs.getString(DesignStore.indexKey)!) as List<Object?>;
      await prefs.setString(
        DesignStore.indexKey,
        jsonEncode([
          for (final line in index.cast<Map<String, Object?>>())
            line['id'] == kept.id ? {...line, 'category': category} : line,
        ]),
      );
      return (DesignStore(customers: people), adam.id);
    }

    test('loaded Unsupported with its category, listed under its customer, '
        'counted and filtered — and never written over', () async {
      final (store, adam) = await seed(sloped(), 'future_custom_shape');
      final prefs = await SharedPreferences.getInstance();
      const key = '${DesignStore.designKeyPrefix}angled';
      final record = prefs.getString(key);

      final loaded = (await store.load('angled'))!;
      expect(loaded.kind, DesignKind.unsupported);
      expect(loaded.kind, isNot(DesignKind.window));
      expect(loaded.savedCategory, 'future_custom_shape');
      expect(loaded.customerId, adam);

      final listed = (await store.page(customerId: adam)).items.single;
      expect(listed.kind, DesignKind.unsupported);
      expect(listed.savedCategory, 'future_custom_shape');
      expect(await store.kindsOf(adam), {DesignKind.unsupported: 1});
      expect(await store.countsByCustomer(), {adam: 1});
      expect(
        (await store.page(customerId: adam, kind: DesignKind.window)).total,
        0,
        reason: 'not among the windows',
      );
      expect(
        (await store.page(
          customerId: adam,
          kind: DesignKind.unsupported,
        )).total,
        1,
      );
      expect((await store.page(query: 'Sloped head')).total, 1);

      // Keeping it, duplicating it, renaming it or giving it to somebody
      // else writes nothing: its record is the later version's.
      final kept = await store.save(loaded.copyWith(name: 'Changed'));
      expect(kept.name, 'Changed');
      expect(await store.duplicate('angled'), isNull);
      expect(await store.retitle('angled', 'Changed'), isNull);
      expect(await store.rename('angled', 'Sara'), isNull);
      expect(prefs.getString(key), record);
      expect(await store.count(), 1);
    });

    test('another design kept beside it rewrites the index, and its line '
        'keeps its category exactly', () async {
      final (store, adam) = await seed(sloped(), 'circular');
      await store.save(
        sloped(id: 'second').copyWith(customerId: adam, name: 'Second'),
      );
      final prefs = await SharedPreferences.getInstance();
      final index = (jsonDecode(prefs.getString(DesignStore.indexKey)!) as List)
          .cast<Map<String, Object?>>();
      expect(
        index.singleWhere((l) => l['id'] == 'angled')['category'],
        'circular',
      );
      expect(
        index.singleWhere((l) => l['id'] == 'second')['category'],
        'angled',
      );
      final fresh = DesignStore(customers: CustomerStore());
      final kinds = await fresh.kindsOf(adam);
      expect(kinds, {DesignKind.unsupported: 1, DesignKind.angled: 1});
      // The unknown key a later version wrote is still in the record.
      final record = jsonDecode(
        prefs.getString('${DesignStore.designKeyPrefix}angled')!,
      ) as Map<String, Object?>;
      expect(record['futureShape'], {'radius': 600, 'segments': 48});
      expect(record['category'], 'circular');
    });

    test('a malformed category on the device loads, lists and filters '
        'without failing', () async {
      final (store, adam) = await seed(sloped(), 12345);
      final loaded = (await store.load('angled'))!;
      expect(loaded.kind, DesignKind.unsupported);
      expect(loaded.savedCategory, 12345);
      final page = await store.page(customerId: adam);
      expect(page.items.single.kind, DesignKind.unsupported);
      for (final kind in DesignKind.values) {
        await store.page(customerId: adam, kind: kind);
      }
    });

    test(
      'kept before customers existed, it is given its customer by '
      'adding that alone — its category and its own fields untouched',
      () async {
        final d = sloped();
        final json = keptAs(d, 'future_custom_shape')
          ..remove('customerId')
          ..['customer'] = 'Adam';
        SharedPreferences.setMockInitialValues({
          '${DesignStore.designKeyPrefix}angled': jsonEncode(json),
          DesignStore.indexKey: jsonEncode([
            {...DesignSummary.of(Design.fromJson(json)).toJson()},
          ]),
        });
        final store = DesignStore(customers: CustomerStore());
        final loaded = (await store.load('angled'))!;
        expect(loaded.customerId, isNotNull);
        final prefs = await SharedPreferences.getInstance();
        final record = jsonDecode(
          prefs.getString('${DesignStore.designKeyPrefix}angled')!,
        ) as Map<String, Object?>;
        expect({...record}..remove('customerId'), json);
        expect(record['category'], 'future_custom_shape');
      },
    );
  });
}
