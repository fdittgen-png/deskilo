// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/shell_destinations.dart';
import '../../../../core/ui/async_read_body.dart';
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
    // #4017 — a failed read is said in the section's place, with Retry;
    // never "nothing to decide".
    final section = switch (ref.watch(myPendingEventsProvider)) {
      AsyncValue(hasValue: true, :final value?) when value.isNotEmpty =>
        PendingDecisionsSection(pending: value, recorded: true),
      AsyncValue(hasValue: false, :final error?) => ReadFailureBanner(
        error: error,
        onRetry: () => ref.invalidate(myPendingEventsProvider),
      ),
      _ => null,
    };
    if (section == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [section, const Divider(height: 1)],
    );
  }
}

/// How many decisions wait on this member — the number the calendar's Alerts
/// view and its destination badge show. #4017 — null when the read failed:
/// the count is unknown, never 0.
int? pendingAlertCount(WidgetRef ref) =>
    switch (ref.watch(myPendingEventCountProvider)) {
      AsyncValue(hasValue: true, :final value?) => value,
      AsyncValue(hasError: true) => null,
      _ => 0, // still reading: no badge yet
    };
