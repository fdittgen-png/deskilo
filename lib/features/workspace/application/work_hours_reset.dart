// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1307 S4 — the two ways back for the working day (ADR 0024: the row
// says which was chosen; this file decides the request and what it makes
// stale). The template's hours go through the same keyed write as an
// edit; the product default is the keys removed.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/work_hours.dart';
import '../providers/workspace_providers.dart';

Future<void> resetWorkHoursToTemplate(
    WidgetRef ref, String workspaceId, WorkHours templateHours) async {
  await ref
      .read(workspaceRepositoryProvider)
      .setWorkHours(workspaceId, templateHours);
  ref.invalidate(workHoursProvider);
}

Future<void> resetWorkHoursToProductDefault(
    WidgetRef ref, String workspaceId) async {
  await ref.read(workspaceRepositoryProvider).resetWorkHoursToDefault(workspaceId);
  ref.invalidate(workHoursProvider);
}
