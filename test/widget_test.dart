import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/main.dart';

void main() {
  testWidgets('ProFrameApp launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ProFrameApp(),
      ),
    );
    expect(find.byType(ProFrameApp), findsOneWidget);
  });
}
