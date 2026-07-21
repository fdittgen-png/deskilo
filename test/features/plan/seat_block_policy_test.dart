// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/plan/domain/seat_block_policy.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

Member member({
  bool isOwner = false,
  bool isAdmin = false,
  MemberStatus status = MemberStatus.active,
}) =>
    Member(
      id: 'member-1',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: isAdmin,
      isOwner: isOwner,
      status: status,
    );

void main() {
  group('canManageSeatBlocks (#161)', () {
    test('the owner may, with or without the feature', () {
      expect(
        canManageSeatBlocks(
          member: member(isOwner: true),
          features: const {},
        ),
        isTrue,
      );
      expect(
        canManageSeatBlocks(
          member: member(isOwner: true),
          features: const {WorkspaceFeature.adminSeatBlocking},
        ),
        isTrue,
      );
    });

    test('an admin may only when the owner enabled the feature', () {
      expect(
        canManageSeatBlocks(
          member: member(isAdmin: true),
          features: const {},
        ),
        isFalse,
      );
      expect(
        canManageSeatBlocks(
          member: member(isAdmin: true),
          features: const {WorkspaceFeature.adminSeatBlocking},
        ),
        isTrue,
      );
    });

    test('a worker never may, even with the feature on', () {
      expect(
        canManageSeatBlocks(
          member: member(),
          features: const {WorkspaceFeature.adminSeatBlocking},
        ),
        isFalse,
      );
    });

    test('inactive members and missing membership never may', () {
      expect(
        canManageSeatBlocks(
          member: member(isOwner: true, status: MemberStatus.paused),
          features: const {WorkspaceFeature.adminSeatBlocking},
        ),
        isFalse,
      );
      expect(
        canManageSeatBlocks(
          member: member(isAdmin: true, status: MemberStatus.exited),
          features: const {WorkspaceFeature.adminSeatBlocking},
        ),
        isFalse,
      );
      expect(
        canManageSeatBlocks(
          member: null,
          features: const {WorkspaceFeature.adminSeatBlocking},
        ),
        isFalse,
      );
    });
  });
}
