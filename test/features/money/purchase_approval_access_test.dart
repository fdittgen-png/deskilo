// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: observed membership, permission, workspace and feature changes fail closed.
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _permission = StateProvider<bool>((ref) => true);
final _feature = StateProvider<bool>((ref) => true);
final _active = StateProvider<bool>((ref) => true);

void main() {
  test(
    'approval access follows actual workspace, role, feature and member state',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentWorkspaceProvider.overrideWith(
            (ref) async => const Workspace(
              id: 'ws',
              name: 'Space',
              countryCode: 'FR',
              currencyCode: 'EUR',
              timezone: 'UTC',
              inviteCode: '',
            ),
          ),
          myMemberProvider.overrideWith(
            (ref) async => Member(
              id: 'm',
              workspaceId: 'ws',
              userId: 'u',
              isAdmin: false,
              isOwner: false,
              status: ref.watch(_active)
                  ? MemberStatus.active
                  : MemberStatus.paused,
            ),
          ),
          myPermissionsProvider.overrideWith(
            (ref) => ref.watch(_permission)
                ? {WorkspacePermission.approveExpenses}
                : {},
          ),
          enabledFeaturesSyncProvider.overrideWith(
            (ref) => ref.watch(_feature) ? {WorkspaceFeature.purchases} : {},
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentWorkspaceProvider.future);
      await container.read(myMemberProvider.future);
      expect(container.read(purchaseApprovalAccessProvider('ws')), isTrue);
      expect(container.read(purchaseApprovalAccessProvider('other')), isFalse);
      container.read(_permission.notifier).state = false;
      expect(container.read(purchaseApprovalAccessProvider('ws')), isFalse);
      container.read(_permission.notifier).state = true;
      container.read(_feature.notifier).state = false;
      expect(container.read(purchaseApprovalAccessProvider('ws')), isFalse);
      container.read(_feature.notifier).state = true;
      container.read(_active.notifier).state = false;
      await container.read(myMemberProvider.future);
      expect(container.read(purchaseApprovalAccessProvider('ws')), isFalse);
    },
  );
}
