// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — change of plan, pause and resume as a short task, for one member
// or a selection: it says that it applies from today (nothing dated is
// stored, #3858), applies member by member (member_batch_change.dart) and
// then lists each member with what became of them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../core/ui/adaptive/task_choice.dart';
import '../../core/ui/adaptive/task_surface.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/workspace/application/set_member_subscription.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import 'member_batch_change.dart';

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
  MemberChangeOutcome outcome,
) => switch (outcome) {
  MemberChangeOutcome.applied => l.membersOutcomeApplied,
  MemberChangeOutcome.unchanged => l.membersOutcomeUnchanged,
  MemberChangeOutcome.pending => l.membersOutcomePending,
  MemberChangeOutcome.exited => l.membersOutcomeExited,
  MemberChangeOutcome.kiosk => l.membersOutcomeKiosk,
  MemberChangeOutcome.wrongStatus => l.membersOutcomeWrongStatus,
  MemberChangeOutcome.ruleRefused => l.membersOutcomeRuleRefused,
  MemberChangeOutcome.gone => l.membersOutcomeGone,
  MemberChangeOutcome.failed => l.membersOutcomeFailed,
};

class _MemberChangeTask extends ConsumerStatefulWidget {
  const _MemberChangeTask({required this.members, required this.change});

  final List<Member> members;
  final MemberChange change;

  @override
  ConsumerState<_MemberChangeTask> createState() => _MemberChangeTaskState();
}

class _MemberChangeTaskState extends ConsumerState<_MemberChangeTask> {
  int? _share;
  bool _running = false;
  Map<String, MemberChangeOutcome>? _outcomes;

  String _title(AppLocalizations l) {
    final n = widget.members.length;
    return switch (widget.change) {
      ChangePlan() => l.membersBulkPlan(n),
      PauseMembers() => l.membersBulkPause(n),
      ResumeMembers() => l.membersBulkResume(n),
    };
  }

  Future<void> _apply() async {
    final change = switch (widget.change) {
      ChangePlan() => ChangePlan(_share!),
      final other => other,
    };
    setState(() => _running = true);
    final outcomes = await applyMemberChange(_Commands(ref), [
      for (final m in widget.members) m.id,
    ], change);
    if (!mounted) return;
    ref.invalidate(workspaceMembersProvider);
    setState(() {
      _running = false;
      _outcomes = outcomes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final names = ref.watch(memberNamesProvider).value ?? const {}; // empty-ok: an unread name shows blank, the outcome still shows
    final today = ref.watch(clockProvider).now();
    final outcomes = _outcomes;
    final plan = widget.change is ChangePlan;
    final offered =
        ref.watch(subscriptionLevelsProvider).value?.offeredLevels ??
        const <int>[]; // empty-ok: no level offered until read
    final ready = !_running && (!plan || _share != null);
    return TaskChoice(
      title: _title(l),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.membersChangeFromToday(
              format.dates(DateShape.longDate).format(today),
            ),
            key: const ValueKey('member-change-from-today'),
          ),
          if (plan && outcomes == null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final pct in [0, ...offered])
                  ChoiceChip(
                    key: ValueKey('member-change-share-$pct'),
                    label: Text(
                      pct == 0
                          ? l.memberNoSubscription
                          : format.ratePercent(pct),
                    ),
                    selected: _share == pct,
                    onSelected: (_) => setState(() => _share = pct),
                  ),
              ],
            ),
          ],
          if (outcomes != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l.membersChangeDone(
                outcomes.values
                    .where((o) => o == MemberChangeOutcome.applied)
                    .length,
                outcomes.length,
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
                  _outcomeText(
                    l,
                    outcomes[m.id] ?? MemberChangeOutcome.gone,
                  ),
                ),
              ),
          ],
        ],
      ),
      actions: [
        if (outcomes == null) ...[
          TextButton(
            key: const ValueKey('member-change-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('member-change-apply'),
            onPressed: ready ? _apply : null,
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
  Future<SubscriptionChange> setShare(Member member, int pct) =>
      _ref.read(memberSubscriptionsProvider).set(member, pct);
}
