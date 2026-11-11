// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3551 — the Demo practice (Leipzig, its places switched off): the owner
// opens the app on the Overview, the bar reads Overview, Clients, Invoices,
// Messages, the centre action is "New invoice", and no screen passed shows a
// place word.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

/// The words of the places a practice does not have, as whole words (the
/// product's own name contains "desk").
final _placeWords = RegExp(
  r'\b(desks?|seats?|floors?|levels?|kiosks?)\b',
  caseSensitive: false,
);

List<String> _placeWordsShown(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if (_placeWords.hasMatch(t.data ?? t.textSpan?.toPlainText() ?? ''))
      t.data ?? t.textSpan!.toPlainText(),
];

void main() {
  testWidgets('the Demo practice opens on its Overview, with Clients, '
      'Invoices and a New invoice action, and no place word', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final journey = DemoJourney.start();
    addTearDown(journey.dispose);
    journey.fixture.prefs.navigationStyle.style = NavigationStyle.classic.wire;
    final spaces = journey.fixture.workspaces.workspaces;
    final i = spaces.indexWhere((w) => w.id == demoSecondSpaceId);
    spaces[i] = spaces[i].copyWith(
      featureFlags: {
        ...spaces[i].featureFlags,
        'placeBooking': false,
        'workspaceOverview': true,
      },
    );
    journey.root
        .read(pendingDemoLinkProvider.notifier)
        .hold(DemoLink.parse({'space': 'leipzig', 'persona': 'owner'}));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: journey.root,
        child: const DeskiloRoot(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloApp)),
    );
    expect(container.read(currentWorkspaceProvider).value?.id, demoSecondSpaceId);
    // Home is asked for: a practice lands on its Overview.
    final router = container.read(routerProvider)..go('/reserve');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/workspace-overview');
    expect(find.text('Overview'), findsWidgets);
    expect(_placeWordsShown(tester), isEmpty);

    // The centre action is a new invoice.
    final center = tester.widget<ShellCenterButton>(find.byType(ShellCenterButton));
    expect(center.label, 'New invoice');
    await tester.tap(find.byType(ShellCenterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-member-dropdown')), findsOneWidget);
    expect(_placeWordsShown(tester), isEmpty);
    // Issue it for a client and the month the form proposes.
    final issued = journey.fixture.secondSpace.money.invoices.length;
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenuItem<String>).last);
    await tester.pumpAndSettle();
    // Last month is invoiced already in the Demo: this month (a client who
    // leaves mid-month is invoiced so too).
    await tester.tap(find.byKey(const ValueKey('invoice-period-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();
    expect(
      journey.fixture.secondSpace.money.invoices.length,
      issued + 1,
      reason: 'the practice issued an invoice from its centre action',
    );
    // It is under Invoices, and still no place word.
    final mine = journey.fixture.secondSpace.money.invoices.last;
    router.go('/invoice-register');
    await tester.pumpAndSettle();
    expect(find.text(mine.memberName), findsWidgets);
    expect(find.text('13/05/2026'), findsWidgets);
    expect(_placeWordsShown(tester), isEmpty);
  });
}
