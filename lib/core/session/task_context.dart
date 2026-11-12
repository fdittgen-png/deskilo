// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — the context a task belongs to, as one token: an open
// task (lib/core/ui/adaptive/task_surface.dart) is closed, unasked, when it
// changes, so the next person or business never sees the previous one's
// form. Core knows only the signed-in person; the composition root and the
// Demo add the workspace (`taskContextFromWorkspace`).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_source.dart';

/// The signed-in user's id, and where the app composes it, `| workspace id`.
final taskContextTokenProvider = Provider<String>(
  (ref) => ref.watch(sessionStateProvider).value ?? '',
);
