import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumpy_skin/main.dart';

void main() {
  testWidgets('Language selection screen is shown first',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CowHealthScannerApp());

    expect(find.text('Choose Your Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('اردو'), findsOneWidget);
  });

  testWidgets('Selecting English opens the home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CowHealthScannerApp());

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Cow Health Scanner'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    // Result card sits below the fold in a lazily-built CustomScrollView.
    await tester.scrollUntilVisible(
      find.text('Awaiting scan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Awaiting scan'), findsOneWidget);
  });

  testWidgets('Selecting Urdu opens the home screen in RTL',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CowHealthScannerApp());

    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    expect(find.text('گائے کی صحت اسکینر'), findsOneWidget);
    expect(find.text('کیمرہ'), findsOneWidget);
    expect(find.text('گیلری'), findsOneWidget);

    final BuildContext ctx = tester.element(find.text('کیمرہ'));
    expect(Directionality.of(ctx), TextDirection.rtl);
  });
}
