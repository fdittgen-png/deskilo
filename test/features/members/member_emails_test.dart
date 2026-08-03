// SPDX-License-Identifier: 0BSD
//
// Member emails in the members lists (#410, migration 0078): an ADMIN
// surface. Admin/owner viewers see each member's email under the name
// in Members & plans and in the directory; plain members see neither —
// the server returns the empty set (mirrored by the fake), and contact
// info in the directory stays the opt-in WhatsApp channel.

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'directory_screen_test.dart' as directory;
import 'members_screen_test.dart' show pumpMembers;

void main() {
  test('fake mirrors the RPC gate: empty set for a plain member', () async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..memberEmails = {'member-1': 'flo@example.com'};
    expect(await repo.fetchMemberEmails('ws-1'), isNotEmpty);
    repo.myMember = repo.myMember.copyWith(isOwner: false, isAdmin: false);
    expect(await repo.fetchMemberEmails('ws-1'), isEmpty,
        reason: 'emails are an admin surface — 0078 returns [] otherwise');
  });

  testWidgets('Members & plans: the owner sees emails under the names',
      (tester) async {
    final workspace = await pumpMembers(tester);
    workspace.memberEmails = {
      'member-1': 'flo@example.com',
      'member-2': 'ana@example.com',
    };
    // Seeded after the pump on purpose — the provider fetched {} first;
    // prove a rebuild path exists by invalidating via fresh navigation.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Members & plans'));
    await tester.pumpAndSettle();

    expect(find.text('flo@example.com'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('directory: admin viewer sees the email line', (tester) async {
    final seeded = directory.seedDirectory();
    seeded.workspace
      ..myMember = seeded.workspace.myMember
          .copyWith(isAdmin: true, isOwner: false)
      ..memberEmails = {'member-2': 'anna@example.com'};
    await directory.pumpDirectory(tester, workspace: seeded.workspace);
    expect(find.text('anna@example.com'), findsOneWidget);
  });

  testWidgets('directory: a plain member sees NO emails', (tester) async {
    final seeded = directory.seedDirectory();
    // The canonical seed keeps me a plain member; emails seeded anyway —
    // the gate, not the data, must hide them.
    seeded.workspace.memberEmails = {'member-2': 'anna@example.com'};
    await directory.pumpDirectory(tester, workspace: seeded.workspace);
    expect(find.text('anna@example.com'), findsNothing);
  });
}
