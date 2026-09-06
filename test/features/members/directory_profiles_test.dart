// SPDX-License-Identifier: 0BSD
//
// #962 — the directory asks for the profiles of members WITH an account.
// A managed member's user id is the empty string; sent along, PostgREST
// refused the whole request (`invalid input syntax for type uuid: ""`)
// and the directory lost every status and WhatsApp button.
import 'package:deskilo/features/members/providers/directory_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';

const _managed = Member(
  id: 'member-managed',
  workspaceId: 'ws-1',
  userId: '',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

void main() {
  test('accountIdsOf leaves the managed member out', () {
    const withAccount = Member(
      id: 'member-2',
      workspaceId: 'ws-1',
      userId: 'user-2',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    );
    expect(accountIdsOf(const [withAccount, _managed]), ['user-2']);
    expect(accountIdsOf(const [_managed]), isEmpty);
  });

  test('memberProfiles never requests an empty id', () async {
    final profile = FakeProfileRepository();
    const withAccount = Member(
      id: 'member-1',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: true,
      isOwner: true,
      status: MemberStatus.active,
    );
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(profile: profile),
        workspaceMembersProvider
            .overrideWith((ref) async => const [withAccount, _managed]),
      ],
    );
    addTearDown(container.dispose);

    final profiles = await container.read(memberProfilesProvider.future);

    expect(profile.requestedIds, [
      ['user-1']
    ], reason: 'the managed member is not asked for');
    expect(profiles.keys, isNot(contains('')));
  });
}
