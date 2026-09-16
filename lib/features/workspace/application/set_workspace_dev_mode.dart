// SPDX-License-Identifier: 0BSD
//
// #1307 — developer mode is a WORKSPACE setting, not a device one: an
// admin flips it and every member inherits the state (#419).
//
// It lives here rather than beside the Settings tile that calls it
// because ADR 0024 draws the line at the repository: `presentation/`
// says what was asked, `application/` decides which write that is, and
// `data/` performs it. The tile's job is the switch; deciding that
// flipping it means "write the workspace row, then invalidate the
// chain so every gate re-derives" is this file's.
//
// Without it the Advanced section — extracted out of a 1 312-line
// screen so Settings could be reorganized at all — would have been a
// widget in `profile/` reaching into `workspace/`'s repository, which
// is the exact coupling `layering_test` counts.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/workspace_providers.dart';

/// Turns developer mode on or off for the whole workspace.
///
/// Silently does nothing when no workspace is selected: the caller is a
/// switch that cannot be reached without one, and inventing an error
/// for an impossible state would be noise.
Future<void> setWorkspaceDevMode(WidgetRef ref, bool enabled) async {
  final ws = ref.read(currentWorkspaceProvider).value;
  if (ws == null) return;
  await ref.read(workspaceRepositoryProvider).setDevMode(ws.id, enabled);
  ref.invalidate(myWorkspacesProvider);
}
