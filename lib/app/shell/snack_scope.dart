// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — a notice belongs to the context it was raised in: when the person
// changes business or account, the visible snack and the queued ones go, so
// a message (or its action) of the old context never shows in the new one.
// Only a change from one known context to another counts, not the first
// read. No timeout is touched.
//
// The Demo's persona and reset are NOT watched here: the Demo's own bar
// clears the messages when the visitor switches or resets
// (`DemoControls.viewAs`, `DemoControls.resetWithNotice`). The Demo's
// session provider lives above the Demo's own container and builds the whole
// Demo dataset wherever it is first read; a read from the shell would build
// it again inside every Demo scope and inside every live session
// (test/lint/demo_session_reads_test.dart).
import 'package:flutter/material.dart' show ScaffoldMessenger;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_source.dart';
import '../../features/workspace/providers/workspace_providers.dart';

void watchSnackScope(WidgetRef ref) {
  void clear<T>(T? before, T? after) {
    if (before == null || after == null || before == after) return;
    if (!ref.context.mounted) return;
    ScaffoldMessenger.maybeOf(ref.context)?.clearSnackBars();
  }

  ref
    ..listen(activeWorkspaceIdProvider, (p, n) => clear(p?.value, n.value))
    ..listen(sessionStateProvider, (p, n) => clear(p?.value, n.value));
}
