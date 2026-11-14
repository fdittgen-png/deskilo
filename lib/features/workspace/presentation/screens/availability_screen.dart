// SPDX-License-Identifier: AGPL-3.0-or-later







import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/work_hours.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/form_scroll.dart';
import '../../../../core/ui/kit/page_bar.dart';
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
    // #3946 — a reload that failed is said, above the form that keeps the
    // last value; Try again repeats the reads that failed.
    final reads = <(AsyncValue<Object?>, void Function())>[
      (weekdaysAsync, () => ref.invalidate(openWeekdaysProvider)),
      (granularityAsync, () => ref.invalidate(bookingGranularityProvider)),
      (closuresAsync, () => ref.invalidate(closureDaysProvider)),
      (
        ref.watch(bookingPoliciesProvider),
        () => ref.invalidate(bookingPoliciesProvider),
      ),
    ];
    final failed = [
      for (final (value, retry) in reads)
        if (value.hasValue && value.hasError) (value, retry),
    ];

    return Scaffold(
      appBar: pageBar(context,
        title: l10n.availabilityTitle,
      ),
      body: switch ((weekdaysAsync, granularityAsync, closuresAsync)) {
        (
          // #3946 — a value being reloaded still shows: a choice made by
          // keyboard reloads the policies, and the form must keep its
          // controls (and the keyboard on them), not give way to a spinner.
          AsyncValue(value: final open?),
          AsyncValue(value: final granularity?),
          AsyncValue(value: final closures?),
        ) =>
          FormScroll(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              // A slot that is always there: the form below keeps its
              // elements (and the keyboard on them) as the banner comes
              // and goes.
              KeyedSubtree(
                key: const ValueKey('availability-read-failure-slot'),
                child: failed.isEmpty
                    ? const SizedBox.shrink()
                    : ReadFailureBanner(
                        error: failed.first.$1.error!,
                        onRetry: () {
                          for (final (_, retry) in failed) {
                            retry();
                          }
                        },
                      ),
              ),
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
