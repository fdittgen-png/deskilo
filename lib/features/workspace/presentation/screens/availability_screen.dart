// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/work_hours.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/generate_public_holidays.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/booking_policies.dart';
import '../../domain/closure_day.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/availability_tiles.dart';
import '../widgets/capacity_kpi_card.dart';
import '../widgets/holiday_import_sheet.dart';
import '../widgets/legend_profile_tile.dart';
import '../widgets/public_holidays_sheet.dart';
import '../widgets/work_hours_provenance_row.dart';

/// Owner-only availability editor (#127): which ISO weekdays (1=Mon..7=Sun,
/// stored in booking_rules) the workspace is open on, plus one-off closure
/// days. The server enforces both; this screen only edits the source of
/// truth.
class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  Future<void> _toggleWeekday(
    BuildContext context,
    WidgetRef ref,
    List<int> open,
    int weekday, {
    required bool selected,
  }) async {
    final l10n = context.l10n;
    if (!selected && open.length <= 1) {
      AppSnack.error(
        context,
        l10n.availabilityLastOpenDay,
      );
      return;
    }
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final updated = {...open};
    selected ? updated.add(weekday) : updated.remove(weekday);
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setOpenWeekdays(workspace.id, updated.toList()..sort());
    } on Object catch (e, st) {
      debugPrint('set open weekdays failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'set open weekdays failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(openWeekdaysProvider);
  }

  Future<void> _setGranularity(
    BuildContext context,
    WidgetRef ref,
    BookingGranularity? granularity,
  ) async {
    if (granularity == null) return;
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingGranularity(workspace.id, granularity);
    } on Object catch (e, st) {
      debugPrint('set booking granularity failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'set booking granularity failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(bookingGranularityProvider);
  }

  Future<void> _setWorkHours(
    BuildContext context,
    WidgetRef ref,
    WorkHours hours,
  ) async {
    final l10n = context.l10n;
    if (!hours.isValid) {
      AppSnack.error(
        context,
        l10n.availabilityWorkHoursInvalid,
      );
      return;
    }
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setWorkHours(workspace.id, hours);
    } on Object catch (e, st) {
      debugPrint('set work hours failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'set work hours failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(workHoursProvider);
  }

  Future<void> _setPolicy(
    BuildContext context,
    WidgetRef ref,
    String key,
    bool enabled,
  ) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingPolicy(workspace.id, key, enabled: enabled);
    } on Object catch (e, st) {
      debugPrint('set booking policy failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'set booking policy failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  Future<void> _setOutsideHoursMode(
    BuildContext context,
    WidgetRef ref,
    OutsideHoursMode? mode,
  ) async {
    if (mode == null) return;
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setOutsideHoursMode(workspace.id, mode);
    } on Object catch (e, st) {
      debugPrint('set outside-hours mode failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'set outside-hours mode failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  /// #628 — the workspace default for simultaneous reservations, through
  /// the same merge-preserving booking_rules write as the other policies.
  Future<void> _setSimultaneous(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setSimultaneousReservations(workspace.id, value);
    } on Object catch (e, st) {
      debugPrint('set simultaneous reservations failed: $e\n$st');
      TraceLogger.instance.error(
          'workspace', 'set simultaneous reservations failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  /// #649 — one writer for all three numeric limits; the key decides
  /// which. Same merge-preserving booking_rules write as every other
  /// policy, so the other keys survive untouched.
  Future<void> _setLimit(
    BuildContext context,
    WidgetRef ref,
    String key,
    int value,
  ) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingLimit(workspace.id, key, value);
    } on Object catch (e, st) {
      debugPrint('set booking limit failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'set booking limit failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  Future<void> _pickWorkTime(
    BuildContext context,
    WidgetRef ref,
    WorkHours hours,
    int currentMinutes,
    WorkHours Function(int minutes) apply,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );
    if (picked == null || !context.mounted) return;
    await _setWorkHours(context, ref, apply(picked.hour * 60 + picked.minute));
  }

  Future<void> _addClosure(BuildContext context, WidgetRef ref) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = context.l10n;

    final now = ref.read(clockProvider).now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (day == null || !context.mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _ReasonDialog(),
    );
    if (reason == null) return; // cancelled

    try {
      await ref
          .read(workspaceRepositoryProvider)
          .addClosureDay(workspace.id, day, reason.trim());
    } on Object catch (e, st) {
      debugPrint('add closure day failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'add closure day failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(closureDaysProvider);
  }

  Future<void> _removeClosure(
    BuildContext context,
    WidgetRef ref,
    ClosureDay closure,
  ) async {
    final l10n = context.l10n;
    try {
      await ref.read(workspaceRepositoryProvider).removeClosureDay(closure.id);
    } on Object catch (e, st) {
      debugPrint('remove closure day failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'remove closure day failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(closureDaysProvider);
  }

  void _showGenericError(BuildContext context, AppLocalizations l10n) {
    AppSnack.error(
      context,
      l10n.workspaceGenericError,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final weekdaysAsync = ref.watch(openWeekdaysProvider);
    final granularityAsync = ref.watch(bookingGranularityProvider);
    final closuresAsync = ref.watch(closureDaysProvider);
    // #446: the working-day editor and the hours granularity are one
    // feature-flagged unit; off = the 8:00–17:00 defaults, silently.
    final workingHoursOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.workingHours);
    final workHours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    // #1274: generating a year's holidays is asked for, never assumed.
    final holidaysOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.publicHolidays);
    // #600: the owner-configurable booking-behavior matrix.
    final policiesOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.bookingPolicies);
    final policies =
        ref.watch(bookingPoliciesProvider).value ?? const BookingPolicies();

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
              Row(children: [
                Flexible(
                  child: SectionHeader(
                    l10n.availabilityOpenWeekdays,
                  ),
                ),
                HelpDot(
                  l10n.helpHintAvailabilityTopic,
                  anchor: HelpAnchor.availabilityOpenWeekdays,
                ),
              ]),
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
                          DateFormat.E(locale)
                              .format(DateTime(2024, 1, weekday)),
                        ),
                        selected: open.contains(weekday),
                        onSelected: (selected) => _toggleWeekday(
                          context,
                          ref,
                          open,
                          weekday,
                          selected: selected,
                        ),
                      ),
                  ],
                ),
              ),
              Row(children: [
                Flexible(
                  child: SectionHeader(
                    l10n.availabilityGranularityTitle,
                  ),
                ),
                HelpDot(
                  l10n.helpHintAvailabilityTopic,
                  anchor: HelpAnchor.availabilityGranularity,
                ),
              ]),
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
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: DropdownButtonFormField<BookingGranularity>(
                  key: const ValueKey('availability-granularity'),
                  isExpanded: true,
                  initialValue: granularity,
                  // The section title above names it; no second label.
                  items: [
                    for (final (value, label) in [
                      (BookingGranularity.flexible,
                          l10n.availabilityGranularityFlexible),
                      (BookingGranularity.minutes5,
                          l10n.availabilityGranularity5),
                      (BookingGranularity.minutes15,
                          l10n.availabilityGranularity15),
                      (BookingGranularity.minutes30,
                          l10n.availabilityGranularity30),
                      (BookingGranularity.minutes60,
                          l10n.availabilityGranularity60),
                      (BookingGranularity.halfDay,
                          l10n.availabilityGranularityHalfDay),
                      (BookingGranularity.fullDay,
                          l10n.availabilityGranularityFullDay),
                      if (workingHoursOn)
                        (BookingGranularity.hours,
                            l10n.availabilityGranularityHours),
                    ])
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                  onChanged: (value) => _setGranularity(context, ref, value),
                ),
              ),
              if (workingHoursOn) ...[
                Row(children: [
                  Flexible(
                    child: SectionHeader(
                      l10n.availabilityWorkHoursTitle,
                    ),
                  ),
                  HelpDot(
                    l10n.helpTopicWorkingHours,
                    anchor: HelpAnchor.availabilityWorkingHours,
                  ),
                ]),
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
                  onTap: () => _pickWorkTime(
                    context,
                    ref,
                    workHours,
                    workHours.startMinutes,
                    (m) => workHours.copyWith(startMinutes: m),
                  ),
                ),
                WorkTimeTile(
                  key: const ValueKey('availability-half-boundary'),
                  keySuffix: 'boundary',
                  title:
                      l10n.availabilityHalfBoundary,
                  minutes: workHours.halfBoundaryMinutes,
                  onTap: () => _pickWorkTime(
                    context,
                    ref,
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
                  onTap: () => _pickWorkTime(
                    context,
                    ref,
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
                    onChanged: (v) => _setWorkHours(
                      context,
                      ref,
                      workHours.copyWith(halfDayHours: v),
                    ),
                  ),
                  HourCountTile(
                    key: const ValueKey('availability-full-day-hours'),
                    keySuffix: 'full-day-hours',
                    title: l10n.availabilityFullDayHours,
                    value: workHours.fullDayHours,
                    onChanged: (v) => _setWorkHours(
                      context,
                      ref,
                      workHours.copyWith(fullDayHours: v),
                    ),
                  ),
                ],
              ],
              if (policiesOn) ...[
                Row(children: [
                  Flexible(
                    child: SectionHeader(
                      l10n.availabilityPoliciesTitle,
                    ),
                  ),
                  HelpDot(
                    l10n.helpTopicBookingPolicies,
                    anchor: HelpAnchor.availabilityPolicies,
                  ),
                ]),
                SwitchListTile(
                  key: const Key('policy-allow-past'),
                  title: HelpDotTitle(
                    l10n.policyAllowPastTitle,
                    l10n.helpTopicBookingPolicies,
                    anchor: HelpAnchor.availabilityAllowPast,
                  ),
                  subtitle: Text(l10n.policyAllowPastDesc),
                  value: policies.allowPastBookings,
                  onChanged: (v) => _setPolicy(context, ref,
                      BookingPolicies.allowPastBookingsKey, v),
                ),
                SwitchListTile(
                  key: const Key('policy-admin-checkout'),
                  title: HelpDotTitle(
                    l10n.policyAdminCheckoutTitle,
                    l10n.helpTopicBookingPolicies,
                    anchor: HelpAnchor.availabilityAdminCheckout,
                  ),
                  subtitle: Text(l10n.policyAdminCheckoutDesc),
                  value: policies.adminCheckOut,
                  onChanged: (v) => _setPolicy(context, ref,
                      BookingPolicies.adminCheckOutKey, v),
                ),
                // #634 — ONE question, four mutually exclusive answers
                // (#600's grid switch folded in). Radio rows, not a
                // four-way SegmentedButton: four labels do not fit a
                // 360dp phone.
                LegendProfileTile(policies: policies),
                ListTile(
                  title: HelpDotTitle(
                    l10n.policyOutsideHoursTitle,
                    l10n.helpTopicBookingPolicies,
                    anchor: HelpAnchor.availabilityOutsideHours,
                  ),
                  subtitle: Text(l10n.policyOutsideHoursDesc),
                ),
                RadioGroup<OutsideHoursMode>(
                  key: const Key('policy-outside-hours'),
                  groupValue: policies.outsideHoursMode,
                  onChanged: (mode) =>
                      _setOutsideHoursMode(context, ref, mode),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<OutsideHoursMode>(
                        key: const Key('policy-outside-hours-off'),
                        value: OutsideHoursMode.off,
                        title: Text(l10n.policyOutsideHoursOff),
                        subtitle: Text(l10n.policyOutsideHoursOffDesc),
                      ),
                      RadioListTile<OutsideHoursMode>(
                        key: const Key('policy-outside-hours-walkup'),
                        value: OutsideHoursMode.walkupOnly,
                        title: Text(l10n.policyOutsideHoursWalkUp),
                        subtitle: Text(l10n.policyOutsideHoursWalkUpDesc),
                      ),
                      RadioListTile<OutsideHoursMode>(
                        key: const Key('policy-outside-hours-free'),
                        value: OutsideHoursMode.free,
                        title: Text(l10n.policyOutsideHoursFree),
                        subtitle: Text(l10n.policyOutsideHoursFreeDesc),
                      ),
                      RadioListTile<OutsideHoursMode>(
                        key: const Key('policy-outside-hours-charged'),
                        value: OutsideHoursMode.charged,
                        title: Text(
                            l10n.policyOutsideHoursCharged),
                        subtitle: Text(
                            l10n.policyOutsideHoursChargedDesc),
                      ),
                    ],
                  ),
                ),
                // #628 — how many overlapping bookings a member may hold.
                SimultaneousTile(
                  key: const ValueKey('availability-simultaneous-tile'),
                  value: policies.simultaneousReservations,
                  onChanged: (v) => _setSimultaneous(context, ref, v),
                ),
                // #649 — the three numeric limits the server has enforced
                // since 0006 but nothing could set. Shown with the values
                // the server coalesces to, so an untouched workspace
                // displays what it actually does.
                Row(children: [
                  Flexible(
                    child: SectionHeader(
                      l10n.policyLimitsTitle,
                    ),
                  ),
                  HelpDot(
                    l10n.helpTopicBookingLimits,
                    anchor: HelpAnchor.availabilityLimits,
                  ),
                ]),
                Padding(
                  padding: AppSpacing.lgH,
                  child: Text(
                    l10n.policyLimitsDesc,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                LimitTile(
                  key: const ValueKey('availability-policy-horizon-title'),
                  keySuffix: 'horizon',
                  icon: Icons.event_available_outlined,
                  title: l10n.policyHorizonTitle,
                  description: l10n.policyHorizonDesc,
                  value: policies.advanceHorizonDays,
                  options: horizonOptions,
                  format: l10n.policyDaysValue,
                  onChanged: (v) => _setLimit(context, ref,
                      BookingPolicies.advanceHorizonDaysKey, v),
                ),
                LimitTile(
                  key: const ValueKey('availability-policy-min-duration-title'),
                  keySuffix: 'min-duration',
                  icon: Icons.hourglass_bottom_outlined,
                  title: l10n.policyMinDurationTitle,
                  description: l10n.policyMinDurationDesc,
                  value: policies.minDurationMinutes,
                  options: durationOptions,
                  format: (v) => formatDuration(l10n, v),
                  onChanged: (v) => _setLimit(context, ref,
                      BookingPolicies.minDurationMinutesKey, v),
                ),
                LimitTile(
                  key: const ValueKey('availability-policy-max-duration-title'),
                  keySuffix: 'max-duration',
                  icon: Icons.hourglass_top_outlined,
                  title: l10n.policyMaxDurationTitle,
                  description: l10n.policyMaxDurationDesc,
                  value: policies.maxDurationMinutes,
                  options: durationOptions,
                  format: (v) => formatDuration(l10n, v),
                  onChanged: (v) => _setLimit(context, ref,
                      BookingPolicies.maxDurationMinutesKey, v),
                ),
                // A minimum above the maximum refuses EVERY booking, and
                // the server compares each bound on its own, so it would
                // never complain — say so here instead.
                if (!policies.durationsAreCoherent)
                  Padding(
                    padding: AppSpacing.lgH,
                    child: Text(
                      l10n.policyDurationConflict,
                      key: const Key('policy-duration-conflict'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
              ],
              Row(children: [
                Flexible(
                  child: SectionHeader(
                    l10n.availabilityClosureDays,
                  ),
                ),
                HelpDot(
                  l10n.helpTopicWorkingHours,
                  anchor: HelpAnchor.availabilityClosureDays,
                ),
              ]),
              // #2313 — adding a closure day is a row of its own section,
              // not a floating button over every other section.
              ListTile(
                key: const ValueKey('availability-add-closure'),
                leading: const Icon(Icons.add),
                title: Text(l10n.availabilityAddClosure),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _addClosure(context, ref),
              ),
              if (holidaysOn)
                ListTile(
                  key: const ValueKey('availability-public-holidays'),
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(
                    l10n.publicHolidaysAction,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  // The screen already holds the repository for its own
                  // closure-day writes; the sheet is handed the decision
                  // rather than reaching for one itself (ADR 0024).
                  onTap: () => showPublicHolidaysSheet(
                    context,
                    PublicHolidayGeneration(
                        ref.read(workspaceRepositoryProvider)),
                  ),
                ),
              if (holidaysOn) const HolidayImportTile(), // #2051
              if (closures.isEmpty)
                Padding(
                  padding: AppSpacing.lgH,
                  child: Text(
                    l10n.availabilityNoClosures,
                  ),
                ),
              for (final closure in closures)
                ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text(
                    DateFormat.yMMMMd(locale).format(closure.day),
                  ),
                  subtitle:
                      closure.reason.isEmpty ? null : Text(closure.reason),
                  trailing: IconButton(
                    key: ValueKey('availability-delete-${closure.id}'),
                    tooltip: l10n.commonDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeClosure(context, ref, closure),
                  ),
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

/// One working-day bound: localized clock text, tap opens a time picker.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.availabilityAddClosure),
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(
          labelText: l10n.availabilityClosureReason,
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('availability-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('availability-save'),
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
