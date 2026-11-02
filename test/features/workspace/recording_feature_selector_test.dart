// SPDX-License-Identifier: AGPL-3.0-or-later
// The privacy switch affects all identity reads, unrelated flags do not.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _flags = StateProvider<Set<WorkspaceFeature>>((ref) => {});
final _workspaceId = StateProvider<String>((ref) => 'a');
final _actor = StateProvider<String>((ref) => 'one');
final _server = StateProvider<String>((ref) => 'first');

class _Reads extends FakeWorkspaceRepository {
  _Reads(this.tag);
  final String tag;
  int mine = 0, members = 0, identity = 0;
  Member member(String workspaceId) => Member(
    id: 'm',
    workspaceId: workspaceId,
    userId: tag,
    isAdmin: false,
    isOwner: false,
    status: MemberStatus.active,
    managedName: 'Real $tag',
    managedIdentity: PersonalInfo(firstName: 'Real', lastName: tag),
  );
  @override
  Future<Member?> fetchMyMember(String workspaceId) async {
    mine++;
    return member(workspaceId);
  }

  @override
  Future<List<Member>> fetchMembers(String workspaceId) async {
    members++;
    return [member(workspaceId)];
  }

  @override
  Future<PersonalInfo> managedIdentityOf(String memberId) async {
    identity++;
    return PersonalInfo(firstName: 'Real', lastName: tag);
  }
}

void main() {
  test(
    'unrelated flags do not refetch and privacy changes all three surfaces',
    () async {
      final reads = _Reads('one');
      final container = ProviderContainer(
        overrides: [
          workspaceRepositoryProvider.overrideWith((ref) => reads),
          currentWorkspaceProvider.overrideWith(
            (ref) async => const Workspace(
              id: 'a',
              name: 'A',
              countryCode: 'FR',
              currencyCode: 'EUR',
              timezone: 'UTC',
              inviteCode: '',
            ),
          ),
          enabledFeaturesSyncProvider.overrideWith((ref) => ref.watch(_flags)),
        ],
      );
      addTearDown(container.dispose);
      final subscriptions = [
        container.listen(myMemberProvider, (_, _) {}),
        container.listen(workspaceMembersProvider, (_, _) {}),
        container.listen(managedIdentityProvider('m'), (_, _) {}),
      ];
      addTearDown(() {
        for (final sub in subscriptions) {
          sub.close();
        }
      });
      Future<(Member, Member, PersonalInfo)> snapshot() async => (
        (await container.read(myMemberProvider.future))!,
        (await container.read(workspaceMembersProvider.future)).single,
        (await container.read(managedIdentityProvider('m').future)).identity,
      );
      final first = await snapshot();
      expect(
        (first.$1.managedName, first.$2.managedName, first.$3.firstName),
        ('Real one', 'Real one', 'Real'),
      );
      expect((reads.mine, reads.members, reads.identity), (1, 1, 1));
      container.read(_flags.notifier).state = {WorkspaceFeature.calendarTab};
      await container.pump();
      await snapshot();
      expect((reads.mine, reads.members, reads.identity), (1, 1, 1));
      container.read(_flags.notifier).state = {
        WorkspaceFeature.calendarTab,
        WorkspaceFeature.recordingPrivacy,
      };
      await container.pump();
      final filming = await snapshot();
      expect(filming.$1.managedName, isNot('Real one'));
      expect(filming.$2.managedName, isNot('Real one'));
      expect(filming.$3.firstName, isNot('Real'));
      expect((reads.mine, reads.members, reads.identity), (2, 2, 2));
      container.read(_flags.notifier).state = {
        WorkspaceFeature.recordingPrivacy,
      };
      await container.pump();
      await snapshot();
      expect((reads.mine, reads.members, reads.identity), (2, 2, 2));
      container.read(_flags.notifier).state = {WorkspaceFeature.calendarTab};
      await container.pump();
      final restored = await snapshot();
      expect(
        (
          restored.$1.managedName,
          restored.$2.managedName,
          restored.$3.firstName,
        ),
        ('Real one', 'Real one', 'Real'),
      );
      expect((reads.mine, reads.members, reads.identity), (3, 3, 3));
    },
  );

  test('workspace, actor and repository changes refresh even with same privacy flag', () async {
    final repos = <String, _Reads>{};
    final container = ProviderContainer(
      overrides: [
        currentWorkspaceProvider.overrideWith(
          (ref) async => Workspace(
            id: ref.watch(_workspaceId),
            name: 'Space',
            countryCode: 'FR',
            currencyCode: 'EUR',
            timezone: 'UTC',
            inviteCode: '',
          ),
        ),
        workspaceRepositoryProvider.overrideWith((ref) {
          final key =
              '${ref.watch(_workspaceId)}:${ref.watch(_actor)}:${ref.watch(_server)}';
          return repos.putIfAbsent(key, () => _Reads(key));
        }),
        enabledFeaturesSyncProvider.overrideWith((ref) => ref.watch(_flags)),
      ],
    );
    addTearDown(container.dispose);
    final subscriptions = [
      container.listen(myMemberProvider, (_, _) {}),
      container.listen(workspaceMembersProvider, (_, _) {}),
      container.listen(managedIdentityProvider('m'), (_, _) {}),
    ];
    addTearDown(() {
      for (final sub in subscriptions) {
        sub.close();
      }
    });
    Future<void> expectContext(String key, String workspace) async {
      final mine = (await container.read(myMemberProvider.future))!;
      final members = await container.read(workspaceMembersProvider.future);
      final identity = await container.read(
        managedIdentityProvider('m').future,
      );
      expect((mine.workspaceId, mine.userId), (workspace, key));
      expect(
        (members.single.workspaceId, members.single.userId),
        (workspace, key),
      );
      expect(identity.identity.lastName, key);
      expect(
        (repos[key]!.mine, repos[key]!.members, repos[key]!.identity),
        (1, 1, 1),
      );
    }

    await expectContext('a:one:first', 'a');
    container.read(_workspaceId.notifier).state = 'b';
    await container.pump();
    await expectContext('b:one:first', 'b');
    container.read(_actor.notifier).state = 'two';
    await container.pump();
    await expectContext('b:two:first', 'b');
    container.read(_server.notifier).state = 'second';
    await container.pump();
    await expectContext('b:two:second', 'b');
  });
}
