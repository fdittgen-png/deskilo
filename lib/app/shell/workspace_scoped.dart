// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the seam of the identity split (#2413). Whatever a long-lived
// part of the app creates for the active workspace implements this, so the
// owner of the session can tell it that the workspace changed and that it
// is going away; a PersonalContext / WorkspaceContext pair can implement it
// later without the shell knowing. This file invents no context class.

/// Something that holds state created for the active workspace.
abstract interface class WorkspaceScoped {
  /// The active workspace is now [workspaceId] (null: none). Release what
  /// was created for the previous one.
  void onWorkspaceChanged(String? workspaceId);

  /// The owner is going away; release everything.
  void dispose();
}
