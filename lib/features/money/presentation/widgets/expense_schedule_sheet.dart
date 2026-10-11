// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/schedule_expense.dart';
import '../../domain/expense_schedule.dart';
import '../../providers/expense_schedule_providers.dart';
import '../../providers/money_providers.dart';

/// #767 — the localized wording of one recurrence rule: "every 2 weeks,
/// 12 times", "monthly until 31.12.2026", "every 10 days".
String _scheduleRuleText(
  AppLocalizations l10n,
  ExpenseSchedule s,
  DateFormat dates,
) {
  final unit = switch (s.unit) {
    ScheduleUnit.day =>
      s.every == 1 ? (l10n.scheduleDaily) : null,
    ScheduleUnit.week =>
      s.every == 1 ? (l10n.scheduleWeekly) : null,
    ScheduleUnit.month =>
      s.every == 1 ? (l10n.scheduleMonthly) : null,
    ScheduleUnit.year =>
      s.every == 1 ? (l10n.scheduleYearly) : null,
  };
  final everyText = unit ??
      switch (s.unit) {
        ScheduleUnit.day =>
          l10n.scheduleEveryDays(s.every),
        ScheduleUnit.week =>
          l10n.scheduleEveryWeeks(s.every),
        ScheduleUnit.month =>
          l10n.scheduleEveryMonths(s.every),
        ScheduleUnit.year =>
          l10n.scheduleEveryMonths(s.every * 12),
      };
  return [
    everyText,
    if (s.repeatCount != null)
      l10n.scheduleTimes(s.repeatCount!),
    if (s.endsOn != null)
      l10n.scheduleUntil(dates.format(s.endsOn!)),
  ].join(' · ');
}

/// The list of MY schedules with their state, and the door to a new one.
Future<void> showExpenseSchedulesSheet(
  BuildContext context,
  WidgetRef ref,
  MoneyFormat currency,
) async {
  final l10n = context.l10n;
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
          title: l10n.scheduledExpensesTitle,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  l10n.scheduledExpensesIntro,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              HelpDot(
                l10n.helpTopicScheduledExpenses,
                anchor: HelpAnchor.expenseSchedule,
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            if (schedules.isEmpty)
              Padding(
                padding: AppSpacing.mdAll,
                child: Text(
                  l10n.scheduledExpensesEmpty,
                ),
              ),
            // #1059 — the list answers "what does the space pay for", and a
            // rejected or ended schedule is not something the space pays
            // for: it can never produce another due date. Left in place it
            // sat beside the live one, same title, same amount, differing
            // only by a cadence you had to read carefully.
            //
            // Hidden, not destroyed: a rejection is a decision with a
            // validator behind it and belongs in the record.
            for (final s in schedules.where(_stillFires))
              ListTile(
                key: ValueKey('schedule-${s.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(s.title),
                subtitle: Text(
                  '${currency.formatMinor(s.amountCents)} · '
                  '${_scheduleRuleText(l10n, s, dates)}\n'
                  '${_statusText(l10n, s.status)}'
                  '${s.nextDue != null ? ' · ${l10n.scheduleNextDue(dates.format(s.nextDue!))}' : ''}',
                ),
                isThreeLine: true,
                trailing: canEndSchedule(s.status)
                    ? IconButton(
                        key: ValueKey('schedule-cancel-${s.id}'),
                        tooltip: l10n.scheduleCancel,
                        icon: const Icon(Icons.stop_circle_outlined),
                        onPressed: () async {
                          final ok = await runGuarded(
                            context,
                            domain: 'money',
                            message: 'cancel expense schedule failed',
                            errorText: l10n.workspaceGenericError,
                            action: () =>
                                ref.read(expenseScheduleCommandProvider).end(s),
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
                  l10n.scheduleNew),
              onPressed: () async {
                final created =
                    await _showCreateExpenseScheduleSheet(context, ref, currency);
                if (created && context.mounted) {
                  ref.invalidate(expenseSchedulesProvider(workspace.id));
                }
              },
            ),
            if (schedules.where((s) => !_stillFires(s)).isNotEmpty)
              ExpansionTile(
                key: const ValueKey('schedule-finished'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  l10n.scheduledExpensesFinished(
                          schedules.where((s) => !_stillFires(s)).length),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                children: [
                  for (final s in schedules.where((s) => !_stillFires(s)))
                    ListTile(
                      key: ValueKey('schedule-${s.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.title),
                      subtitle: Text(
                        '${currency.formatMinor(s.amountCents)} · '
                        '${_scheduleRuleText(l10n, s, dates)}\n'
                        '${_statusText(l10n, s.status)}',
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

/// Whether [s] can still produce a due date.
///
/// `rejected` and `ended` never will: the first was refused by the
/// validators, the second was stopped. Both belong in the record and
/// neither belongs in the list of what the space pays for.
bool _stillFires(ExpenseSchedule s) =>
    s.status == ScheduleStatus.pending || s.status == ScheduleStatus.active;

String _statusText(AppLocalizations l10n, ScheduleStatus status) =>
    switch (status) {
      ScheduleStatus.pending =>
        l10n.scheduleStatusPending,
      ScheduleStatus.active => l10n.scheduleStatusActive,
      ScheduleStatus.rejected => l10n.scheduleStatusRejected,
      ScheduleStatus.ended => l10n.scheduleStatusEnded,
    };

/// The creation form: what, how much, from when, how often, how long.
Future<bool> _showCreateExpenseScheduleSheet(
  BuildContext context,
  WidgetRef ref,
  MoneyFormat currency,
) async {
  final l10n = context.l10n;
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
  final topic = l10n.helpTopicScheduledExpenses;

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SheetShell(
        title: l10n.scheduleNew,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: HelpDot(topic, anchor: HelpAnchor.expenseSchedule),
          ),
          TextField(
            key: const ValueKey('schedule-title'),
            controller: title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.scheduleTitleLabel,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('schedule-amount'),
            controller: amount,
            decoration: InputDecoration(
              labelText: l10n.moneyAmountLabel,
              suffixText: currency.currencyName,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            decoration: InputDecoration(
              labelText: l10n.moneyDescriptionLabel,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const ValueKey('schedule-starts'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.scheduleStartsOn),
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
                  labelText: l10n.scheduleEveryLabel,
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
                  labelText: l10n.scheduleUnitLabel,
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
              labelText: l10n.scheduleTimesLabel,
            ),
            keyboardType: TextInputType.number,
          ),
          ListTile(
            key: const ValueKey('schedule-ends'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.scheduleEndsOn),
            subtitle: Text(endsOn == null
                ? (l10n.scheduleNoEnd)
                : dates.format(endsOn!)),
            trailing: endsOn == null
                ? const Icon(Icons.edit_calendar_outlined)
                : IconButton(
                  key: const ValueKey('expense-schedule-sheet-a11y-clear-date'),
                  tooltip: l10n.a11yClearDate,
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
            l10n.scheduleValidationHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('schedule-submit'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.scheduleSubmit),
          ),
        ],
      ),
    ),
  );
  if (submitted != true || !context.mounted) return false;
  final cents = parseCentsInput(amount.text);
  // #1449 — the command refuses it and writes nothing; the sheet says so.
  if (!isSchedulable(title: title.text, amountCents: cents)) {
    AppSnack.error(
        context, l10n.scheduleMissingFields);
    return false;
  }
  final ok = await runGuarded(
    context,
    domain: 'money',
    message: 'create expense schedule failed',
    errorText:
        l10n.workspaceGenericError,
    action: () => ref.read(expenseScheduleCommandProvider).schedule(
          workspaceId: workspace.id,
          title: title.text,
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
    l10n.schedulePending,
  );
  ref.invalidate(eventsProvider);
  return true;
}

String _unitText(AppLocalizations l10n, ScheduleUnit u) => switch (u) {
      ScheduleUnit.day => l10n.scheduleUnitDays,
      ScheduleUnit.week => l10n.scheduleUnitWeeks,
      ScheduleUnit.month => l10n.scheduleUnitMonths,
      ScheduleUnit.year => l10n.scheduleUnitYears,
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
      text: centsToMajor(widget.occurrence.amountCents)); // #1140
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
    final l10n = context.l10n;
    final o = widget.occurrence;
    final scheduled = o.scheduledAmountCents;
    final cents = parseCentsInput(_amount.text);
    final rejected = o.status == OccurrenceStatus.rejected;
    // #1449 — the rule the command applies, read here to show the field.
    final explain = needsExplanation(o, cents);
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
                l10n.helpTopicScheduledExpenses,
                anchor: HelpAnchor.expenseSchedule,
              ),
            ]),
            if (rejected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.occurrenceRejected,
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
                labelText: l10n.moneyAmountLabel,
                suffixText: widget.currency.currencyName,
                helperText: scheduled == null
                    ? null
                    : (l10n.occurrenceScheduledAmount(
                            widget.currency.formatMinor(scheduled))),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            if (explain) ...[
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('occurrence-reason-${o.id}'),
                controller: _reason,
                decoration: InputDecoration(
                  labelText: l10n.occurrenceReasonLabel,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: ValueKey('occurrence-confirm-${o.id}'),
                onPressed: _confirm,
                child: Text(rejected
                    ? (l10n.occurrenceResend)
                    : (l10n.occurrenceConfirm)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// #1449 — the command decides what this amount means and refuses the
  /// write the rule forbids; the sheet says which answer it was.
  Future<void> _confirm() async {
    final l10n = context.l10n;
    final workspaceId = widget.occurrence.workspaceId;
    OccurrenceAnswer? answer;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'confirm expense occurrence failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        answer = await ref.read(expenseScheduleCommandProvider).answer(
              occurrence: widget.occurrence,
              amountCents: parseCentsInput(_amount.text),
              reason: _reason.text,
            );
      },
    );
    if (!ok || !mounted) return;
    switch (answer) {
      case OccurrenceAnswer.noAmount || null:
        return;
      case OccurrenceAnswer.explanationMissing:
        AppSnack.error(context,
            l10n.occurrenceReasonMissing);
        return;
      case OccurrenceAnswer.forValidation:
        AppSnack.success(context,
            l10n.occurrenceSentForValidation);
      case OccurrenceAnswer.settled:
        AppSnack.success(
            context, l10n.occurrenceAdded);
    }
    ref
      ..invalidate(expenseOccurrencesProvider(workspaceId))
      ..invalidate(eventsProvider);
  }
}
