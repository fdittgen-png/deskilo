// SPDX-License-Identifier: AGPL-3.0-or-later
//
// How a newly joining member starts (their subscription level and what
// happens once their entitlement is used up), written as the one keyed
// billing rule the server merges. The setup guide's new-members step saves
// through this class; the workspace settings screen sends the same rule
// inside its whole-form save.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/membership_repository.dart';
import '../domain/new_member_defaults.dart';
import '../providers/workspace_providers.dart';

part 'save_new_member_defaults.g.dart';

class SaveNewMemberDefaults {
  const SaveNewMemberDefaults(this._members);
  final MembershipRepository _members;

  /// Stores [defaults] for [workspaceId]. Only members who join afterwards
  /// start with them. Throws whatever the repository throws.
  Future<void> save(String workspaceId, NewMemberDefaults defaults) =>
      _members.setNewMemberDefaults(workspaceId, defaults);
}

/// The new-member defaults' write.
@riverpod
SaveNewMemberDefaults saveNewMemberDefaults(Ref ref) =>
    SaveNewMemberDefaults(ref.watch(workspaceRepositoryProvider));
