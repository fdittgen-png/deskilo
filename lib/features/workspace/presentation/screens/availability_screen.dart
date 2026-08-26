// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/time/work_hours.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/booking_policies.dart';
import '../../domain/closure_day.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/availability_tiles.dart';
import '../../../../core/time/clock.dart';

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
    final l10n = AppLocalizations.of(context);
    if (!selected && open.length <= 1) {
      AppSnack.error(
        context,
        l10n?.availabilityLastOpenDay ??
            'At least one weekday must stay open.',
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
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingGranularity(workspace.id, granularity);
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);
    if (!hours.isValid) {
      AppSnack.error(
        context,
        l10n?.availabilityWorkHoursInvalid ??
            'The day must run start < half-day boundary < end.',
      );
      return;
    }
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setWorkHours(workspace.id, hours);
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingPolicy(workspace.id, key, enabled: enabled);
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setOutsideHoursMode(workspace.id, mode);
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setSimultaneousReservations(workspace.id, value);
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingLimit(workspace.id, key, value);
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);

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
    } catch (e, st) {
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
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(workspaceRepositoryProvider).removeClosureDay(closure.id);
    } catch (e, st) {
      debugPrint('remove closure day failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'remove closure day failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      _showGenericError(context, l10n);
      return;
    }
    ref.invalidate(closureDaysProvider);
  }

  void _showGenericError(BuildContext context, AppLocalizations? l10n) {
    AppSnack.error(
      context,
      l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
    // #600: the owner-configurable booking-behavior matrix.
    final policiesOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.bookingPolicies);
    final policies =
        ref.watch(bookingPoliciesProvider).value ?? const BookingPolicies();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.availabilityTitle ?? 'Availability'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n?.availabilityAddClosure ?? 'Add closure day',
        onPressed: () => _addClosure(context, ref),
        child: const Icon(Icons.add),
      ),
      body: switch ((weekdaysAsync, granularityAsync, closuresAsync)) {
        (
          AsyncData(value: final open),
          AsyncData(value: final granularity),
          AsyncData(value: final closures),
        ) =>
          ListView(
            children: [
              // #606 — contextual how-to; gated inside the widget.
              const HelpHint(HelpHintId.availability),
              SectionHeader(
                l10n?.availabilityOpenWeekdays ?? 'Open weekdays',
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
              SectionHeader(
                l10n?.availabilityGranularityTitle ?? 'Booking granularity',
              ),
              Padding(
                padding: AppSpacing.lgH,
                child: Text(
                  l10n?.availabilityGranularityDescription ??
                      'Half days: bookings cover the morning (until 13:00), '
                          'the afternoon (from 13:00) or the whole day.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              RadioGroup<BookingGranularity>(
                groupValue: granularity,
                onChanged: (value) => _setGranularity(context, ref, value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<BookingGranularity>(
                      value: BookingGranularity.flexible,
                      title: Text(
                        l10n?.availabilityGranularityFlexible ??
                            'Free time period',
                      ),
                    ),
                    RadioListTile<BookingGranularity>(
                      value: BookingGranularity.minutes5,
                      title: Text(
                        l10n?.availabilityGranularity5 ?? '5-minute slots',
                      ),
                    ),
                    RadioListTile<BookingGranularity>(
                      value: BookingGranularity.minutes15,
                      title: Text(
                        l10n?.availabilityGranularity15 ??
                            '15-minute slots',
                      ),
                    ),
                    RadioListTile<BookingGranularity>(
                      value: BookingGranularity.minutes30,
                      title: Text(
                        l10n?.availabilityGranularity30 ??
                            '30-minute slots',
                      ),
                    ),
                    RadioListTile<BookingGranularity>(
                      value: BookingGranularity.minutes60,
                      title: Text(
                        l10n?.availabilityGranularity60 ?? '1-hour slots',
                      ),
                    ),
                    RadioListTile<BookingGranularity>(
                      value: BookingGranularity.halfDay,
                      title: Text(
                        l10n?.availabilityGranularityHalfDay ??
                            'Half days (morning & afternoon)',
                      ),
                    ),
                    RadioListTile<BookingGranularity>(
                      value: BookingGranularity.fullDay,
                      title: Text(
                        l10n?.availabilityGranularityFullDay ??
                            'Full days only',
                      ),
                    ),
                    if (workingHoursOn)
                      RadioListTile<BookingGranularity>(
                        value: BookingGranularity.hours,
                        title: Text(
                          l10n?.availabilityGranularityHours ??
                              'Real hours (exact from-to, half/full days '
                                  'as shortcuts)',
                        ),
                      ),
                  ],
                ),
              ),
              if (workingHoursOn) ...[
                SectionHeader(
                  l10n?.availabilityWorkHoursTitle ?? 'Working hours',
                ),
                Padding(
                  padding: AppSpacing.lgH,
                  child: Text(
                    l10n?.availabilityWorkHoursDescription ??
                        'The half-day and full-day windows everywhere - '
                            'reservations, check-in and invoicing - follow '
                            'these hours.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                WorkTimeTile(
                  keySuffix: 'start',
                  title: l10n?.availabilityWorkStart ?? 'Day starts',
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
                  keySuffix: 'boundary',
                  title:
                      l10n?.availabilityHalfBoundary ?? 'Half-day boundary',
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
                  keySuffix: 'end',
                  title: l10n?.availabilityWorkEnd ?? 'Day ends',
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
                    keySuffix: 'half-day-hours',
                    title: l10n?.availabilityHalfDayHours ??
                        'Hours billed as a half day',
                    value: workHours.halfDayHours,
                    onChanged: (v) => _setWorkHours(
                      context,
                      ref,
                      workHours.copyWith(halfDayHours: v),
                    ),
                  ),
                  HourCountTile(
                    keySuffix: 'full-day-hours',
                    title: l10n?.availabilityFullDayHours ??
                        'Hours billed as a full day',
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
                SectionHeader(
                  l10n?.availabilityPoliciesTitle ?? 'Booking policies',
                ),
                SwitchListTile(
                  key: const Key('policy-allow-past'),
                  title: Text(l10n?.policyAllowPastTitle ??
                      'Allow past bookings'),
                  subtitle: Text(l10n?.policyAllowPastDesc ??
                      'Members may record a booking that already '
                          'ended (backfill).'),
                  value: policies.allowPastBookings,
                  onChanged: (v) => _setPolicy(context, ref,
                      BookingPolicies.allowPastBookingsKey, v),
                ),
                SwitchListTile(
                  key: const Key('policy-admin-checkout'),
                  title: Text(l10n?.policyAdminCheckoutTitle ??
                      'Admins may check members out'),
                  subtitle: Text(l10n?.policyAdminCheckoutDesc ??
                      "An admin can end a member's running check-in."),
                  value: policies.adminCheckOut,
                  onChanged: (v) => _setPolicy(context, ref,
                      BookingPolicies.adminCheckOutKey, v),
                ),
                // #634 — ONE question, four mutually exclusive answers
                // (#600's grid switch folded in). Radio rows, not a
                // four-way SegmentedButton: four labels do not fit a
                // 360dp phone.
                ListTile(
                  title: Text(l10n?.policyOutsideHoursTitle ??
                      'Outside the opening hours'),
                  subtitle: Text(l10n?.policyOutsideHoursDesc ??
                      'What may happen outside the working day — the '
                          'same answer on every granularity.'),
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
                        title: Text(l10n?.policyOutsideHoursOff ?? 'Off'),
                        subtitle: Text(l10n?.policyOutsideHoursOffDesc ??
                            'Nothing outside the hours: no booking '
                                'ahead, no walk-up, and a booking '
                                'running past the day end is refused.'),
                      ),
                      RadioListTile<OutsideHoursMode>(
                        key: const Key('policy-outside-hours-walkup'),
                        value: OutsideHoursMode.walkupOnly,
                        title: Text(l10n?.policyOutsideHoursWalkUp ??
                            'Spontaneous only'),
                        subtitle: Text(l10n?.policyOutsideHoursWalkUpDesc ??
                            'Walk-up check-ins stay possible (evening '
                                'overtime included); booking ahead '
                                'outside the hours is refused.'),
                      ),
                      RadioListTile<OutsideHoursMode>(
                        key: const Key('policy-outside-hours-free'),
                        value: OutsideHoursMode.free,
                        title: Text(l10n?.policyOutsideHoursFree ?? 'Free'),
                        subtitle: Text(l10n?.policyOutsideHoursFreeDesc ??
                            'Allowed, never counted and never charged — '
                                'pure presence information.'),
                      ),
                      RadioListTile<OutsideHoursMode>(
                        key: const Key('policy-outside-hours-charged'),
                        value: OutsideHoursMode.charged,
                        title: Text(
                            l10n?.policyOutsideHoursCharged ?? 'Charged'),
                        subtitle: Text(
                            l10n?.policyOutsideHoursChargedDesc ??
                                'Allowed and counted like ordinary '
                                    'usage — except next to a regular '
                                    'booking the same day.'),
                      ),
                    ],
                  ),
                ),
                // #628 — how many overlapping bookings a member may hold.
                SimultaneousTile(
                  value: policies.simultaneousReservations,
                  onChanged: (v) => _setSimultaneous(context, ref, v),
                ),
                // #649 — the three numeric limits the server has enforced
                // since 0006 but nothing could set. Shown with the values
                // the server coalesces to, so an untouched workspace
                // displays what it actually does.
                SectionHeader(
                  l10n?.policyLimitsTitle ?? 'Booking limits',
                ),
                Padding(
                  padding: AppSpacing.lgH,
                  child: Text(
                    l10n?.policyLimitsDesc ??
                        'How far ahead a booking may be made, and how '
                            'short or long it may be. These hold on '
                            'every granularity.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                LimitTile(
                  keySuffix: 'horizon',
                  icon: Icons.event_available_outlined,
                  title: l10n?.policyHorizonTitle ??
                      'Advance booking horizon',
                  description: l10n?.policyHorizonDesc ??
                      'How many days ahead a booking may start.',
                  value: policies.advanceHorizonDays,
                  options: horizonOptions,
                  format: (v) => l10n?.policyDaysValue(v) ?? '$v days',
                  onChanged: (v) => _setLimit(context, ref,
                      BookingPolicies.advanceHorizonDaysKey, v),
                ),
                LimitTile(
                  keySuffix: 'min-duration',
                  icon: Icons.hourglass_bottom_outlined,
                  title: l10n?.policyMinDurationTitle ?? 'Minimum duration',
                  description: l10n?.policyMinDurationDesc ??
                      'The shortest booking accepted.',
                  value: policies.minDurationMinutes,
                  options: durationOptions,
                  format: (v) => formatDuration(l10n, v),
                  onChanged: (v) => _setLimit(context, ref,
                      BookingPolicies.minDurationMinutesKey, v),
                ),
                LimitTile(
                  keySuffix: 'max-duration',
                  icon: Icons.hourglass_top_outlined,
                  title: l10n?.policyMaxDurationTitle ?? 'Maximum duration',
                  description: l10n?.policyMaxDurationDesc ??
                      'The longest booking accepted.',
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
                      l10n?.policyDurationConflict ??
                          'The minimum cannot exceed the maximum — no '
                              'booking would be accepted.',
                      key: const Key('policy-duration-conflict'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
              ],
              SectionHeader(
                l10n?.availabilityClosureDays ?? 'Closure days',
              ),
              if (closures.isEmpty)
                Padding(
                  padding: AppSpacing.lgH,
                  child: Text(
                    l10n?.availabilityNoClosures ?? 'No closure days.',
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
                    tooltip: l10n?.commonDelete ?? 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeClosure(context, ref, closure),
                  ),
                ),
              const SizedBox(height: 80), // keep the FAB off the last row
            ],
          ),
        (AsyncError(), _, _) ||
        (_, AsyncError(), _) ||
        (_, _, AsyncError()) =>
          Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.availabilityAddClosure ?? 'Add closure day'),
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(
          labelText: l10n?.availabilityClosureReason ?? 'Reason (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
