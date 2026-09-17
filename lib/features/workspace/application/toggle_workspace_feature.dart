// SPDX-License-Identifier: 0BSD
//
// #1327 — what flipping one feature switch writes, out of the Features
// screen.
//
// ADR 0024 draws the line at the repository: `presentation/` says what
// the owner asked for, `application/` decides which write that is. The
// screen grew a second view (the process overview) and the decision
// below had no reason to stay beside it. The write is unchanged — the
// same delta, the same merge, the same forced refetch — which is what
// `features_screen_test`'s #963 pins prove. The one difference: the
// screen now guards the refetch too, so a failed refetch shows the
// generic error instead of escaping as an unhandled exception.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/workspace.dart';
import '../domain/workspace_feature.dart';
import '../providers/workspace_providers.dart';

/// Writes [feature] = [value] for [workspace] and waits until the
/// workspace chain has re-derived its features from the new row.
Future<void> toggleWorkspaceFeature(
  WidgetRef ref, {
  required Workspace workspace,
  required WorkspaceFeature feature,
  required bool value,
}) async {
  // #963 — write ONLY what this toggle changes; the server merges it
  // into the row. A full map written from a stale copy of the row put
  // the pilot's earlier switches back off. Switching ON carries the
  // requires chain with it (#800).
  final flags = {
    for (final entry in featureFlagsToggleDelta(
      feature: feature,
      value: value,
    ).entries)
      entry.key.dbKey: entry.value,
  };
  await ref
      .read(workspaceRepositoryProvider)
      .setFeatureFlags(workspace.id, flags);
  // The workspace chain re-derives enabledFeatures from the new row —
  // that applies the gates locally right away. The read after the
  // invalidation FORCES the fetch: the pilot's device skipped it twice
  // out of three and the switch stayed where it was.
  ref.invalidate(myWorkspacesProvider);
  await ref.read(myWorkspacesProvider.future);
}
