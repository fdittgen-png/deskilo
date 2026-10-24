// SPDX-License-Identifier: AGPL-3.0-or-later
// #2472 (P): the new discussion reads its directory at the personal home.
// Before any search it lists my workspaces (a remote one by a neutral
// label), the people of each with Show more, a hidden name as "Person",
// and my groups; a lapsed source says so instead of reading as nobody; a
// refusal offers a retry that recovers; only a home without the reader
// keeps the per-server directory. Who is listed is pgTAP 274's.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/domain/personal_message_directory.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/account_messenger_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _local = 'cccccccc-0000-4000-8000-000000000001:00000000-0000-4000-8000-0000000000f1';
const _remote = 'aaaaaaaa-0000-4000-8000-000000000001:00000000-0000-4000-8000-0000000000f1';
const _field = ValueKey('account-messenger-portal-find-people-2');

/// The personal home, page by page, as the reader answers.
class _Home implements PersonalMessageDirectoryRepository {
  DirectoryRefused? refusal;
  RelationshipStatus status = RelationshipStatus.ready;
  RelationshipStatus remoteStatus = RelationshipStatus.ready;
  final calls = <String>[];

  void _check() {
    final r = refusal;
    if (r != null) throw r;
  }

  @override
  Future<DirectoryPage<DirectoryWorkspace>> workspaces({String? after}) async {
    _check();
    return DirectoryPage(
      items: const [
        DirectoryWorkspace(networkId: _local, name: 'Atelier'),
        DirectoryWorkspace(networkId: _remote),
      ],
      status: status,
    );
  }

  @override
  Future<DirectoryPage<DirectoryPerson>> people(
    String networkId, {
    String? after,
    String query = '',
  }) async {
    _check();
    calls.add('$networkId/${after ?? ''}');
    if (networkId == _remote) {
      return DirectoryPage(
        items: remoteStatus == RelationshipStatus.ready
            ? const [DirectoryPerson(id: 'p9', workspaceRef: _remote)]
            : const [],
        status: remoteStatus,
      );
    }
    return after == null
        ? const DirectoryPage(
            items: [
              DirectoryPerson(id: 'p1', workspaceRef: _local, name: 'Ada Lovelace'),
              DirectoryPerson(id: 'p2', workspaceRef: _local, name: 'Bruno Ricci'),
            ],
            status: RelationshipStatus.ready,
            nextKey: 'p2',
          )
        : const DirectoryPage(
            items: [
              DirectoryPerson(id: 'p3', workspaceRef: _local, name: 'Chiara Neri'),
            ],
            status: RelationshipStatus.ready,
          );
  }

  @override
  Future<DirectoryPage<DirectoryGroup>> groups({String? after}) async {
    _check();
    return const DirectoryPage(
      items: [
        DirectoryGroup(id: 'g1', title: 'Floor crew', announceOnly: false, canWrite: true),
        DirectoryGroup(id: 'g2', title: 'Notices', announceOnly: true, canWrite: false),
      ],
      status: RelationshipStatus.ready,
    );
  }
}

Future<void> _show(
  WidgetTester tester,
  PersonalMessageDirectoryRepository home, {
  FakeAccountContactRepository? contacts,
  FakeMessengerRepository? messenger,
}) async {
  await pumpApp(
    tester,
    const AccountMessengerScreen(),
    size: const Size(800, 2400),
    overrides: standardTestOverrides(
      auth: FakeAuthRepository.signedIn(),
      personalDirectory: home,
      contacts: contacts,
      messenger: messenger,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('before any search: my workspaces with their people, a remote '
      'one by a neutral label, a hidden name as Person, then my groups', (
    tester,
  ) async {
    await _show(tester, _Home());
    expect(find.text('Atelier (2)'), findsOneWidget);
    expect(find.text('A workspace on another server (1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reachable-person-p-$_remote-p9')),
      findsOneWidget,
    );
    expect(find.text('Person'), findsOneWidget);
    expect(find.text('Groups (2)'), findsOneWidget);
    expect(find.text('Only admins can post'), findsOneWidget);
    expect(find.byKey(const ValueKey('reachable-partial')), findsNothing);
    // The per-server directory is not asked.
    expect(find.byKey(const ValueKey('reachable-')), findsNothing);
  });

  testWidgets('Show more appends the next page of one workspace', (tester) async {
    final home = _Home();
    await _show(tester, home);
    expect(find.text('Chiara Neri'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reachable-more-$_local')));
    await tester.pumpAndSettle();
    expect(home.calls, contains('$_local/p2'));
    expect(find.text('Chiara Neri'), findsOneWidget);
    expect(find.text('Atelier (3)'), findsOneWidget);
    expect(find.byKey(const ValueKey('reachable-more-$_local')), findsNothing);
  });

  testWidgets('a lapsed source is said, never read as nobody', (tester) async {
    await _show(
      tester,
      _Home()
        ..status = RelationshipStatus.partial
        ..remoteStatus = RelationshipStatus.unavailable,
    );
    expect(find.byKey(const ValueKey('reachable-partial')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reachable-unverified-$_remote')),
      findsOneWidget,
    );
    expect(find.text('A workspace on another server (0)'), findsOneWidget);
  });

  testWidgets('a refusal offers a retry, which recovers', (tester) async {
    final home = _Home()
      ..refusal = const DirectoryRefused(DirectoryFailure.forbidden);
    await _show(tester, home);
    expect(find.byKey(const ValueKey('reachable-retry-personal')), findsOneWidget);
    expect(find.text('Atelier (2)'), findsNothing);
    home.refusal = null;
    await tester.tap(find.byKey(const ValueKey('reachable-retry-personal')));
    await tester.pumpAndSettle();
    expect(find.text('Atelier (2)'), findsOneWidget);
  });

  testWidgets('a home without the reader keeps the per-server directory', (
    tester,
  ) async {
    final contacts = FakeAccountContactRepository()
      ..reachable.add(
        const ReachablePerson(
          workspaceId: 'w1',
          workspaceName: 'Loft',
          id: 'a',
          name: 'Alice Martin',
        ),
      );
    await _show(
      tester,
      _Home()..refusal = const DirectoryRefused(DirectoryFailure.unsupported),
      contacts: contacts,
    );
    expect(find.byKey(const ValueKey('reachable-person--w1-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('reachable-retry-personal')), findsNothing);
  });

  testWidgets('one letter suggests from the home\'s directory; a pick opens '
      'the conversation with the home\'s account', (tester) async {
    final messenger = FakeMessengerRepository();
    await _show(tester, _Home(), messenger: messenger);
    await tester.enterText(find.byKey(_field), 'b');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('recipient-suggestion-p::p2')),
      findsOneWidget,
    );
    // A hidden name is never suggested.
    await tester.enterText(find.byKey(_field), 'p');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('recipient-suggestion-p::p9')),
      findsNothing,
    );
    await tester.enterText(find.byKey(_field), 'bru');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recipient-suggestion-p::p2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hi Bruno');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(
      messenger
          .threads[FakeMessengerRepository.threadKey(MessageContextKind.account, 'p2')]
          ?.single
          .body,
      'Hi Bruno',
    );
  });

  testWidgets('a group without a message opens its thread', (tester) async {
    await _show(tester, _Home());
    await tester.tap(find.byKey(const ValueKey('reachable-group-g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
  });
}
