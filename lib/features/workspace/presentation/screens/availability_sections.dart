// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/work_hours.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/closure_day.dart';
import '../widgets/availability_tiles.dart';
import '../widgets/holiday_import_sheet.dart';
import '../widgets/work_hours_provenance_row.dart';
import 'availability_actions.dart';

/// The open weekdays: one chip each (#127).
class AvailabilityWeekdays extends StatelessWidget {
  const AvailabilityWeekdays({
    super.key,
    required this.actions,
    required this.open,
  });

  final AvailabilityActions actions;
  final List<int> open;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: SectionHeader(l10n.availabilityOpenWeekdays)),
            HelpDot(
              l10n.helpHintAvailabilityTopic,
              anchor: HelpAnchor.availabilityOpenWeekdays,
            ),
          ],
        ),
        Padding(
          padding: AppSpacing.lgH,
          child: Wrap(
            spacing: 8,
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                FilterChip(
                  // 2024-01-01 was a Monday, so day-of-month == isodow:
                  // locale weekday names without hardcoded strings.
                  key: ValueKey('availability-filter-chip-$weekday'),
                  label: Text(
                    DateFormat.E(locale).format(DateTime(2024, 1, weekday)),
                  ),
                  selected: open.contains(weekday),
                  onSelected: (selected) =>
                      actions.toggleWeekday(open, weekday, selected: selected),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The booking granularity (#2313: one dropdown).
class AvailabilityGranularity extends StatelessWidget {
  const AvailabilityGranularity({
    super.key,
    required this.actions,
    required this.granularity,
    required this.workingHoursOn,
  });

  final AvailabilityActions actions;
  final BookingGranularity granularity;
  final bool workingHoursOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: SectionHeader(l10n.availabilityGranularityTitle)),
            HelpDot(
              l10n.helpHintAvailabilityTopic,
              anchor: HelpAnchor.availabilityGranularity,
            ),
          ],
        ),
        Padding(
          padding: AppSpacing.lgH,
          child: Text(
            l10n.availabilityGranularityDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // #2313 — one choice, one control: a dropdown instead of
        // eight radio rows pushing the rest of the page down.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: DropdownButtonFormField<BookingGranularity>(
            key: const ValueKey('availability-granularity'),
            isExpanded: true,
            initialValue: granularity,
            // The section title above names it; no second label.
            items: [
              for (final (value, label) in [
                (
                  BookingGranularity.flexible,
                  l10n.availabilityGranularityFlexible,
                ),
                (BookingGranularity.minutes5, l10n.availabilityGranularity5),
                (BookingGranularity.minutes15, l10n.availabilityGranularity15),
                (BookingGranularity.minutes30, l10n.availabilityGranularity30),
                (BookingGranularity.minutes60, l10n.availabilityGranularity60),
                (
                  BookingGranularity.halfDay,
                  l10n.availabilityGranularityHalfDay,
                ),
                (
                  BookingGranularity.fullDay,
                  l10n.availabilityGranularityFullDay,
                ),
                if (workingHoursOn)
                  (BookingGranularity.hours, l10n.availabilityGranularityHours),
              ])
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: actions.setGranularity,
          ),
        ),
      ],
    );
  }
}

/// The working day and the hour counts of the hours granularity (#446).
class AvailabilityWorkHours extends StatelessWidget {
  const AvailabilityWorkHours({
    super.key,
    required this.actions,
    required this.workHours,
    required this.granularity,
  });

  final AvailabilityActions actions;
  final WorkHours workHours;
  final BookingGranularity granularity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: SectionHeader(l10n.availabilityWorkHoursTitle)),
            HelpDot(
              l10n.helpTopicWorkingHours,
              anchor: HelpAnchor.availabilityWorkingHours,
            ),
          ],
        ),
        Padding(
          padding: AppSpacing.lgH,
          child: Text(
            l10n.availabilityWorkHoursDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const WorkHoursProvenanceRow(),
        WorkTimeTile(
          key: const ValueKey('availability-work-start'),
          keySuffix: 'start',
          title: l10n.availabilityWorkStart,
          minutes: workHours.startMinutes,
          onTap: () => actions.pickWorkTime(
            workHours,
            workHours.startMinutes,
            (m) => workHours.copyWith(startMinutes: m),
          ),
        ),
        WorkTimeTile(
          key: const ValueKey('availability-half-boundary'),
          keySuffix: 'boundary',
          title: l10n.availabilityHalfBoundary,
          minutes: workHours.halfBoundaryMinutes,
          onTap: () => actions.pickWorkTime(
            workHours,
            workHours.halfBoundaryMinutes,
            (m) => workHours.copyWith(halfBoundaryMinutes: m),
          ),
        ),
        WorkTimeTile(
          key: const ValueKey('availability-work-end'),
          keySuffix: 'end',
          title: l10n.availabilityWorkEnd,
          minutes: workHours.endMinutes,
          onTap: () => actions.pickWorkTime(
            workHours,
            workHours.endMinutes,
            (m) => workHours.copyWith(endMinutes: m),
          ),
        ),
        // The hour counts only price bookings under the hours
        // granularity - half-day equivalents on the statement.
        if (granularity == BookingGranularity.hours) ...[
          HourCountTile(
            key: const ValueKey('availability-half-day-hours'),
            keySuffix: 'half-day-hours',
            title: l10n.availabilityHalfDayHours,
            value: workHours.halfDayHours,
            onChanged: (v) =>
                actions.setWorkHours(workHours.copyWith(halfDayHours: v)),
          ),
          HourCountTile(
            key: const ValueKey('availability-full-day-hours'),
            keySuffix: 'full-day-hours',
            title: l10n.availabilityFullDayHours,
            value: workHours.fullDayHours,
            onChanged: (v) =>
                actions.setWorkHours(workHours.copyWith(fullDayHours: v)),
          ),
        ],
      ],
    );
  }
}

/// One-off closure days and the public holidays (#127, #1274, #2051).
class AvailabilityClosures extends StatelessWidget {
  const AvailabilityClosures({
    super.key,
    required this.actions,
    required this.closures,
    required this.holidaysOn,
  });

  final AvailabilityActions actions;
  final List<ClosureDay> closures;
  final bool holidaysOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: SectionHeader(l10n.availabilityClosureDays)),
            HelpDot(
              l10n.helpTopicWorkingHours,
              anchor: HelpAnchor.availabilityClosureDays,
            ),
          ],
        ),
        // #2313 — adding a closure day is a row of its own section,
        // not a floating button over every other section.
        ListTile(
          key: const ValueKey('availability-add-closure'),
          leading: const Icon(Icons.add),
          title: Text(l10n.availabilityAddClosure),
          trailing: const Icon(Icons.chevron_right),
          onTap: actions.addClosure,
        ),
        if (holidaysOn)
          ListTile(
            key: const ValueKey('availability-public-holidays'),
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.publicHolidaysAction),
            trailing: const Icon(Icons.chevron_right),
            // The screen already holds the repository for its own
            // closure-day writes; the sheet is handed the decision
            // rather than reaching for one itself (ADR 0024).
            onTap: actions.showPublicHolidays,
          ),
        if (holidaysOn) const HolidayImportTile(), // #2051
        if (closures.isEmpty)
          Padding(
            padding: AppSpacing.lgH,
            child: Text(l10n.availabilityNoClosures),
          ),
        for (final closure in closures)
          ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(DateFormat.yMMMMd(locale).format(closure.day)),
            subtitle: closure.reason.isEmpty ? null : Text(closure.reason),
            trailing: IconButton(
              key: ValueKey('availability-delete-${closure.id}'),
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => actions.removeClosure(closure),
            ),
          ),
      ],
    );
  }
}
