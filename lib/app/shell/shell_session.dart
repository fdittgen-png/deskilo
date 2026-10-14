// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the one owner of what the shell creates for a session: the ids of
// the member notes already announced. It used to be a top-level set that
// lived until the process died and was never emptied; now it is created
// with the shell, emptied when the active workspace changes and when the
// shell goes (test/app/shell/shell_session_test.dart proves both).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workspace/providers/workspace_providers.dart';
import 'workspace_scoped.dart';

/// Note ids already announced THIS SESSION — belt to the persisted
/// NOTIFIED stamp's braces: two racing provider refreshes must not
/// announce the same note twice before the stamp lands.
class ShellSession implements WorkspaceScoped {
  final Set<String> notifiedNoteIds = <String>{};

  @override
  void onWorkspaceChanged(String? workspaceId) => notifiedNoteIds.clear();

  @override
  void dispose() => notifiedNoteIds.clear();
}

/// The shell's session, alive while the shell is watched.
final shellSessionProvider = Provider.autoDispose<ShellSession>((ref) {
  final session = ShellSession();
  ref
    ..listen(
      activeWorkspaceIdProvider,
      (_, next) => session.onWorkspaceChanged(next.value),
    )
    ..onDispose(session.dispose);
  return session;
});
