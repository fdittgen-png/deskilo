// SPDX-License-Identifier: AGPL-3.0-or-later
// #2472: a new discussion starts from who I can write to. Before any search
// the messenger lists the people of each workspace I share with them, one
// collapsible section per workspace with its count, then my groups; typing
// suggests people and groups from the first letter, and a tap, or Enter on
// the highlighted suggestion, opens the conversation. Who is reachable is
// the server's answer (pgTAP 253); these tests own the screen's wiring.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/account_messenger_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _field = ValueKey('account-messenger-portal-find-people-2');
const _suggestions = ValueKey('recipient-suggestions');

Future<void> _show(
  WidgetTester tester, {
  required FakeAccountContactRepository contacts,
  required FakeMessengerRepository messenger,
  Size size = const Size(800, 2000),
}) async {
  await pumpApp(
    tester,
    const AccountMessengerScreen(),
    size: size,
    overrides: standardTestOverrides(
      auth: FakeAuthRepository.signedIn(),
      contacts: contacts,
      messenger: messenger,
    ),
  );
  await tester.pumpAndSettle();
}

ReachablePerson _p(String ws, String id, String name) => ReachablePerson(
  workspaceId: ws,
  workspaceName: ws == 'w1' ? 'Atelier' : 'Loft',
  id: id,
  name: name,
);

FakeAccountContactRepository _contacts() => FakeAccountContactRepository()
  ..reachable.addAll([
    _p('w1', 'a', 'Alice Martin'),
    _p('w1', 'b', 'Bob Marchand'),
    _p('w1', 'user-1', 'Me Myself'),
    _p('w2', 'a', 'Alice Martin'),
    _p('w2', 'e', 'Élodie Rami'),
  ]);

FakeMessengerRepository _withGroup() => FakeMessengerRepository()
  ..inboxRows.add({
    'context_kind': 'account_group',
    'context_id': 'g1',
    'title': 'Floor crew',
    'last_body': '',
    'last_at': '2026-07-15T09:00:00Z',
    'unread': 0,
    'member_count': 3,
  });

Iterable<String> _suggested(WidgetTester tester) => tester
    .widgetList<ListTile>(
      find.descendant(of: find.byKey(_suggestions), matching: find.byType(ListTile)),
    )
    .map((t) => (t.title! as Text).data!);

void main() {
  testWidgets('lists who I can write to by workspace, with counts, a person '
      'in two workspaces under both, never me, then my groups', (tester) async {
    await _show(tester, contacts: _contacts(), messenger: _withGroup());
    expect(find.byKey(const ValueKey('reachable-heading')), findsOneWidget);
    expect(find.text('Atelier (2)'), findsOneWidget);
    expect(find.text('Loft (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('reachable-person--w1-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('reachable-person--w2-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('reachable-person--w1-user-1')), findsNothing);
    expect(find.text('Groups (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('reachable-group-g1')), findsOneWidget);
    expect(find.text('AM'), findsNWidgets(2)); // initials, once per workspace

    // A section collapses.
    await tester.tap(find.text('Atelier (2)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reachable-person--w1-b')), findsNothing);
    expect(find.byKey(const ValueKey('reachable-person--w2-a')), findsOneWidget);
  });

  testWidgets('one letter suggests, prefix before contains, accents ignored, '
      'a shared person once with both workspaces', (tester) async {
    await _show(tester, contacts: _contacts(), messenger: _withGroup());
    await tester.enterText(find.byKey(_field), 'm');
    await tester.pump();
    // "Me Myself" is me and never suggested; Martin / Marchand are last
    // names (prefix of a word), Élodie Rami only contains an m.
    expect(_suggested(tester), ['Alice Martin', 'Bob Marchand', 'Élodie Rami']);
    expect(
      find.descendant(of: find.byKey(_suggestions), matching: find.text('Atelier, Loft')),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(_field), 'elo');
    await tester.pump();
    expect(_suggested(tester), ['Élodie Rami']);

    await tester.enterText(find.byKey(_field), 'fl');
    await tester.pump();
    expect(_suggested(tester), ['Floor crew']);
    expect(find.bySemanticsLabel(RegExp('Write to Floor crew')), findsOneWidget);
  });

  testWidgets('Down then Enter opens the highlighted person; Esc closes the '
      'list', (tester) async {
    final messenger = FakeMessengerRepository();
    await _show(tester, contacts: _contacts(), messenger: messenger);
    await tester.tap(find.byKey(_field));
    await tester.enterText(find.byKey(_field), 'mar');
    await tester.pump();
    expect(_suggested(tester), ['Alice Martin', 'Bob Marchand']);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(_suggestions), findsNothing);

    await tester.enterText(find.byKey(_field), 'mar ');
    await tester.enterText(find.byKey(_field), 'mar');
    await tester.pump();
    expect(find.byKey(_suggestions), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hi Bob');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(
      messenger
          .threads[FakeMessengerRepository.threadKey(MessageContextKind.account, 'b')]
          ?.single
          .body,
      'Hi Bob',
    );
  });

  testWidgets('a tap on a suggested group opens the group thread', (tester) async {
    await _show(tester, contacts: _contacts(), messenger: _withGroup());
    await tester.enterText(find.byKey(_field), 'crew');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recipient-suggestion-g::g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('reachable-groups-heading')), findsNothing);
    await tester.enterText(find.byKey(_field), 'a');
    await tester.pump();
    expect(find.byKey(_suggestions), findsNothing);
  });

  testWidgets('a server that cannot answer offers a retry, which recovers', (
    tester,
  ) async {
    final contacts = _contacts()..failReachable = true;
    await _show(tester, contacts: contacts, messenger: FakeMessengerRepository());
    expect(find.byKey(const ValueKey('reachable-retry-')), findsOneWidget);
    contacts.failReachable = false;
    await tester.tap(find.byKey(const ValueKey('reachable-retry-')));
    await tester.pumpAndSettle();
    expect(find.text('Atelier (2)'), findsOneWidget);
  });

  testWidgets('fits 360 px with the suggestions open', (tester) async {
    final contacts = FakeAccountContactRepository()
      ..reachable.add(
        _p('w1', 'x', 'Maximilian Alexander von Hohenzollern-Sigmaringen'),
      );
    await _show(
      tester,
      contacts: contacts,
      messenger: _withGroup(),
      size: const Size(360, 800),
    );
    await tester.enterText(find.byKey(_field), 'max');
    await tester.pump();
    expect(find.byKey(_suggestions), findsOneWidget);
    expect(tester.takeException(), isNull);
    final row = find.byKey(const ValueKey('recipient-suggestion-p::x'));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
  });
}
