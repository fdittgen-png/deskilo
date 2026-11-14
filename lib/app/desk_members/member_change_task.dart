// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — change of plan, pause and resume as a short task, for one member
// or a selection: it applies member by member (member_batch_change.dart) and
// then lists each member with what became of them.
// #3858 — a change of plan takes its date (as soon as possible, or from the
// first of a month) and a pause its days (from, and until or until
// resumed); a resume applies from today. Before it is applied, the task
// says in words what the change means in money for one member: the first
// statement a share shows on; the months a pause leaves charged and the
// months it frees, and the bookings that fall in them. After it, each
// member's line says the date, a refused date the earliest it can take, and
// a pause what the server answered.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/ids/request_id.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../core/ui/adaptive/task_choice.dart';
import '../../core/ui/adaptive/task_surface.dart';
import '../../core/ui/date_field.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/member_term_answer.dart';
import '../../features/workspace/domain/member_term_change.dart';
import '../../features/workspace/providers/member_term_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import 'member_batch_change.dart';
import 'member_terms_view.dart';

/// Opens the task that applies [change] to [members]; a [ChangePlan] asks
/// for the share first (its own share is ignored).
Future<void> showMemberChangeTask(
  BuildContext context, {
  required List<Member> members,
  required MemberChange change,
}) => showTask<void>(
  context,
  size: TaskSize.short,
  builder: (_) => _MemberChangeTask(members: members, change: change),
);

/// The words for [outcome].
String _outcomeText(
  AppLocalizations l,
  AppFormat format,
  MemberChangeResult result,
) {
  final day = format.dates(DateShape.numeric).format;
  return switch (result.outcome) {
    MemberChangeOutcome.applied => l.membersOutcomeApplied,
    MemberChangeOutcome.scheduled => switch (result.answer?.effectiveOn) {
      final on? => l.membersOutcomeScheduled(day(on)),
      null => l.memberTermScheduled,
    },
    MemberChangeOutcome.held => l.memberTermPending,
    MemberChangeOutcome.dateRefused => switch (result.earliest) {
      final on? => l.membersOutcomeEarliest(day(on)),
      null => l.membersOutcomeFailed,
    },
    MemberChangeOutcome.unchanged => l.membersOutcomeUnchanged,
    MemberChangeOutcome.pending => l.membersOutcomePending,
    MemberChangeOutcome.exited => l.membersOutcomeExited,
    MemberChangeOutcome.kiosk => l.membersOutcomeKiosk,
    MemberChangeOutcome.wrongStatus => l.membersOutcomeWrongStatus,
    MemberChangeOutcome.ruleRefused => l.membersOutcomeRuleRefused,
    MemberChangeOutcome.gone => l.membersOutcomeGone,
    MemberChangeOutcome.failed => l.membersOutcomeFailed,
  };
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// What the task is set to: the share, its date, the pause's days.
class _Draft {
  int? share;

  /// The month a share takes effect from; null: as soon as possible.
  DateTime? month;
  DateTime? from;
  DateTime? until;
}

class _MemberChangeTask extends ConsumerStatefulWidget {
  const _MemberChangeTask({required this.members, required this.change});

  final List<Member> members;
  final MemberChange change;

  @override
  ConsumerState<_MemberChangeTask> createState() => _MemberChangeTaskState();
}

class _MemberChangeTaskState extends ConsumerState<_MemberChangeTask> {
  final _draft = _Draft();
  bool _running = false;
  Map<String, MemberChangeResult>? _results;

  String _title(AppLocalizations l) {
    final n = widget.members.length;
    return switch (widget.change) {
      ChangePlan() => l.membersBulkPlan(n),
      PauseMembers() => l.membersBulkPause(n),
      ResumeMembers() => l.membersBulkResume(n),
    };
  }

  void _edit(void Function(_Draft d) change) =>
      setState(() => change(_draft));

  Future<void> _apply(DateTime today) async {
    final change = switch (widget.change) {
      ChangePlan() => ChangePlan(_draft.share!, on: _draft.month),
      PauseMembers() => PauseMembers(
        from: _draft.from ?? today,
        until: _draft.until,
      ),
      final other => other,
    };
    setState(() => _running = true);
    final results = await applyMemberChange(_Commands(ref), [
      for (final m in widget.members) m.id,
    ], change);
    if (!mounted) return;
    ref
      ..invalidate(workspaceMembersProvider)
      ..invalidate(memberTermChangesProvider);
    setState(() {
      _running = false;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final names = ref.watch(memberNamesProvider).value ?? const {}; // empty-ok: an unread name shows blank, the outcome still shows
    final today = _dayOf(ref.watch(clockProvider).now());
    final results = _results;
    final change = widget.change;
    final offered =
        ref.watch(subscriptionLevelsProvider).value?.offeredLevels ??
        const <int>[]; // empty-ok: no level offered until read
    // One member: the money is said before the change is applied.
    final single = widget.members.length == 1 ? widget.members.single : null;
    final invoiced = single == null
        ? const <DateTime>{}
        : ref.watch(memberInvoicedMonthsProvider).value?[single.id] ??
              const <DateTime>{}; // empty-ok: before they are read, no month counts as invoiced
    final earliest = earliestShareDay(today, invoiced);
    final ready =
        !_running && (change is! ChangePlan || _draft.share != null);
    return TaskChoice(
      title: _title(l),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (results == null) ...switch (change) {
            ChangePlan() => _planFields(l, format, offered, earliest),
            PauseMembers() => _pauseFields(l, today),
            ResumeMembers() => [
              Text(
                l.membersChangeFromToday(
                  format.dates(DateShape.longDate).format(today),
                ),
                key: const ValueKey('member-change-from-today'),
              ),
            ],
          },
          if (results == null && single != null)
            ..._preview(l, format, single, today, earliest, invoiced),
          if (results != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l.membersChangeDone(
                results.values
                    .where(
                      (r) =>
                          r.outcome == MemberChangeOutcome.applied ||
                          r.outcome == MemberChangeOutcome.scheduled,
                    )
                    .length,
                results.length,
              ),
              key: const ValueKey('member-change-done'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final m in widget.members)
              ListTile(
                key: ValueKey('member-change-outcome-${m.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(names[m.id] ?? ''),
                subtitle: Text(
                  _resultLines(
                    l,
                    format,
                    today,
                    results[m.id] ??
                        const MemberChangeResult(MemberChangeOutcome.gone),
                  ).join('\n'),
                ),
              ),
          ],
        ],
      ),
      actions: [
        if (results == null) ...[
          TextButton(
            key: const ValueKey('member-change-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('member-change-apply'),
            onPressed: ready ? () => _apply(today) : null,
            child: Text(l.membersChangeApply),
          ),
        ] else
          FilledButton(
            key: const ValueKey('member-change-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonClose),
          ),
      ],
    );
  }

  /// The share, and the month it takes effect from.
  List<Widget> _planFields(
    AppLocalizations l,
    AppFormat format,
    List<int> offered,
    DateTime earliest,
  ) {
    final month = _draft.month;
    final material = MaterialLocalizations.of(context);
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final pct in [0, ...offered])
            ChoiceChip(
              key: ValueKey('member-change-share-$pct'),
              label: Text(
                pct == 0 ? l.memberNoSubscription : format.ratePercent(pct),
              ),
              selected: _draft.share == pct,
              onSelected: (_) => _edit((d) => d.share = pct),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Text(l.membersChangeWhen, style: Theme.of(context).textTheme.titleSmall),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          ChoiceChip(
            key: const ValueKey('member-change-soonest'),
            label: Text(l.membersChangeSoonest),
            selected: month == null,
            onSelected: (_) => _edit((d) => d.month = null),
          ),
          ChoiceChip(
            key: const ValueKey('member-change-from-month'),
            label: Text(l.membersChangeFromMonth),
            selected: month != null,
            onSelected: (_) => _edit(
              (d) => d.month = DateTime(earliest.year, earliest.month + 1),
            ),
          ),
        ],
      ),
      if (month != null)
        Row(
          children: [
            IconButton(
              key: const ValueKey('member-change-month-earlier'),
              tooltip: material.previousMonthTooltip,
              icon: const Icon(Icons.chevron_left),
              onPressed: month.isAfter(earliest)
                  ? () => _edit(
                      (d) => d.month = DateTime(month.year, month.month - 1),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                format.dates(DateShape.longDate).format(month),
                key: const ValueKey('member-change-month'),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: const ValueKey('member-change-month-later'),
              tooltip: material.nextMonthTooltip,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _edit(
                (d) => d.month = DateTime(month.year, month.month + 1),
              ),
            ),
          ],
        ),
    ];
  }

  /// The days of the pause: from, and until (empty: until resumed).
  List<Widget> _pauseFields(AppLocalizations l, DateTime today) {
    final from = _draft.from ?? today;
    return [
      AppDateField(
        key: const ValueKey('member-change-pause-from'),
        label: l.membersPauseFrom,
        value: from,
        first: today,
        last: DateTime(today.year + 3),
        isRequired: true,
        onChanged: (read) => _edit((d) => d.from = read.date ?? d.from),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppDateField(
        key: const ValueKey('member-change-pause-until'),
        label: l.membersPauseUntil,
        helper: l.membersPauseUntilHelper,
        value: _draft.until,
        first: from.add(const Duration(days: 1)),
        last: DateTime(today.year + 3),
        onChanged: (read) => _edit((d) => d.until = read.date),
      ),
    ];
  }

  /// What the change means for [member] before it is applied.
  List<Widget> _preview(
    AppLocalizations l,
    AppFormat format,
    Member member,
    DateTime today,
    DateTime earliest,
    Set<DateTime> invoiced,
  ) {
    final lines = <String>[
      ...switch (widget.change) {
        ChangePlan() => [
          if (_draft.share case final pct?)
            memberShareText(l, format, pct, _draft.month ?? earliest, invoiced),
        ],
        PauseMembers() => [
          memberPauseMoneyText(
            l,
            format,
            _draft.from ?? today,
            _draft.until,
            invoiced,
          ),
          ?memberPauseBookingsText(
            ref,
            l,
            member.id,
            _draft.from ?? today,
            _draft.until,
            invoiced,
          ),
        ],
        ResumeMembers() => const <String>[],
      },
    ];
    return [
      if (lines.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text(
          lines.join('\n'),
          key: const ValueKey('member-change-preview'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ];
  }

  /// One member's lines after the change: the outcome, and for a pause what
  /// the server answered it costs.
  List<String> _resultLines(
    AppLocalizations l,
    AppFormat format,
    DateTime today,
    MemberChangeResult result,
  ) {
    final answer = result.answer;
    final change = widget.change;
    return [
      _outcomeText(l, format, result),
      if (change is PauseMembers && answer != null) ...[
        memberPauseMoneyText(
          l,
          format,
          change.from ?? _draft.from ?? today,
          change.until ?? _draft.until,
          answer.charged.toSet(),
        ),
        if (answer.bookings > 0) l.memberTermBookingsInFreeMonths(answer.bookings),
      ],
    ];
  }
}

/// The commands of one member, for a selection.
class _Commands implements MemberChangeCommands {
  _Commands(this._ref);

  final WidgetRef _ref;

  /// Read again now, through the app's own members read.
  @override
  Future<List<Member>> members() =>
      _ref.refresh(workspaceMembersProvider.future);

  @override
  Future<void> setStatus(Member member, MemberStatus status) => _ref
      .read(workspaceRepositoryProvider)
      .updateMemberStatus(member.id, status);

  @override
  Future<MemberTermAnswer> setShare(Member member, int pct, {DateTime? on}) {
    final repository = _ref.read(workspaceRepositoryProvider);
    return on == null
        ? repository.requestMemberShare(member.id, pct)
        : repository.scheduleMemberShare(member.id, pct, on, newRequestId());
  }

  @override
  Future<MemberTermAnswer> pause(
    Member member, {
    DateTime? from,
    DateTime? until,
  }) => _ref
      .read(workspaceRepositoryProvider)
      .scheduleMemberPause(
        member.id,
        from ?? _dayOf(_ref.read(clockProvider).now()),
        until,
        newRequestId(),
      );
}
