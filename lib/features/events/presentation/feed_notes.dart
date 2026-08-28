// SPDX-License-Identifier: 0BSD
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/domain/member_note.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';

/// The notes the notification feed still carries (#687).
///
/// Only BROADCASTS. An admin broadcast is a fan-out to whoever is an
/// admin at READ time — it has no recipient, no thread, and nowhere in
/// the messaging centre to live, so the bell is its home.
///
/// The direct exchange left, both sides of it. The SENT side is what
/// made this feed an inbox reporting your own outbox.
List<MemberNote> broadcastsForFeed(WidgetRef ref) {
  if (!ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.memberNotifications)) {
    return const [];
  }
  return [
    for (final n in ref.watch(myNotesProvider).value ?? const <MemberNote>[])
      if (n.isBroadcast) n,
  ];
}
