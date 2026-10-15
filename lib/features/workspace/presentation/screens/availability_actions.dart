// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/work_hours.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/generate_public_holidays.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/booking_policies.dart';
import '../../domain/closure_day.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/public_holidays_sheet.dart';

/// The availability editor's writes (#127, #446, #600, #628, #649, #2313):
/// each asks the repository for one change and invalidates the provider that
/// shows it, or tells the person it failed. Split out of the screen (#2494);
/// it holds the build [context] and [ref] it was made for.
class AvailabilityActions {
  const AvailabilityActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  Future<void> toggleWeekday(
    List<int> open,
    int weekday, {
    required bool selected,
  }) async {
    final l10n = context.l10n;
    if (!selected && open.length <= 1) {
      AppSnack.error(context, l10n.availabilityLastOpenDay);
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
      TraceLogger.instance.error(
        'workspace',
        'set open weekdays failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(openWeekdaysProvider);
  }

  Future<void> setGranularity(BookingGranularity? granularity) async {
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
      TraceLogger.instance.error(
        'workspace',
        'set booking granularity failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(bookingGranularityProvider);
  }

  Future<void> setWorkHours(WorkHours hours) async {
    final l10n = context.l10n;
    if (!hours.isValid) {
      AppSnack.error(context, l10n.availabilityWorkHoursInvalid);
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
      TraceLogger.instance.error(
        'workspace',
        'set work hours failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(workHoursProvider);
  }

  Future<void> setPolicy(String key, {required bool enabled}) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingPolicy(workspace.id, key, enabled: enabled);
    } on Object catch (e, st) {
      debugPrint('set booking policy failed: $e\n$st');
      TraceLogger.instance.error(
        'workspace',
        'set booking policy failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  Future<void> setOutsideHoursMode(OutsideHoursMode? mode) async {
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
      TraceLogger.instance.error(
        'workspace',
        'set outside-hours mode failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  /// #628 — the workspace default for simultaneous reservations, through
  /// the same merge-preserving booking_rules write as the other policies.
  Future<void> setSimultaneous(int value) async {
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
        'workspace',
        'set simultaneous reservations failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  /// #649 — one writer for all three numeric limits; the key decides
  /// which. Same merge-preserving booking_rules write as every other
  /// policy, so the other keys survive untouched.
  Future<void> setLimit(String key, int value) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setBookingLimit(workspace.id, key, value);
    } on Object catch (e, st) {
      debugPrint('set booking limit failed: $e\n$st');
      TraceLogger.instance.error(
        'workspace',
        'set booking limit failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(bookingPoliciesProvider);
  }

  Future<void> pickWorkTime(
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
    await setWorkHours(apply(picked.hour * 60 + picked.minute));
  }

  Future<void> addClosure() async {
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
      builder: (context) => const ReasonDialog(),
    );
    if (reason == null) return; // cancelled

    try {
      await ref
          .read(workspaceRepositoryProvider)
          .addClosureDay(workspace.id, day, reason.trim());
    } on Object catch (e, st) {
      debugPrint('add closure day failed: $e\n$st');
      TraceLogger.instance.error(
        'workspace',
        'add closure day failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(closureDaysProvider);
  }

  Future<void> removeClosure(ClosureDay closure) async {
    final l10n = context.l10n;
    try {
      await ref.read(workspaceRepositoryProvider).removeClosureDay(closure.id);
    } on Object catch (e, st) {
      debugPrint('remove closure day failed: $e\n$st');
      TraceLogger.instance.error(
        'workspace',
        'remove closure day failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _showGenericError(l10n);
      return;
    }
    ref.invalidate(closureDaysProvider);
  }

  /// Opens the public-holidays generator. The screen already holds the
  /// repository for its own closure-day writes; the sheet is handed the
  /// decision rather than reaching for one itself (ADR 0024).
  void showPublicHolidays() => unawaited(
    showPublicHolidaysSheet(
      context,
      PublicHolidayGeneration(ref.read(workspaceRepositoryProvider)),
    ),
  );

  void _showGenericError(AppLocalizations l10n) {
    AppSnack.error(context, l10n.workspaceGenericError);
  }
}

/// Asks for the reason of a closure day.
class ReasonDialog extends StatefulWidget {
  const ReasonDialog({super.key});

  @override
  State<ReasonDialog> createState() => ReasonDialogState();
}

class ReasonDialogState extends State<ReasonDialog> {
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
        decoration: InputDecoration(labelText: l10n.availabilityClosureReason),
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
