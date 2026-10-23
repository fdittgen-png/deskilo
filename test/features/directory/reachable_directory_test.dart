// SPDX-License-Identifier: AGPL-3.0-or-later
// #2472: a new discussion starts from who I can write to. Before any search
// the messenger lists the people of each workspace I share with them, then
// my groups; typing narrows both from the first character, and a tap opens
// the conversation with that person or group. Who is reachable is the
// server's answer (pgTAP 253); these tests own the screen's wiring.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/account_messenger_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<void> _show(
  WidgetTester tester, {
  required FakeAccountContactRepository contacts,
  required FakeMessengerRepository messenger,
}) async {
  await pumpApp(
    tester,
    const AccountMessengerScreen(),
    size: const Size(800, 2000),
    overrides: standardTestOverrides(
      auth: FakeAuthRepository.signedIn(),
      contacts: contacts,
      messenger: messenger,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists who I can write to by workspace before any search, '
      'narrows as I type, and opens the conversation', (tester) async {
    final contacts = FakeAccountContactRepository()
      ..reachable.addAll([
        const ReachablePerson(
          workspaceId: 'w1',
          workspaceName: 'Atelier',
          id: 'a',
          name: 'Alice',
        ),
        const ReachablePerson(
          workspaceId: 'w1',
          workspaceName: 'Atelier',
          id: 'b',
          name: 'Bob',
        ),
        const ReachablePerson(
          workspaceId: 'w2',
          workspaceName: 'Loft',
          id: 'a',
          name: 'Alice',
        ),
      ]);
    final messenger = FakeMessengerRepository();
    await _show(tester, contacts: contacts, messenger: messenger);
    expect(find.byKey(const ValueKey('reachable-heading')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reachable-workspace--Atelier')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reachable-workspace--Loft')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reachable-person--w1-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reachable-person--w2-a')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'bo');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('reachable-person--w1-b')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reachable-person--w1-a')), findsNothing);
    expect(
      find.byKey(const ValueKey('reachable-workspace--Loft')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('reachable-person--w1-b')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hi Bob');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(
      messenger
          .threads[FakeMessengerRepository.threadKey(
            MessageContextKind.account,
            'b',
          )]
          ?.single
          .body,
      'Hi Bob',
    );
  });

  testWidgets('with no reachable person the directory says how to find some', (
    tester,
  ) async {
    await _show(
      tester,
      contacts: FakeAccountContactRepository(),
      messenger: FakeMessengerRepository(),
    );
    expect(find.byKey(const ValueKey('reachable-empty-')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reachable-groups-heading')),
      findsNothing,
    );
  });

  testWidgets('my groups follow the people, narrow as I type, and open the '
      'group thread', (tester) async {
    final messenger = FakeMessengerRepository()
      ..inboxRows.add({
        'context_kind': 'account_group',
        'context_id': 'g1',
        'title': 'Floor crew',
        'last_body': 'see you',
        'last_at': '2026-07-15T09:00:00Z',
        'unread': 0,
        'member_count': 3,
      });
    await _show(
      tester,
      contacts: FakeAccountContactRepository(),
      messenger: messenger,
    );
    expect(
      find.byKey(const ValueKey('reachable-groups-heading')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reachable-group-g1')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump();
    expect(find.byKey(const ValueKey('reachable-group-g1')), findsNothing);

    await tester.enterText(find.byType(TextField), 'floor');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reachable-group-g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
  });
}
