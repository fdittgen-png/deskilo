// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/expense_schedule.dart';
import '../../providers/expense_schedule_providers.dart';
import '../../providers/money_providers.dart';

/// #767 — the localized wording of one recurrence rule: "every 2 weeks,
/// 12 times", "monthly until 31.12.2026", "every 10 days".
String scheduleRuleText(
  AppLocalizations? l10n,
  ExpenseSchedule s,
  DateFormat dates,
) {
  final unit = switch (s.unit) {
    ScheduleUnit.day =>
      s.every == 1 ? (l10n?.scheduleDaily ?? 'daily') : null,
    ScheduleUnit.week =>
      s.every == 1 ? (l10n?.scheduleWeekly ?? 'weekly') : null,
    ScheduleUnit.month =>
      s.every == 1 ? (l10n?.scheduleMonthly ?? 'monthly') : null,
    ScheduleUnit.year =>
      s.every == 1 ? (l10n?.scheduleYearly ?? 'yearly') : null,
  };
  final everyText = unit ??
      switch (s.unit) {
        ScheduleUnit.day =>
          l10n?.scheduleEveryDays(s.every) ?? 'every ${s.every} days',
        ScheduleUnit.week =>
          l10n?.scheduleEveryWeeks(s.every) ?? 'every ${s.every} weeks',
        ScheduleUnit.month =>
          l10n?.scheduleEveryMonths(s.every) ?? 'every ${s.every} months',
        ScheduleUnit.year =>
          l10n?.scheduleEveryMonths(s.every * 12) ??
              'every ${s.every * 12} months',
      };
  return [
    everyText,
    if (s.repeatCount != null)
      l10n?.scheduleTimes(s.repeatCount!) ?? '${s.repeatCount} times',
    if (s.endsOn != null)
      l10n?.scheduleUntil(dates.format(s.endsOn!)) ??
          'until ${dates.format(s.endsOn!)}',
  ].join(' · ');
}

/// The list of MY schedules with their state, and the door to a new one.
Future<void> showExpenseSchedulesSheet(
  BuildContext context,
  WidgetRef ref,
  MoneyFormat currency,
) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  final dates = DateFormat.yMMMd();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final schedules =
            ref.watch(expenseSchedulesProvider(workspace.id)).value ??
                const <ExpenseSchedule>[];
        return SheetShell(
          title: l10n?.scheduledExpensesTitle ?? 'Scheduled expenses',
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  l10n?.scheduledExpensesIntro ??
                      'Subscriptions the space pays for — internet, phone, '
                          'electricity. The schedule is validated once; every '
                          'due date is presented to you before it counts.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              HelpDot(l10n?.helpTopicScheduledExpenses ?? 'Scheduled expenses'),
            ]),
            const SizedBox(height: AppSpacing.sm),
            if (schedules.isEmpty)
              Padding(
                padding: AppSpacing.mdAll,
                child: Text(
                  l10n?.scheduledExpensesEmpty ?? 'No scheduled expense yet.',
                ),
              ),
            for (final s in schedules)
              ListTile(
                key: ValueKey('schedule-${s.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(s.title),
                subtitle: Text(
                  '${currency.formatMinor(s.amountCents)} · '
                  '${scheduleRuleText(l10n, s, dates)}\n'
                  '${_statusText(l10n, s.status)}'
                  '${s.nextDue != null ? ' · ${l10n?.scheduleNextDue(dates.format(s.nextDue!)) ?? 'next: ${dates.format(s.nextDue!)}'}' : ''}',
                ),
                isThreeLine: true,
                trailing: s.status == ScheduleStatus.pending ||
                        s.status == ScheduleStatus.active
                    ? IconButton(
                        key: ValueKey('schedule-cancel-${s.id}'),
                        tooltip: l10n?.scheduleCancel ?? 'End this schedule',
                        icon: const Icon(Icons.stop_circle_outlined),
                        onPressed: () async {
                          final ok = await runGuarded(
                            context,
                            domain: 'money',
                            message: 'cancel expense schedule failed',
                            errorText: l10n?.workspaceGenericError ??
                                'Something went wrong. Please try again.',
                            action: () => ref
                                .read(moneyRepositoryProvider)
                                .cancelExpenseSchedule(s.id),
                          );
                          if (ok) {
                            ref.invalidate(
                                expenseSchedulesProvider(workspace.id));
                          }
                        },
                      )
                    : null,
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('schedule-new'),
              icon: const Icon(Icons.event_repeat_outlined),
              label: Text(
                  l10n?.scheduleNew ?? 'Schedule a recurring expense'),
              onPressed: () async {
                final created =
                    await showCreateExpenseScheduleSheet(context, ref, currency);
                if (created && context.mounted) {
                  ref.invalidate(expenseSchedulesProvider(workspace.id));
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

String _statusText(AppLocalizations? l10n, ScheduleStatus status) =>
    switch (status) {
      ScheduleStatus.pending =>
        l10n?.scheduleStatusPending ?? 'Awaiting validation',
      ScheduleStatus.active => l10n?.scheduleStatusActive ?? 'Active',
      ScheduleStatus.rejected => l10n?.scheduleStatusRejected ?? 'Rejected',
      ScheduleStatus.ended => l10n?.scheduleStatusEnded ?? 'Ended',
    };

/// The creation form: what, how much, from when, how often, how long.
Future<bool> showCreateExpenseScheduleSheet(
  BuildContext context,
  WidgetRef ref,
  MoneyFormat currency,
) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return false;
  final dates = DateFormat.yMMMd();
  final title = TextEditingController();
  final amount = TextEditingController();
  final description = TextEditingController();
  final every = TextEditingController(text: '1');
  final times = TextEditingController();
  var unit = ScheduleUnit.month;
  final now = ref.read(clockProvider).now();
  var startsOn = now;
  DateTime? endsOn;
  final topic = l10n?.helpTopicScheduledExpenses ?? 'Scheduled expenses';

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SheetShell(
        title: l10n?.scheduleNew ?? 'Schedule a recurring expense',
        children: [
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('schedule-title'),
            controller: title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n?.scheduleTitleLabel ?? 'What (e.g. Internet)',
              suffixIcon: HelpDot(topic),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('schedule-amount'),
            controller: amount,
            decoration: InputDecoration(
              labelText: l10n?.moneyAmountLabel ?? 'Amount',
              suffixText: currency.currencyName,
              suffixIcon: HelpDot(topic),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            decoration: InputDecoration(
              labelText: l10n?.moneyDescriptionLabel ?? 'Description',
              suffixIcon: HelpDot(topic),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const ValueKey('schedule-starts'),
            contentPadding: EdgeInsets.zero,
            title: HelpDotTitle(
                l10n?.scheduleStartsOn ?? 'First occurrence', topic),
            subtitle: Text(dates.format(startsOn)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startsOn,
                firstDate: now.subtract(const Duration(days: 366)),
                lastDate: now.add(const Duration(days: 730)),
              );
              if (picked != null) setSheetState(() => startsOn = picked);
            },
          ),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('schedule-every'),
                controller: every,
                decoration: InputDecoration(
                  labelText: l10n?.scheduleEveryLabel ?? 'Every',
                  suffixIcon: HelpDot(topic),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<ScheduleUnit>(
                key: const ValueKey('schedule-unit'),
                initialValue: unit,
                decoration: InputDecoration(
                  labelText: l10n?.scheduleUnitLabel ?? 'Unit',
                ),
                items: [
                  for (final u in ScheduleUnit.values)
                    DropdownMenuItem(value: u, child: Text(_unitText(l10n, u))),
                ],
                onChanged: (v) => setSheetState(() => unit = v ?? unit),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('schedule-times'),
            controller: times,
            decoration: InputDecoration(
              labelText: l10n?.scheduleTimesLabel ??
                  'Repetitions (empty = until the end date)',
              suffixIcon: HelpDot(topic),
            ),
            keyboardType: TextInputType.number,
          ),
          ListTile(
            key: const ValueKey('schedule-ends'),
            contentPadding: EdgeInsets.zero,
            title: HelpDotTitle(
                l10n?.scheduleEndsOn ?? 'Until (optional)', topic),
            subtitle: Text(endsOn == null
                ? (l10n?.scheduleNoEnd ?? 'No end date')
                : dates.format(endsOn!)),
            trailing: endsOn == null
                ? const Icon(Icons.edit_calendar_outlined)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setSheetState(() => endsOn = null),
                  ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: endsOn ?? startsOn.add(const Duration(days: 365)),
                firstDate: startsOn,
                lastDate: startsOn.add(const Duration(days: 3650)),
              );
              if (picked != null) setSheetState(() => endsOn = picked);
            },
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.scheduleValidationHint ??
                'The schedule goes to the validators first. Each due date is '
                    'then presented to you: confirmed at this amount it counts '
                    'immediately; a different amount explains itself and is '
                    'validated again.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('schedule-submit'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.scheduleSubmit ?? 'Schedule it'),
          ),
        ],
      ),
    ),
  );
  if (submitted != true || !context.mounted) return false;
  final cents = parseCentsInput(amount.text);
  if (cents == null || cents <= 0 || title.text.trim().isEmpty) {
    AppSnack.error(
        context, l10n?.scheduleMissingFields ?? 'Name and amount are needed.');
    return false;
  }
  final ok = await runGuarded(
    context,
    domain: 'money',
    message: 'create expense schedule failed',
    errorText:
        l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).createExpenseSchedule(
          workspaceId: workspace.id,
          title: title.text.trim(),
          amountCents: cents,
          startsOn: startsOn,
          unit: unit,
          every: int.tryParse(every.text) ?? 1,
          repeatCount: int.tryParse(times.text),
          endsOn: endsOn,
          description: description.text.trim(),
        ),
  );
  if (!ok || !context.mounted) return false;
  AppSnack.success(
    context,
    l10n?.schedulePending ??
        'Scheduled — waiting for the validators to confirm it.',
  );
  ref.invalidate(eventsProvider);
  return true;
}

String _unitText(AppLocalizations? l10n, ScheduleUnit u) => switch (u) {
      ScheduleUnit.day => l10n?.scheduleUnitDays ?? 'days',
      ScheduleUnit.week => l10n?.scheduleUnitWeeks ?? 'weeks',
      ScheduleUnit.month => l10n?.scheduleUnitMonths ?? 'months',
      ScheduleUnit.year => l10n?.scheduleUnitYears ?? 'years',
    };

/// One presented occurrence on the Payments face: due date, amount
/// (editable), the mandatory explanation when it differs, confirm — and
/// the rejected state with its resend.
class ExpenseOccurrenceCard extends ConsumerStatefulWidget {
  const ExpenseOccurrenceCard(this.occurrence, this.currency, {super.key});

  final ExpenseOccurrence occurrence;
  final MoneyFormat currency;

  @override
  ConsumerState<ExpenseOccurrenceCard> createState() =>
      _ExpenseOccurrenceCardState();
}

class _ExpenseOccurrenceCardState extends ConsumerState<ExpenseOccurrenceCard> {
  late final TextEditingController _amount = TextEditingController(
      text: (widget.occurrence.amountCents / 100).toStringAsFixed(2));
  final _reason = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final o = widget.occurrence;
    final scheduled = o.scheduledAmountCents;
    final cents = parseCentsInput(_amount.text);
    final differs = scheduled != null && cents != null && cents != scheduled;
    final rejected = o.status == OccurrenceStatus.rejected;
    final dates = DateFormat.yMMMd();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('occurrence-${o.id}'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                rejected
                    ? Icons.replay_circle_filled_outlined
                    : Icons.event_repeat_outlined,
                size: 18,
                color: rejected ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${o.scheduleTitle} · ${dates.format(o.dueOn)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              HelpDot(
                  l10n?.helpTopicScheduledExpenses ?? 'Scheduled expenses'),
            ]),
            if (rejected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n?.occurrenceRejected ??
                      'The validators rejected it — adjust the amount or the '
                          'description and resend.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('occurrence-amount-${o.id}'),
              controller: _amount,
              decoration: InputDecoration(
                labelText: l10n?.moneyAmountLabel ?? 'Amount',
                suffixText: widget.currency.currencyName,
                helperText: scheduled == null
                    ? null
                    : (l10n?.occurrenceScheduledAmount(
                            widget.currency.formatMinor(scheduled)) ??
                        'Validated: ${widget.currency.formatMinor(scheduled)}'),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            if (differs || rejected) ...[
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('occurrence-reason-${o.id}'),
                controller: _reason,
                decoration: InputDecoration(
                  labelText: l10n?.occurrenceReasonLabel ??
                      'Why it differs (required)',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: ValueKey('occurrence-confirm-${o.id}'),
                onPressed: () => _confirm(differs || rejected),
                child: Text(rejected
                    ? (l10n?.occurrenceResend ?? 'Resend for validation')
                    : (l10n?.occurrenceConfirm ?? 'Confirm this expense')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(bool needsReason) async {
    final l10n = AppLocalizations.of(context);
    final cents = parseCentsInput(_amount.text);
    if (cents == null || cents <= 0) return;
    if (needsReason && _reason.text.trim().isEmpty) {
      AppSnack.error(
        context,
        l10n?.occurrenceReasonMissing ??
            'A different amount needs an explanation.',
      );
      return;
    }
    final workspaceId = widget.occurrence.workspaceId;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'confirm expense occurrence failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).confirmExpenseOccurrence(
            occurrenceId: widget.occurrence.id,
            amountCents: cents,
            reason: _reason.text.trim(),
          ),
    );
    if (!ok || !mounted) return;
    AppSnack.success(
      context,
      needsReason
          ? (l10n?.occurrenceSentForValidation ??
              'Sent to the validators — it counts once they confirm.')
          : (l10n?.occurrenceAdded ?? 'Added to your expenses.'),
    );
    ref
      ..invalidate(expenseOccurrencesProvider(workspaceId))
      ..invalidate(eventsProvider);
  }
}
