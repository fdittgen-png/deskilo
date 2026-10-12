// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'availability_screen.dart';

// #2386 — part 1 of AvailabilityScreen, split out of availability_screen.dart so no
// file holds the whole class.
extension _AvailabilityScreenPart1 on AvailabilityScreen {

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
}
