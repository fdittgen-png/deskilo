// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: DeskiloApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shell shows the four localized destinations', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Plan', 'Calendar', 'Events', 'Money']) {
      expect(find.text(label), findsWidgets, reason: 'missing tab "$label"');
    }
  });

  testWidgets('tapping a destination switches the branch and app-bar title',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Money'),
    );
    expect(appBarTitle, findsOneWidget);
  });

  testWidgets('settings app-bar action pushes the settings screen',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('interactive elements meet the Android tap-target guideline',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
