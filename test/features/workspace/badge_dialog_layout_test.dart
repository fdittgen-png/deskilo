// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1178 — the badge manager with more than a badge or two in it.
//
// Four badges made the dialog three separate problems at once: the
// unbounded list of rows painted itself OVER the actions, so "Close"
// landed on a switch and "New badge" on a Revoke; every unnamed badge
// read "Badge", so `Revoke` sat beside four identical rows; and the
// three-line "Off by default" hint repeated under every switch, until
// two thirds of the dialog was the same sentence.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// Open Settings → My badge with [count] badges already issued, on a
/// phone-sized screen — the dialog only overflowed where there was not
/// room to spare.
Future<FakeWorkspaceRepository> openWithBadges(
  WidgetTester tester,
  int count,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace();
  for (var i = 0; i < count; i++) {
    await workspace.issueMemberBadge('ws-1', 'member-1');
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-my-badge')));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('the list scrolls inside the dialog instead of covering '
      'its buttons', (tester) async {
    await openWithBadges(tester, 4);

    // The rows live in their own viewport, so the list runs out of
    // room by scrolling rather than by growing over the buttons.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );

    // And the proof that matters: Close still closes. It used to land
    // on whatever badge row had grown over it.
    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .map((s) => s.value)
        .toList();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'the tap reached the button, not a badge row');
    expect(switches.every((v) => v == false), isTrue,
        reason: 'and it flipped nothing on the way');
  });

  testWidgets('each badge says WHICH one it is, so Revoke is not beside '
      'four identical rows', (tester) async {
    await openWithBadges(tester, 3);
    expect(find.textContaining('Issued '), findsNWidgets(3),
        reason: 'the icon already says QR or card; the issue date says '
            'which');
  });

  testWidgets('the "Off by default" hint is said once, not once per '
      'switch', (tester) async {
    await openWithBadges(tester, 3);
    expect(find.textContaining('Off by default'), findsOneWidget,
        reason: 'repeated under every switch, it was two thirds of the '
            'dialog');
  });
}
