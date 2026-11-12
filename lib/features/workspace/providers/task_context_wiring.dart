// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../core/session/session_source.dart';
import '../../../core/session/task_context.dart';
import 'active_workspace_providers.dart';

/// #3608 — the context an open task belongs to: the signed-in person and
/// the active workspace. A change of either closes the task, unasked
/// (core/ui/adaptive/task_surface.dart); the composition root and the Demo
/// put it in their scopes' overrides.
final taskContextFromWorkspace = taskContextTokenProvider.overrideWith(
  (ref) =>
      '${ref.watch(sessionStateProvider).value ?? ''}'
      '|${ref.watch(activeWorkspaceIdProvider).value ?? ''}',
);
