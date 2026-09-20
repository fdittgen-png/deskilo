// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/shell_destinations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/event_providers.dart';
import 'pending_decisions_section.dart';

/// #1306 S2 — the decisions waiting on this member, at the top of the
/// calendar, when the calendar is where the decision signal lives
/// ([decisionSignalOnCalendar]): the events bell is off, and the calendar
/// shows decisions on its timeline.
///
/// The Calendar badge counts exactly these, so tapping the badge opens the
/// content it counts. Nothing pending, or the bell still on: nothing here.
class CalendarDecisions extends ConsumerWidget {
  const CalendarDecisions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    if (!decisionSignalOnCalendar(features)) return const SizedBox.shrink();
    final pending = ref.watch(myPendingEventsProvider).value ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PendingDecisionsSection(pending: pending),
        const Divider(height: 1),
      ],
    );
  }
}
