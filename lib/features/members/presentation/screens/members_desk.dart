// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 (desk M5) — the members at the desk: a records table (#3606) of
// name, e-mail, plan and share, plan fee, status, open amount per currency
// and last visit, with Pending, Paused and With an open amount as chips; a
// member opens beside it at `/members/<id>` (#3607). A column the person
// may not see is not there at all, never an empty one: the e-mail is the
// administrators' (as the server answers it), the plan fee and the open
// amount are the finance readers' (`may_view_member_finances`, 0131). The
// owner changes a plan, pauses and resumes, for one member or a selection
// (member_change_task.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/list_detail_route.dart';
import '../../../../core/storage/pane_width_store.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../money/application/receivables.dart';
import '../../../money/domain/fee_band.dart';
import '../../../money/presentation/invoicing/invoicing_reads.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/member_labels.dart';
import '../../../workspace/presentation/subscription_text.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/member_batch_change.dart';
import '../../domain/member_plan.dart';
import '../../providers/member_desk_providers.dart';
import '../widgets/member_change_task.dart';
import 'member_record.dart';

/// The members' address; a member is `/members/<id>`.
const String membersPath = '/members';

/// What the person may see and do in the members' table.
typedef MembersDeskRights = ({
  bool seesEmail,
  bool seesFees,
  bool seesOpen,
  bool changes,
});

/// The rights of [me] holding [permissions].
MembersDeskRights membersDeskRights(
  Member? me,
  Set<WorkspacePermission> permissions,
) {
  final finance =
      permissions.contains(WorkspacePermission.viewFinances) ||
      permissions.contains(WorkspacePermission.issueInvoices);
  return (
    // memberEmailsProvider answers administrators only.
    seesEmail: me?.canAdminister ?? false,
    seesFees:
        finance || permissions.contains(WorkspacePermission.manageBilling),
    seesOpen: finance,
    changes: me?.actsAsOwner ?? false,
  );
}

/// The members table, with the open member beside it.
class MembersDesk extends ConsumerWidget {
  const MembersDesk({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OpenRecord(
    listPath: membersPath,
    builder: (context, id) => ListDetailScaffold(
      id: 'members',
      paneStore: ref.watch(paneWidthStoreProvider),
      list: _MembersTable(),
      selected: recordBesideList(context) ? id : null,
      onClose: () => closeRecord(context, membersPath),
      onMove: (id) => moveToRecord(context, membersPath, id),
      detail: (context, id) => MemberRecord(
        key: ValueKey('member-panel-$id'),
        memberId: id,
        onClose: () => closeRecord(context, membersPath),
      ),
    ),
  );
}

class _MembersTable extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final rights = membersDeskRights(
      ref.watch(myMemberProvider).value,
      ref.watch(myPermissionsProvider),
    );
    final read = ref.watch(workspaceMembersProvider);
    final names =
        ref.watch(memberNamesProvider).value ??
        const {}; // empty-ok: an unread name shows blank
    final emails = rights.seesEmail
        ? ref.watch(memberEmailsProvider).value ??
              const <
                String,
                String
              >{} // empty-ok: an unread address shows blank
        : const <String, String>{};
    final bands = rights.seesFees
        ? ref.watch(feeBandsProvider).value
        : null; // empty-ok: the fee column is absent without the right
    final currency =
        ref.watch(currentWorkspaceProvider).value?.currencyCode ??
        format.currencyCode;
    final open = rights.seesOpen
        ? _openByMember(ref.watch(invoicingReceivablesProvider))
        : const <String, Map<String, int>>{};
    final now = ref.watch(clockProvider).now();
    final visits = ref.watch(membersVisitsProvider);
    final since = visits.since;
    final reservations =
        visits.reservations ??
        const <Reservation>[]; // empty-ok: an unread visit shows blank
    String fee(Member m) =>
        switch (planFeeOf(bands ?? const <FeeBand>[], m.subscriptionPct)) {
          NoPlan() => l.memberNoSubscription,
          BandFee(:final cents) => format.moneyIn(currency).formatMinor(cents),
          FeeUnavailable() => l.membersFeeUnavailable,
        };
    return RecordsTable<Member>(
      tableId: 'members',
      rows: read.value ?? const <Member>[], // empty-ok: the table shows loading or failed while it is not read
      state: switch (read) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      onRetry: () => ref.invalidate(workspaceMembersProvider),
      keyOf: (m) => m.id,
      searchText: (m) => '${names[m.id] ?? ''} ${emails[m.id] ?? ''}',
      onOpen: (m) => openRecord(context, membersPath, m.id),
      empty: Center(child: Text(l.directoryEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'name'),
      chips: [
        RecordChip(
          id: 'pending',
          label: l.memberStatusPending,
          keeps: (m) => m.status == MemberStatus.pending,
        ),
        RecordChip(
          id: 'paused',
          label: l.memberStatusPaused,
          keeps: (m) => m.status == MemberStatus.paused,
        ),
        if (rights.seesOpen)
          RecordChip(
            id: 'open',
            label: l.membersChipOpen,
            keeps: (m) => open[m.id]?.isNotEmpty ?? false,
          ),
      ],
      // The plan fees add up per currency, with the table's own totals.
      amountOf: bands == null
          ? null
          : (m) => switch (planFeeOf(bands, m.subscriptionPct)) {
              BandFee(:final cents) => (currency: currency, minor: cents),
              _ => null,
            },
      formatAmount: (code, minor) => format.moneyIn(code).formatMinor(minor),
      columns: [
        RecordColumn(
          id: 'name',
          label: l.membersColName,
          flex: 3,
          hideable: false,
          sortKey: (m) => (names[m.id] ?? '').toLowerCase(),
          cell: (_, m) =>
              Text(names[m.id] ?? '', overflow: TextOverflow.ellipsis),
        ),
        if (rights.seesEmail)
          RecordColumn(
            id: 'email',
            label: l.membersColEmail,
            flex: 3,
            sortKey: (m) => emails[m.id] ?? '',
            cell: (_, m) =>
                Text(emails[m.id] ?? '', overflow: TextOverflow.ellipsis),
          ),
        RecordColumn(
          id: 'plan',
          label: l.membersColPlan,
          flex: 2,
          sortKey: (m) => m.subscriptionPct,
          cell: (_, m) => Text(
            m.isKiosk
                ? l.memberKioskLabel
                : subscriptionText(l, format, m.subscriptionPct),
          ),
        ),
        if (rights.seesFees)
          RecordColumn(
            id: 'fee',
            label: l.membersColPlanFee,
            flex: 2,
            numeric: true,
            cell: (_, m) => Text(m.isKiosk ? '' : fee(m)),
          ),
        RecordColumn(
          id: 'status',
          label: l.membersColStatus,
          flex: 2,
          sortKey: (m) => m.status.index,
          cell: (_, m) => Text(memberStatusLabel(l, m.status)),
        ),
        if (rights.seesOpen)
          RecordColumn(
            id: 'open',
            label: l.invoicingColOpen,
            flex: 2,
            numeric: true,
            // One line per currency, never one sum across them.
            cell: (_, m) => Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in (open[m.id] ?? const <String, int>{}).entries)
                  Text(format.moneyIn(e.key).formatMinor(e.value)),
              ],
            ),
          ),
        RecordColumn(
          id: 'visit',
          label: l.membersColLastVisit,
          flex: 2,
          sortKey: (m) => lastVisitOf(m.id, reservations, now) ?? DateTime(0),
          cell: (_, m) => Text(switch (lastVisitOf(m.id, reservations, now)) {
            final on? => format.dates(DateShape.numeric).format(on),
            null when visits.reservations != null => l.membersNoVisitSince(
              format.dates(DateShape.numeric).format(since),
            ),
            null => '',
          }),
        ),
      ],
      rowActions: rights.changes
          ? (m) => [
              RecordAction(
                id: 'plan',
                label: l.memberSubscriptionLabel,
                icon: Icons.tune,
                onRun: (m) => showMemberChangeTask(
                  context,
                  members: [m],
                  change: const ChangePlan(0),
                ),
              ),
              RecordAction(
                id: 'pause',
                label: m.status == MemberStatus.paused
                    ? l.memberReactivate
                    : l.memberPause,
                icon: m.status == MemberStatus.paused
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                onRun: (m) => showMemberChangeTask(
                  context,
                  members: [m],
                  change: m.status == MemberStatus.paused
                      ? const ResumeMembers()
                      : const PauseMembers(),
                ),
              ),
            ]
          : null,
      bulkActions: rights.changes
          ? [
              for (final (id, label, icon, change) in [
                ('plan', l.membersBulkPlan, Icons.tune, const ChangePlan(0)),
                (
                  'pause',
                  l.membersBulkPause,
                  Icons.pause_circle_outline,
                  const PauseMembers(),
                ),
                (
                  'resume',
                  l.membersBulkResume,
                  Icons.play_circle_outline,
                  const ResumeMembers(),
                ),
              ])
                RecordBulkAction(
                  id: id,
                  label: label,
                  icon: icon,
                  onRun: (keys) => showMemberChangeTask(
                    context,
                    members: [
                      for (final m in read.value ?? const <Member>[]) // empty-ok: nothing is selected before the rows are read
                        if (keys.contains(m.id)) m,
                    ],
                    change: change,
                  ),
                ),
            ]
          : const [],
      cardBuilder: (context, m) => ListTile(
        title: Text(names[m.id] ?? '', overflow: TextOverflow.ellipsis),
        subtitle: Text(memberStatusLabel(l, m.status)),
      ),
    );
  }

  /// What each member still owes, per currency, from the invoices as
  /// receivables; empty while they are not read.
  static Map<String, Map<String, int>> _openByMember(List<Receivable>? rows) {
    final open = <String, Map<String, int>>{};
    for (final r in rows ?? const <Receivable>[]) {
      if (r.openMinor <= 0) continue;
      if (r.stage != ReceivableStage.open &&
          r.stage != ReceivableStage.partlyPaid) {
        continue;
      }
      final byCurrency = open[r.customerId] ??= {};
      byCurrency[r.currency] = (byCurrency[r.currency] ?? 0) + r.openMinor;
    }
    return open;
  }
}
