// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — a member's plan beside the members' table: the share, the plan
// fee (the fee band's, or "unavailable"), the joining date (the only date
// stored, labelled as that), a pause without dates (none are stored,
// #3858), and the estimated next invoice from the statement of the
// current period with its parts, its period and the day it was read. The
// owner changes the plan, pauses and resumes here as short tasks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../money/domain/fee_band.dart';
import '../../../money/providers/money_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/presentation/member_labels.dart';
import '../../../workspace/presentation/subscription_text.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/member_batch_change.dart';
import '../../domain/member_plan.dart';
import '../screens/members_desk.dart';
import 'member_change_task.dart';

/// The plan of [member], for a person with [rights].
class MemberPlanTab extends ConsumerWidget {
  const MemberPlanTab({super.key, required this.member, required this.rights});

  final Member member;
  final MembersDeskRights rights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.numeric);
    final isSelf = ref.watch(myMemberProvider).value?.id == member.id;
    final currency =
        ref.watch(currentWorkspaceProvider).value?.currencyCode ??
        format.currencyCode;
    final money = format.moneyIn(currency);
    final paused = member.status == MemberStatus.paused;
    Widget row(String key, String label, String value) => ListTile(
      key: ValueKey('member-plan-$key'),
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value),
    );
    return ListView(
      key: const ValueKey('member-plan'),
      padding: AppSpacing.lgAll,
      children: [
        row(
          'share',
          l.memberPlanShareLabel,
          subscriptionText(l, format, member.subscriptionPct),
        ),
        if (rights.seesFees)
          row('fee', l.membersColPlanFee, switch (planFeeOf(
            ref.watch(feeBandsProvider).value ?? const <FeeBand>[], // empty-ok: an unread band list says unavailable, never a fee
            member.subscriptionPct,
          )) {
            NoPlan() => l.memberNoSubscription,
            BandFee(:final cents) => money.formatMinor(cents),
            FeeUnavailable() => l.membersFeeUnavailable,
          }),
        row('joined', l.memberPlanJoined, switch (member.joinedAt) {
          final on? => dates.format(on),
          null => l.memberPlanJoinedUnknown,
        }),
        row('status', l.membersColStatus, memberStatusLabel(l, member.status)),
        if (paused)
          Text(
            l.memberPlanPausedNoDates,
            key: const ValueKey('member-plan-paused'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (rights.seesOpen || isSelf) _Estimate(memberId: member.id),
        if (rights.changes) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton(
                key: const ValueKey('member-plan-change'),
                onPressed: () => showMemberChangeTask(
                  context,
                  members: [member],
                  change: const ChangePlan(0),
                ),
                child: Text(l.memberSubscriptionLabel),
              ),
              OutlinedButton(
                key: const ValueKey('member-plan-pause'),
                onPressed: () => showMemberChangeTask(
                  context,
                  members: [member],
                  change: paused ? const ResumeMembers() : const PauseMembers(),
                ),
                child: Text(paused ? l.memberReactivate : l.memberPause),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The estimated next invoice: the statement of the current period, its
/// parts as the server gives them.
class _Estimate extends ConsumerWidget {
  const _Estimate({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final format = appFormatOf(context);
    final now = ref.watch(clockProvider).now();
    final period = currentPeriod(now);
    final read = ref.watch(memberStatementProvider(memberId, period));
    final currency =
        ref.watch(currentWorkspaceProvider).value?.currencyCode ??
        format.currencyCode;
    final money = format.moneyIn(currency);
    final statement = read.value;
    final children = <Widget>[
      Text(l.memberPlanEstimate, style: theme.textTheme.titleSmall),
    ];
    if (read.hasError || (read.hasValue && statement == null)) {
      children.add(
        Text(
          l.memberPlanEstimateUnavailable,
          key: const ValueKey('member-plan-estimate-unavailable'),
        ),
      );
    } else if (statement != null) {
      final e = estimateOf(statement);
      Widget part(String key, String label, int cents) => Row(
        key: ValueKey('member-plan-estimate-$key'),
        children: [
          Expanded(child: Text(label)),
          Text(money.formatMinor(cents)),
        ],
      );
      children.addAll([
        Text(
          l.memberPlanEstimateBasis(
            format
                .dates(DateShape.monthYear)
                .format(DateTime.parse('${e.period}-01')),
            format.dates(DateShape.numeric).format(now),
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        part('fee', l.membersColPlanFee, e.feeCents),
        part('overage', l.memberPlanEstOverage, e.overageCents),
        part('supplements', l.memberPlanEstSupplements, e.supplementCents),
        part('credits', l.memberPlanEstCredits, -e.creditsCents),
        const Divider(),
        Row(
          key: const ValueKey('member-plan-estimate'),
          children: [
            Expanded(
              child: Text(
                l.memberPlanEstimate,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              money.formatMinor(e.owedCents),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
