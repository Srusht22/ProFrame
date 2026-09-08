import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app.dart';
import 'package:proframe/core/di/providers.dart';
import 'package:proframe/data/demo/demo_data_seeder.dart';
import 'package:proframe/data/local/key_value_store.dart';

/// In-memory stand-in for the SharedPreferences-backed store, so the whole
/// app (seeding, repositories, auth, router, shell) can boot inside a test.
class InMemoryKeyValueStore implements IKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  testWidgets('app boots to the login screen and signs a user in to the dashboard', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore())],
        child: const ProFrameApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Unauthenticated users land on the login screen.
    expect(find.text('Sign in to ProFrame'), findsOneWidget);

    // Sign in with the seeded admin demo account.
    await tester.enterText(find.byType(TextFormField).first, 'admin@proframe.demo');
    await tester.enterText(find.byType(TextFormField).last, DemoDataSeeder.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // The router redirect should now put us inside the shell on the dashboard,
    // rendering live stats seeded by DemoDataSeeder.
    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Total customers'), findsOneWidget);
    expect(find.text('Quotations'), findsWidgets); // nav rail destination
  });
}
