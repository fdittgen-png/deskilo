// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Running a workspace group (0383): rename, description, announcement-only,
// admin roles — offered to admins, hidden from members.
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/presentation/widgets/group_info_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

final _group = Conversation(
  id: 'g1',
  kind: ConversationKind.group,
  title: 'Floor 2',
  lastAt: DateTime.utc(2026, 8, 27),
);

Future<({FakeWorkspaceRepository workspace, FakeMessengerRepository messenger})>
    open(WidgetTester tester, {required bool admin}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..conversations.add(_group)
    ..participants['g1'] = [
      ConversationParticipant(memberId: 'member-1', isAdmin: admin),
      const ConversationParticipant(memberId: 'member-2', isAdmin: false),
    ];
  final messenger = FakeMessengerRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace, messenger: messenger),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-group'),
              onPressed: () =>
                  showGroupInfoSheet(context, ref, conversation: _group),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-group')));
  await tester.pumpAndSettle();
  return (workspace: workspace, messenger: messenger);
}

void main() {
  testWidgets('an admin renames the group, writes its description, closes '
      'posting and promotes someone', (tester) async {
    final r = await open(tester, admin: true);

    await tester.tap(find.byKey(const ValueKey('group-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('group-rename-field')), 'Floor 2 crew');
    await tester.tap(find.byKey(const ValueKey('group-text-save')));
    await tester.pumpAndSettle();
    expect(r.workspace.metaWrites.single.title, 'Floor 2 crew');

    await tester.tap(find.byKey(const ValueKey('group-description')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('group-description-field')), 'Heating and keys');
    await tester.tap(find.byKey(const ValueKey('group-text-save')));
    await tester.pumpAndSettle();
    expect(r.messenger.details['g1']?.description, 'Heating and keys');

    await tester.tap(find.byKey(const ValueKey('group-announce-only')));
    await tester.pumpAndSettle();
    expect(r.messenger.details['g1']?.announceOnly, isTrue);
    // the description written a moment ago was kept
    expect(r.messenger.details['g1']?.description, 'Heating and keys');

    await tester.tap(find.byKey(const ValueKey('group-admin-member-2')));
    await tester.pumpAndSettle();
    expect(r.messenger.adminChanges.single,
        (conversation: 'g1', member: 'member-2', admin: true));
  });

  testWidgets('a plain member sees none of the admin controls',
      (tester) async {
    await open(tester, admin: false);
    for (final key in [
      'group-rename',
      'group-announce-only',
      'group-add-people',
      'group-admin-member-2',
      'group-remove-member-2',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }
  });
}
