// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3551 — the Demo practice (#3863: the practice in Berlin, a business of
// its own without places, seeded so — no flag is switched here): the owner
// opens the app on the Overview, the bar reads Overview, Clients, Invoices,
// Messages, the centre action is "New invoice", and no screen passed shows a
// place word. At the desk the five surfaces a business without places once
// met — the desk calendar, the Sales menu, Billing, a member's page and the
// setup guide's hours step — show none. Leipzig stays a coworking space with
// its seats and bookings.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/desk_calendar/desk_calendar_page.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/app/shell/shell_drawer_tiles.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_setting_seed.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/features/money/presentation/widgets/carnets_editor.dart';
import 'package:deskilo/features/money/presentation/widgets/member_carnet_tile.dart';
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
    journey.root
        .read(pendingDemoLinkProvider.notifier)
        .hold(DemoLink.parse({'space': 'practice', 'persona': 'owner'}));
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
    expect(
      container.read(currentWorkspaceProvider).value?.id,
      demoPracticeSpaceId,
    );
    // Home is asked for: a practice lands on its Overview.
    final router = container.read(routerProvider)..go('/reserve');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/workspace-overview',
    );
    expect(find.text('Overview'), findsWidgets);
    expect(_placeWordsShown(tester), isEmpty);

    // The centre action is a new invoice.
    final center = tester.widget<ShellCenterButton>(
      find.byType(ShellCenterButton),
    );
    expect(center.label, 'New invoice');
    await tester.tap(find.byType(ShellCenterButton));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('invoice-member-dropdown')),
      findsOneWidget,
    );
    expect(_placeWordsShown(tester), isEmpty);
    // Issue it for a client and the month the form proposes.
    final issued = journey.fixture.practice.money.invoices.length;
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
      journey.fixture.practice.money.invoices.length,
      issued + 1,
      reason: 'the practice issued an invoice from its centre action',
    );
    // It is under Invoices, and still no place word.
    final mine = journey.fixture.practice.money.invoices.last;
    router.go('/invoice-register');
    await tester.pumpAndSettle();
    expect(find.text(mine.memberName), findsWidgets);
    expect(find.text('13/05/2026'), findsWidgets);
    expect(_placeWordsShown(tester), isEmpty);
  });

  testWidgets('at the desk the practice meets no place: the calendar, the '
      'Sales menu, Billing, a member\'s page and the hours step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final journey = DemoJourney.start();
    addTearDown(journey.dispose);
    journey.root
        .read(pendingDemoLinkProvider.notifier)
        .hold(DemoLink.parse({'space': 'practice', 'persona': 'owner'}));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: journey.root,
        child: const DeskiloRoot(),
      ),
    );
    await tester.pumpAndSettle();
    final router = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloApp)),
    ).read(routerProvider);
    // Fixed frames: a page that keeps a progress spinner never settles.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> visit(String path) async {
      router.go(path);
      await settle();
      expect(_placeWordsShown(tester), isEmpty, reason: path);
    }

    await visit('/calendar');
    expect(find.byType(DeskCalendarPage), findsNothing);
    await visit('/invoices');
    final sales = find.byWidgetPredicate(
      (w) => w is DrawerGroup && w.id == 'sales',
    );
    final title = tester.widget<DrawerGroup>(sales).title;
    await tester.tap(
      find.descendant(of: sales, matching: find.text(title)).first,
    );
    await settle();
    expect(find.byKey(const ValueKey('drawer-guest-passes')), findsNothing);
    await visit('/billing');
    expect(find.byType(CarnetsEditor, skipOffstage: false), findsNothing);
    await visit('/member/member-2');
    expect(find.byType(MemberCarnetTile, skipOffstage: false), findsNothing);
    await visit('/setup/step/hours');
    expect(
      find.byKey(const ValueKey('setup-hours-open-availability')),
      findsNothing,
    );
  });

  test('Leipzig stays a coworking space: its seats, its bookings, and no '
      'kind but the default', () {
    final journey = DemoJourney.start();
    addTearDown(journey.dispose);
    final leipzig = journey.fixture.secondSpace;
    expect(leipzig.floorPlan.seats, isNotEmpty);
    expect(leipzig.reservations.reservations, isNotEmpty);
    expect(
      demoSettingSeed.where((s) => s.workspaceId == demoSecondSpaceId),
      isEmpty,
      reason: 'Leipzig reads the default kind, coworking',
    );
    expect(journey.fixture.practice.floorPlan.seats, isEmpty);
    expect(journey.fixture.practice.reservations.reservations, isEmpty);
  });
}
