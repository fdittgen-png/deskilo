// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4069 — the members directory has a labelled search above its list: it
// finds a person by name or e-mail, case and accents aside; a search that
// finds no one says so and offers to clear it, which brings everyone back.
// The rows are compact: a status says itself in text and an icon.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/directory_screen.dart';

Future<void> _pump(WidgetTester tester, {bool admin = false}) async {
  final seeded = seedDirectory();
  seeded.workspace.memberEmails = {'member-5': 'dora@example.org'};
  // E-mails are for those who administer the space (#410).
  if (admin) seeded.workspace.myMember = directoryMember(1, isAdmin: true);
  await pumpDirectory(
    tester,
    workspace: seeded.workspace,
    reservations: seeded.reservations,
    floorPlan: seeded.floorPlan,
    profile: seeded.profile,
  );
}

Finder get _field => find.descendant(
  of: find.byKey(const ValueKey('directory-search')),
  matching: find.byType(TextField),
);

void main() {
  testWidgets('the search is labelled and finds a person by name, case '
      'aside', (tester) async {
    await _pump(tester);
    expect(find.text('Search by name or e-mail'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    await tester.enterText(_field, 'bEN');
    await tester.pumpAndSettle();
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Anna'), findsNothing);
    expect(find.text('Cara'), findsNothing);
  });

  testWidgets('an e-mail the reader may see finds its member', (tester) async {
    await _pump(tester, admin: true);
    await tester.enterText(_field, 'dora@');
    await tester.pumpAndSettle();
    expect(find.text('Dora'), findsOneWidget);
    expect(find.text('Ben'), findsNothing);
  });

  testWidgets('a member who may not see e-mails is not found by one', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(_field, 'dora@');
    await tester.pumpAndSettle();
    expect(find.text('Dora'), findsNothing);
    expect(find.byKey(const ValueKey('directory-search-none')), findsOneWidget);
  });

  testWidgets('no one found: it says so, and clearing brings everyone back', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(_field, 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('directory-search-none')), findsOneWidget);
    expect(find.text('No one matches “zzz”'), findsOneWidget);
    expect(find.text('Anna'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('directory-search-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('directory-search-none')), findsNothing);
    for (final name in ['Anna', 'Ben', 'Cara', 'Dora']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(tester.widget<TextField>(_field).controller!.text, isEmpty);
  });

  testWidgets('a status says itself in text and an icon', (tester) async {
    await _pump(tester);
    final online = find.byKey(const ValueKey('directory-status-member-2'));
    expect(
      find.descendant(of: online, matching: find.text('Online')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: online, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });
}
