// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — a notice belongs to the context it was raised in: when the person
// changes business, account or persona, the visible snack and the queued
// ones go, so a message (or its action) of the old context never shows in
// the new one. Only a change from one known context to another counts, not
// the first read. No timeout is touched.
import 'package:flutter/material.dart' show ScaffoldMessenger;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_session.dart';
import '../../core/session/session_source.dart';
import '../../features/workspace/providers/workspace_providers.dart';

/// Starts the listeners; called from the shell's build.
void watchSnackScope(WidgetRef ref) {
  void clear<T>(T? before, T? after) {
    if (before == null || after == null || before == after) return;
    if (!ref.context.mounted) return;
    ScaffoldMessenger.maybeOf(ref.context)?.clearSnackBars();
  }

  ref
    ..listen(activeWorkspaceIdProvider, (p, n) => clear(p?.value, n.value))
    ..listen(sessionStateProvider, (p, n) => clear(p?.value, n.value))
    ..listen(
      demoSessionControllerProvider.select((d) => d.scopeKey),
      clear<String>,
    );
}
