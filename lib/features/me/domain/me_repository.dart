// SPDX-License-Identifier: AGPL-3.0-or-later
import 'my_spaces.dart';
import 'visibility.dart';

/// #1823 — the account layer's own calls. Every one is about the signed-in
/// person; none reads or writes inside a workspace beyond leaving it.
abstract interface class MeRepository {
  /// `leave_workspace` (0001): my membership becomes `exited`. My data
  /// stays; erasing it is the separate, stronger action in Privacy.
  Future<void> leaveSpace(String workspaceId);

  /// `my_visibility()`.
  Future<MyVisibility> myVisibility();

  /// `set_visibility(field, audience, workspaces)`.
  Future<void> setVisibility(VisibilityField field, FieldAudience audience);

  /// `preview_my_account(as)`: what that audience would see of me.
  Future<AccountView> previewMyAccount(PreviewAudience audience);

  /// `visible_account(user)`: what I may see of another account.
  Future<AccountView> visibleAccount(String userId);

  /// My spaces on the linked server [source], read with that server's
  /// own session.
  Future<List<LinkedSpace>> spacesOn(String source);
}
