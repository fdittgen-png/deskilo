// SPDX-License-Identifier: AGPL-3.0-or-later







import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/work_hours.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/booking_policies.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/capacity_kpi_card.dart';
import 'availability_actions.dart';
import 'availability_policies.dart';
import 'availability_sections.dart';

/// Owner-only availability editor (#127): which ISO weekdays (1=Mon..7=Sun,
/// stored in booking_rules) the workspace is open on, plus one-off closure
/// days. The server enforces both; this screen only edits the source of
/// truth. Each section is a widget of its own, the writes are
/// [AvailabilityActions] (#2494).
class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final weekdaysAsync = ref.watch(openWeekdaysProvider);
    final granularityAsync = ref.watch(bookingGranularityProvider);
    final closuresAsync = ref.watch(closureDaysProvider);
    // #446: the working-day editor and the hours granularity are one
    // feature-flagged unit; off = the 8:00–17:00 defaults, silently.
    final features = ref.watch(enabledFeaturesSyncProvider);
    final workingHoursOn = features.contains(WorkspaceFeature.workingHours);
    final workHours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    // #1274: generating a year's holidays is asked for, never assumed.
    final holidaysOn = features.contains(WorkspaceFeature.publicHolidays);
    // #600: the owner-configurable booking-behavior matrix.
    final policiesOn = features.contains(WorkspaceFeature.bookingPolicies);
    final policies =
        ref.watch(bookingPoliciesProvider).value ?? const BookingPolicies();
    final actions = AvailabilityActions(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.availabilityTitle),
      ),
      body: switch ((weekdaysAsync, granularityAsync, closuresAsync)) {
        (
          AsyncData(value: final open),
          AsyncData(value: final granularity),
          AsyncData(value: final closures),
        ) =>
          ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              // #606 — contextual how-to; gated inside the widget.
              const HelpHint(HelpHintId.availability),
              AvailabilityWeekdays(actions: actions, open: open),
              AvailabilityGranularity(
                actions: actions,
                granularity: granularity,
                workingHoursOn: workingHoursOn,
              ),
              if (workingHoursOn)
                AvailabilityWorkHours(
                  actions: actions,
                  workHours: workHours,
                  granularity: granularity,
                ),
              if (policiesOn)
                AvailabilityPolicies(actions: actions, policies: policies),
              AvailabilityClosures(
                actions: actions,
                closures: closures,
                holidaysOn: holidaysOn,
              ),
              const CapacityKpiCard(), // #1918, gated inside
            ],
          ),
        (AsyncError(), _, _) ||
        (_, AsyncError(), _) ||
        (_, _, AsyncError()) =>
          Center(
            child: Text(
              l10n.workspaceGenericError,
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}
