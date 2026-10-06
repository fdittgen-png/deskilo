// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#2211): a first message held as a request is listed with its
// words and sender, Accept and Ignore answer it on the server and the card
// follows; with no request the card takes no room.
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/presentation/messenger/message_requests_card.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeMessengerRepository messenger,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(messenger: messenger),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: MessageRequestsCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no request, no card', (tester) async {
    await _pump(tester, FakeMessengerRepository());
    expect(find.byKey(const ValueKey('message-requests')), findsNothing);
  });

  testWidgets('a request is listed and Accept answers it', (tester) async {
    final messenger = FakeMessengerRepository()
      ..requests.add(
        const MessageRequest(
          conversationId: 'c1',
          userId: 'u1',
          name: 'Ana',
          body: 'Hello there',
        ),
      );
    await _pump(tester, messenger);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('request-accept-c1')));
    await tester.pumpAndSettle();
    expect(messenger.requestLog, ['c1:accept']);
    expect(find.byKey(const ValueKey('message-requests')), findsNothing);
  });

  testWidgets('Ignore answers without accepting', (tester) async {
    final messenger = FakeMessengerRepository()
      ..requests.add(
        const MessageRequest(
          conversationId: 'c2',
          userId: 'u2',
          name: 'Ben',
          body: 'Hi',
        ),
      );
    await _pump(tester, messenger);
    await tester.tap(find.byKey(const ValueKey('request-ignore-c2')));
    await tester.pumpAndSettle();
    expect(messenger.requestLog, ['c2:ignore']);
  });

  testWidgets('Block confirms, blocks and ignores the request', (tester) async {
    final messenger = FakeMessengerRepository()
      ..requests.add(
        const MessageRequest(
          conversationId: 'c3',
          userId: 'u3',
          name: 'Cy',
          body: 'Buy now',
        ),
      );
    await _pump(tester, messenger);
    await tester.tap(find.byKey(const ValueKey('request-block-c3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-block-confirm')));
    await tester.pumpAndSettle();
    expect(messenger.blocked.keys, ['u3']);
    expect(messenger.requestLog, ['c3:ignore']);
  });

  test('the server refusal for a second message is understood', () {
    expect(
      MessengerRefusal.of('request pending'),
      MessengerRefusal.requestPending,
    );
  });
}
