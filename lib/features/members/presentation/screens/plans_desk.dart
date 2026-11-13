// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 (desk M5) — subscriptions and plans at the desk: a records table of
// the plans, which are the fee bands (ADR 0008): the shares a plan covers,
// its monthly fee in the business's currency, what it includes and how many
// members are on it; a plan opens beside it at `/members/plans/<id>` with
// its members, each with their share, status and joining date. The fee is
// the finance readers' and the billing managers'; without the right the
// column is not there. Prices are edited where they always were (Pricing &
// packages); the owner changes the plan of the plan's members from here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/list_detail_route.dart';
import '../../../../core/storage/pane_width_store.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../money/domain/fee_band.dart';
import '../../../money/providers/money_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/presentation/member_labels.dart';
import '../../../workspace/presentation/subscription_text.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/member_batch_change.dart';
import '../../domain/member_plan.dart';
import '../widgets/member_change_task.dart';
import 'members_desk.dart';

/// The plans' address; a plan is `/members/plans/<band id>`.
const String plansPath = '/members/plans';

/// The page of the plans.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: PageTitle(context.l10n.membersPlansTitle)),
    body: OpenRecord(
      listPath: plansPath,
      builder: (context, id) => ListDetailScaffold(
        id: 'plans',
        paneStore: ref.watch(paneWidthStoreProvider),
        list: const _PlansTable(),
        selected: recordBesideList(context) ? id : null,
        onClose: () => closeRecord(context, plansPath),
        onMove: (id) => moveToRecord(context, plansPath, id),
        detail: (context, id) => PlanRecord(
          key: ValueKey('plan-panel-$id'),
          bandId: id,
          onClose: () => closeRecord(context, plansPath),
        ),
      ),
    ),
  );
}

/// "26 % to 50 %": the shares [band] covers (inclusive-upper).
String _shares(BuildContext context, FeeBand band) {
  final format = appFormatOf(context);
  return context.l10n.plansShareRange(
    format.ratePercent(band.fromPct + 1),
    format.ratePercent(band.toPct),
  );
}

class _PlansTable extends ConsumerWidget {
  const _PlansTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final rights = membersDeskRights(
      ref.watch(myMemberProvider).value,
      ref.watch(myPermissionsProvider),
    );
    final read = ref.watch(feeBandsProvider);
    final members =
        ref.watch(workspaceMembersProvider).value ??
        const <Member>[]; // empty-ok: an unread member list counts nobody yet
    final currency =
        ref.watch(currentWorkspaceProvider).value?.currencyCode ??
        format.currencyCode;
    final money = format.moneyIn(currency);
    int count(FeeBand b) => members.where((m) => onBand(m, b)).length;
    return RecordsTable<FeeBand>(
      tableId: 'plans',
      rows: read.value ?? const <FeeBand>[], // empty-ok: the table shows loading or failed while it is not read
      state: switch (read) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      onRetry: () => ref.invalidate(feeBandsProvider),
      keyOf: (b) => b.id,
      searchText: (b) => _shares(context, b),
      onOpen: (b) => openRecord(context, plansPath, b.id),
      empty: Center(child: Text(l.plansEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'plan'),
      columns: [
        RecordColumn(
          id: 'plan',
          label: l.plansColPlan,
          flex: 2,
          hideable: false,
          sortKey: (b) => b.toPct,
          cell: (context, b) => Text(_shares(context, b)),
        ),
        if (rights.seesFees)
          RecordColumn(
            id: 'fee',
            label: l.billingBandFee,
            flex: 2,
            numeric: true,
            sortKey: (b) => b.feeCents,
            cell: (_, b) => Text(money.formatMinor(b.feeCents)),
          ),
        RecordColumn(
          id: 'included',
          label: l.plansColIncluded,
          flex: 5,
          cell: (_, b) =>
              Text(l.plansIncluded(money.formatMinor(b.overageFeeCents))),
        ),
        RecordColumn(
          id: 'members',
          label: l.plansColMembers,
          numeric: true,
          sortKey: count,
          cell: (_, b) => Text('${count(b)}'),
        ),
      ],
      cardBuilder: (context, b) => ListTile(
        title: Text(_shares(context, b)),
        subtitle: Text(l.plansIncluded(money.formatMinor(b.overageFeeCents))),
        trailing: Text('${count(b)}'),
      ),
    );
  }
}

/// A plan at its address: the members on it.
class PlanRecord extends ConsumerWidget {
  const PlanRecord({super.key, required this.bandId, this.onClose});

  final String bandId;

  /// Set when the plan stands beside the table: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final bands = ref.watch(feeBandsProvider).value;
    final band = bands?.where((b) => b.id == bandId).firstOrNull;
    final rights = membersDeskRights(
      ref.watch(myMemberProvider).value,
      ref.watch(myPermissionsProvider),
    );
    final names =
        ref.watch(memberNamesProvider).value ??
        const {}; // empty-ok: an unread name shows blank
    final on = band == null
        ? const <Member>[]
        : [
            for (final m
                in ref.watch(workspaceMembersProvider).value ??
                    const <
                      Member
                    >[]) // empty-ok: an unread member list lists nobody yet
              if (onBand(m, band)) m,
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text(band == null ? '' : _shares(context, band)),
        automaticallyImplyLeading: onClose == null,
        actions: [
          if (onClose case final close?)
            CloseButton(key: const ValueKey('plan-close'), onPressed: close),
        ],
      ),
      body: bands != null && band == null
          ? Center(
              child: Text(
                l.searchRecordUnreadable,
                key: const ValueKey('search-record-unreadable'),
              ),
            )
          : ListView(
              key: const ValueKey('plan-members'),
              children: [
                if (on.isEmpty) ListTile(title: Text(l.plansNoMembers)),
                for (final m in on)
                  ListTile(
                    key: ValueKey('plan-member-${m.id}'),
                    title: Text(names[m.id] ?? ''),
                    subtitle: Text(
                      '${subscriptionText(l, format, m.subscriptionPct)} · '
                      '${memberStatusLabel(l, m.status)}',
                    ),
                    trailing: Text(switch (m.joinedAt) {
                      final at? => format.dates(DateShape.numeric).format(at),
                      null => '',
                    }),
                    onTap: () => context.go('$membersPath/${m.id}'),
                  ),
                if (rights.changes && on.isNotEmpty)
                  Padding(
                    padding: AppSpacing.lgAll,
                    child: OutlinedButton(
                      key: const ValueKey('plan-change-members'),
                      onPressed: () => showMemberChangeTask(
                        context,
                        members: on,
                        change: const ChangePlan(0),
                      ),
                      child: Text(l.membersBulkPlan(on.length)),
                    ),
                  ),
              ],
            ),
    );
  }
}
