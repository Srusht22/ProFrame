import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A workshop keeps a design for every person it draws for, so the list of
// them has to stay quick however long it grows. The list is read a page at
// a time from an index of one short line a design; a design itself — every
// stroke the user drew — is read only when its card is on the screen or it
// is opened.

final start = DateTime(2026, 1, 1);

/// Design [i], for "Customer [i]", edited [i] minutes after [start] — so the
/// higher the number, the more recent — with a sketch the size of a real
/// one, a few hundred samples.
Design numbered(int i) => Design(
  id: 'design-${1767225600000 + i}-$i',
  name: 'Customer $i',
  customer: 'Customer $i',
  kind: i.isEven ? DesignKind.door : DesignKind.window,
  createdAt: start.add(Duration(minutes: i)),
  updatedAt: start.add(Duration(minutes: i)),
  sketch: Sketch(
    strokes: [
      Stroke(
        id: 's$i',
        samples: [
          for (var k = 0; k < 200; k++)
            StrokeSample(Vec2(k * 10.0, (k % 7) * 3.0)),
        ],
      ),
    ],
  ),
);

Future<DesignStore> keep(int count) async {
  final store = DesignStore();
  for (var i = 0; i < count; i++) {
    await store.save(numbered(i));
  }
  return store;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a page at a time, the most recently edited first', () async {
    final store = await keep(1000);
    final first = await store.page(limit: 40);
    expect(first.total, 1000);
    expect(first.items, hasLength(40));
    expect(first.items.first.customer, 'Customer 999');
    expect(first.items.last.customer, 'Customer 960');

    final later = await store.page(offset: 960, limit: 40);
    expect(later.items, hasLength(40));
    expect(later.items.last.customer, 'Customer 0');
    final past = await store.page(offset: 1000, limit: 40);
    expect(past.items, isEmpty);
    expect(past.total, 1000);
  });

  test('the list is read from short lines, not from the designs', () async {
    await keep(200);
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getString(DesignStore.indexKey)!;
    final design = prefs.getString(
      '${DesignStore.designKeyPrefix}${numbered(0).id}',
    )!;
    // A line of the index is a small part of the design it stands for:
    // no strokes, no geometry.
    expect(index.length / 200, lessThan(design.length / 10));
    expect(index, isNot(contains('samples')));
  });

  test('a search among thousands finds the one', () async {
    final store = await keep(3000);
    final watch = Stopwatch()..start();
    final found = await store.page(query: 'customer 1234');
    watch.stop();
    expect(found.total, 1);
    expect(found.items.single.customer, 'Customer 1234');
    // By its number, too.
    final byNumber = await store.page(query: found.items.single.number);
    expect(byNumber.items.single.id, found.items.single.id);
    // And quickly: the index, not the designs.
    expect(watch.elapsedMilliseconds, lessThan(500));
    // A search that finds many is paged like the whole list.
    final many = await store.page(query: 'customer 1', limit: 40);
    expect(many.items, hasLength(40));
    expect(many.total, greaterThan(1000));
  });

  test('a design is read whole, exactly as kept', () async {
    final store = await keep(50);
    final one = await store.load(numbered(17).id);
    expect(jsonEncode(one!.toJson()), jsonEncode(numbered(17).toJson()));
    expect(await store.load('no-such-design'), isNull);
  });

  test('keeping a design again moves it to the top, and only it', () async {
    final store = await keep(100);
    final edited = numbered(3).copyWith(customer: 'Customer 3, again');
    await store.save(edited);
    final top = await store.page(limit: 2);
    expect(top.total, 100, reason: 'kept again, not kept twice');
    expect(top.items.first.id, edited.id);
    expect(top.items.first.customer, 'Customer 3, again');
    expect(top.items.last.customer, 'Customer 99');
  });

  test('a design removed is gone from the list and the store', () async {
    final store = await keep(10);
    await store.remove(numbered(4).id);
    final all = await store.page(limit: 100);
    expect(all.total, 9);
    expect(all.items.map((s) => s.id), isNot(contains(numbered(4).id)));
    expect(await store.load(numbered(4).id), isNull);
  });

  test(
    'designs kept by the earlier version are moved over, not lost',
    () async {
      final older = [numbered(1), numbered(2)];
      SharedPreferences.setMockInitialValues({
        DesignStore.legacyKey: [for (final d in older) jsonEncode(d.toJson())],
      });
      final store = DesignStore();
      final page = await store.page();
      expect(page.total, 2);
      expect(page.items.first.customer, 'Customer 2');
      for (final d in older) {
        expect(
          jsonEncode((await store.load(d.id))!.toJson()),
          jsonEncode(d.toJson()),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(DesignStore.legacyKey), isNull);
    },
  );

  testWidgets('the screen reads a page, and the next as it scrolls', (
    tester,
  ) async {
    await tester.runAsync(() => keep(150));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: ProFrameApp()));
    await tester.pumpAndSettle();

    expect(find.text('150 designs'), findsOneWidget);
    expect(find.text('Customer 149'), findsOneWidget);
    // Only what is on the screen is built, not all a hundred and fifty.
    expect(
      find.byType(DesignCard).evaluate().length,
      lessThan(DesignsScreen.pageSize),
    );

    // The oldest is there, by scrolling to it.
    await tester.scrollUntilVisible(
      find.text('Customer 0'),
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    expect(find.text('Customer 0'), findsOneWidget);
  });
}
