// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shell shows the three localized destinations', (tester) async {
    await pumpApp(tester);

    expect(find.byType(ShellBottomBar), findsOneWidget);
    // #702: Members left the bar for the inbox's third face, the same
    // way Events left it for the app-bar bell in #230 and then for the
    // inbox's second face.
    for (final label in ['Messages', 'Calendar', 'Money']) {
      expect(find.text(label), findsWidgets, reason: 'missing tab "$label"');
    }
    expect(
      find.descendant(
        of: find.byType(ShellBottomBar),
        matching: find.text('Members'),
      ),
      findsNothing,
    );
  });

  testWidgets('the directory is one tap into the inbox (#702)',
      (tester) async {
    await pumpApp(tester);

    await openMembersTab(tester);

    // The bottom bar is still there — the directory did not become a
    // pushed route, it became a face of a destination.
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-tab-members')), findsOneWidget);
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
    // #402: the iOS floor (44dp) and the LABELED guideline — every
    // tappable must carry a semantic label, or it reads as "button" to a
    // screen reader.
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
