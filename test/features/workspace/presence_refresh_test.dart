// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3123 (PERF-5) — presence is no longer pushed on every heartbeat (the
// heartbeat writes the unpublished presence table), so the directory's
// profiles refresh themselves once per heartbeat interval while they are
// on screen, and not in between. Counted on the demo profile repository.
import 'package:deskilo/core/demo/data/profile_repository.dart';
import 'package:deskilo/core/presence/presence_rules.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _member = Member(
  id: 'member-1',
  workspaceId: 'ws-a',
  userId: 'user-1',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

class _Counting extends FakeProfileRepository {
  int reads = 0;
  @override
  Future<List<Profile>> fetchProfiles(
    String workspaceId,
    List<String> userIds,
  ) {
    reads++;
    return super.fetchProfiles(workspaceId, userIds);
  }
}

void main() {
  testWidgets('one refresh per heartbeat interval, none in between', (
    tester,
  ) async {
    final repo = _Counting();
    final c = ProviderContainer(
      overrides: [
        memberProfileRepositoryProvider.overrideWithValue(repo),
        workspaceMembersProvider.overrideWith((ref) async => const [_member]),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(memberProfilesProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pump();
    await tester.pump();
    expect(repo.reads, 1);
    await tester.pump(PresenceRules.heartbeatInterval ~/ 2);
    expect(repo.reads, 1);
    await tester.pump(PresenceRules.heartbeatInterval ~/ 2);
    await tester.pump();
    expect(repo.reads, 2);
    // Leaving the screen cancels the next refresh.
    sub.close();
    c.dispose();
  });
}
