// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/closure_day.dart';
import '../../providers/workspace_providers.dart';

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

  Future<void> _addClosure(BuildContext context, WidgetRef ref) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = AppLocalizations.of(context);

    final now = DateTime.now();
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
              _SectionHeader(
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
              _SectionHeader(
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
                      value: BookingGranularity.halfDay,
                      title: Text(
                        l10n?.availabilityGranularityHalfDay ??
                            'Half days (morning & afternoon)',
                      ),
                    ),
                  ],
                ),
              ),
              _SectionHeader(
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Optional closure reason. Pops null on cancel (aborts the add) and the
/// (possibly empty) text on save.
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
