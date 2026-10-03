// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1835 — Me › Home › My visits: nothing when the account holds no visit;
// one card per visit with its status and the line that says it is not a
// membership; Cancel asks the server and the list re-reads; a refusal is
// said, not swallowed; a declined visit offers no cancel.
import 'package:deskilo/features/visits/domain/guest_participation.dart';
import 'package:deskilo/features/visits/presentation/my_visits_section.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

GuestParticipation _visit(String id, GuestVisitStatus status) =>
    GuestParticipation(
      id: id,
      workspaceId: 'w-1',
      workspaceName: 'Kraftwerk',
      siteName: 'Hall',
      status: status,
      startsAt: DateTime.utc(2026, 10, 10, 8),
      endsAt: DateTime.utc(2026, 10, 10, 12),
    );

Future<void> _pump(
  WidgetTester tester,
  FakeGuestParticipationRepository fake,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(guestVisits: fake),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ListView(children: const [MyVisitsSection()])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no visit: the section is not there', (tester) async {
    await _pump(tester, FakeGuestParticipationRepository());
    expect(find.byKey(const ValueKey('me-visits')), findsNothing);
  });

  testWidgets('each visit is a card: where, status, and not a membership', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeGuestParticipationRepository(
        visits: [
          _visit('v-1', GuestVisitStatus.confirmed),
          _visit('v-2', GuestVisitStatus.declined),
        ],
      ),
    );
    expect(find.byKey(const ValueKey('me-visits')), findsOneWidget);
    expect(find.text('My visits'), findsOneWidget);
    expect(find.text('Kraftwerk · Hall'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('me-visit-status-confirmed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('me-visit-status-declined')),
      findsOneWidget,
    );
    expect(find.text('Guest visit — not a membership'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('me-visit-cancel-v-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('me-visit-cancel-v-2')),
      findsNothing,
      reason: 'a declined visit has nothing left to cancel',
    );
  });

  testWidgets('Cancel asks the server and the list shows what it holds now', (
    tester,
  ) async {
    final fake = FakeGuestParticipationRepository(
      visits: [_visit('v-1', GuestVisitStatus.requested)],
    );
    await _pump(tester, fake);
    await tester.tap(find.byKey(const ValueKey('me-visit-cancel-v-1')));
    await tester.pumpAndSettle();
    expect(fake.cancelled, ['v-1']);
    expect(
      find.byKey(const ValueKey('me-visit-status-cancelled')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('me-visit-cancel-v-1')), findsNothing);
  });

  testWidgets('a refused cancel is said, and nothing changes', (tester) async {
    final fake = FakeGuestParticipationRepository(
      visits: [_visit('v-1', GuestVisitStatus.confirmed)],
    )..nextCancel = GuestVisitCancelOutcome.refused;
    await _pump(tester, fake);
    await tester.tap(find.byKey(const ValueKey('me-visit-cancel-v-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Could not cancel the visit'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('me-visit-status-confirmed')),
      findsOneWidget,
    );
  });
}
