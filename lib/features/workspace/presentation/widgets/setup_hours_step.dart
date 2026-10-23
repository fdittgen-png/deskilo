// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "opening hours": the availability screen's own weekday,
// working-day and closure sections, embedded with their writes
// ([AvailabilityActions]); the booking unit and the booking rules stay on
// that screen, one tap away. Beside them the week as members can book it,
// hour by hour and in words, and the next closures and holidays.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/work_hours.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/closure_day.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../screens/availability_actions.dart';
import '../screens/availability_sections.dart';
import 'setup_week_strip.dart';

/// How many coming closures the preview lists.
const int _nextClosures = 3;

class SetupHoursStep extends ConsumerWidget {
  const SetupHoursStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    // #446: off = the 8:00–17:00 defaults, as on the availability screen.
    final workingHoursOn = features.contains(WorkspaceFeature.workingHours);
    final workHours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    return switch ((
      ref.watch(openWeekdaysProvider),
      ref.watch(bookingGranularityProvider),
      ref.watch(closureDaysProvider),
    )) {
      (
        AsyncData(value: final open),
        AsyncData(value: final granularity),
        AsyncData(value: final closures),
      ) =>
        SetupStepLayout(
          form: _HoursForm(
            actions: AvailabilityActions(context, ref),
            open: open,
            granularity: granularity,
            closures: closures,
            workHours: workHours,
            workingHoursOn: workingHoursOn,
            holidaysOn: features.contains(WorkspaceFeature.publicHolidays),
          ),
          preview: _HoursPreview(
            open: open,
            workHours: workHours,
            closures: closures,
            today: ref.watch(clockProvider).now(),
          ),
        ),
      (AsyncError(), _, _) ||
      (_, AsyncError(), _) ||
      (_, _, AsyncError()) => Padding(
        padding: AppSpacing.lgAll,
        child: InlineBanner(
          key: const ValueKey('setup-hours-failed'),
          icon: Icons.error_outline,
          text: context.l10n.setupStepLoadFailed,
        ),
      ),
      _ => const LoadingView(),
    };
  }
}

class _HoursForm extends StatelessWidget {
  const _HoursForm({
    required this.actions,
    required this.open,
    required this.granularity,
    required this.closures,
    required this.workHours,
    required this.workingHoursOn,
    required this.holidaysOn,
  });

  final AvailabilityActions actions;
  final List<int> open;
  final BookingGranularity granularity;
  final List<ClosureDay> closures;
  final WorkHours workHours;
  final bool workingHoursOn;
  final bool holidaysOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('hours')),
        const SizedBox(height: AppSpacing.sm),
        AvailabilityWeekdays(actions: actions, open: open),
        if (workingHoursOn)
          AvailabilityWorkHours(
            actions: actions,
            workHours: workHours,
            granularity: granularity,
          ),
        AvailabilityClosures(
          actions: actions,
          closures: closures,
          holidaysOn: holidaysOn,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('setup-hours-open-availability'),
            onPressed: () => context.push('/availability'),
            child: Text(l10n.setupHoursOpenAvailability),
          ),
        ),
      ],
    );
  }
}

class _HoursPreview extends StatelessWidget {
  const _HoursPreview({
    required this.open,
    required this.workHours,
    required this.closures,
    required this.today,
  });

  final List<int> open;
  final WorkHours workHours;
  final List<ClosureDay> closures;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final from = DateTime(today.year, today.month, today.day);
    final coming = closures.where((c) => !c.day.isBefore(from)).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return Column(
      key: const ValueKey('setup-hours-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupHoursWeekTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        SetupWeekStrip(open: open, workHours: workHours),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.setupHoursNextClosures, style: theme.textTheme.labelLarge),
        if (coming.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.setupHoursNoClosures,
              key: const ValueKey('setup-hours-no-closures'),
            ),
          ),
        for (final closure in coming.take(_nextClosures))
          ListTile(
            key: ValueKey('setup-hours-closure-${closure.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(DateFormat.yMMMMEEEEd(locale).format(closure.day)),
            subtitle: closure.reason.isEmpty ? null : Text(closure.reason),
          ),
      ],
    );
  }
}
