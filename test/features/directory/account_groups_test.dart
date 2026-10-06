// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Groups of people (0384): they live in the Me inbox beside conversations,
// open as a thread with the same actions, carry references only to a
// workspace every member belongs to, and are run by their admins.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/account_group.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<({FakeMessengerRepository messenger, FakeAccountContactRepository contacts})>
    pump(
  WidgetTester tester, {
  bool admin = true,
  bool announceOnly = false,
  List<({String id, String name})> shared = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final messenger = FakeMessengerRepository()
    ..inboxRows.add({
      'context_kind': 'account_group',
      'context_id': 'g1',
      'title': 'Floor crew',
      'last_body': 'see you',
      'last_at': '2026-07-15T09:00:00Z',
      'unread': 1,
      'member_count': 3,
    })
    ..groups['g1'] = AccountGroupInfo(
      id: 'g1',
      title: 'Floor crew',
      memberCount: 3,
      iAmAdmin: admin,
      announceOnly: announceOnly,
    )
    ..groupRoster['g1'] = const [
      GroupMember(userId: 'me', name: 'Me', isAdmin: true),
      GroupMember(userId: 'ana', name: 'Ana'),
      GroupMember(userId: 'bob', name: 'Bob'),
    ]
    ..groupSharedIn['g1'] = shared;
  final contacts = FakeAccountContactRepository()
    ..people.addAll([
      {'id': 'cleo', 'name': 'Cleo'},
      {'id': 'dan', 'name': 'Dan'},
    ]);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: standardTestOverrides(messenger: messenger, contacts: contacts),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MeMessagesTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (messenger: messenger, contacts: contacts);
}

void main() {
  testWidgets('a group sits in the inbox with its glyph and opens as a '
      'thread that sends into the group', (tester) async {
    final r = await pump(tester);
    expect(find.byKey(const ValueKey('inbox-entry-g1')), findsOneWidget);
    expect(find.text('Floor crew'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
    expect(r.messenger.reads, contains('g1'));
    await tester.enterText(find.byKey(const ValueKey('member-note-body')), 'hello all');
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();
    expect(find.text('hello all'), findsOneWidget);
  });

  testWidgets('with no workspace shared by every member the attach menu is '
      'locked; with one it is open', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-attach-locked')), findsOneWidget);
  });

  testWidgets('an announcement-only group closes the composer to a plain '
      'member and keeps it for an admin', (tester) async {
    await pump(tester, admin: false, announceOnly: true);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('group-posting-closed')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-note-body')), findsNothing);
  });

  testWidgets('the group sheet: an admin renames, closes posting, promotes '
      'and removes; a member sees none of it', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-g1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agroup-info')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agroup-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('agroup-rename-field')), 'Crew 2');
    await tester.tap(find.byKey(const ValueKey('agroup-text-save')));
    await tester.pumpAndSettle();
    expect(r.messenger.groups['g1']?.title, 'Crew 2');
    await tester.tap(find.byKey(const ValueKey('agroup-announce-only')));
    await tester.pumpAndSettle();
    expect(r.messenger.groups['g1']?.announceOnly, isTrue);
    await tester.tap(find.byKey(const ValueKey('agroup-admin-ana')));
    await tester.pumpAndSettle();
    expect(r.messenger.groupLog, contains('admin:ana:true'));
    await tester.tap(find.byKey(const ValueKey('agroup-remove-bob')));
    await tester.pumpAndSettle();
    expect(r.messenger.groupLog, contains('remove:bob'));
  });

  testWidgets('a plain member cannot run the group', (tester) async {
    await pump(tester, admin: false);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-g1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agroup-info')));
    await tester.pumpAndSettle();
    for (final k in [
      'agroup-rename',
      'agroup-announce-only',
      'agroup-add-people',
      'agroup-admin-ana',
      'agroup-remove-ana',
    ]) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    expect(find.byKey(const ValueKey('agroup-leave')), findsOneWidget);
  });

  testWidgets('a new group needs a name and people; the people come from the '
      'search', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('unified-inbox-new-group')));
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('create-group-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('create-group-name')), 'Lunch club');
    await tester.enterText(find.byKey(const ValueKey('create-group-search')), 'Cleo');
    await tester.tap(find.byKey(const ValueKey('create-group-go')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-group-person-cleo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-group-chip-cleo')), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(r.messenger.groupLog, contains('create:Lunch club'));
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
  });
}
