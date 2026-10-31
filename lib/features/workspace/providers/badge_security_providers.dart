// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/workspace_feature.dart';
import '../domain/workspace_permission.dart';
import 'workspace_providers.dart';

part 'badge_security_providers.g.dart';

/// Only badge administrators inspect PIN review status on the active host.
@riverpod
Future<bool> badgePinReview(
  Ref ref,
  String workspaceId,
  String memberId,
) async {
  final repository = ref.watch(workspaceRepositoryProvider);
  final activeId = ref.watch(
    currentWorkspaceProvider.select((v) => v.value?.id),
  );
  final permitted = ref.watch(
    myPermissionsProvider.select(
      (permissions) => permissions.contains(WorkspacePermission.operateKiosk),
    ),
  );
  final enabled = ref.watch(
    enabledFeaturesSyncProvider.select(
      (features) => features.contains(WorkspaceFeature.badgeSignIn),
    ),
  );
  if (activeId != workspaceId || !permitted || !enabled) return false;
  return repository.badgePinNeedsReview(workspaceId, memberId);
}
