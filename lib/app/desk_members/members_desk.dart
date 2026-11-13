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

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/navigation/list_detail_route.dart';
import '../../core/storage/pane_width_store.dart';
import '../../core/time/clock.dart';
import '../../core/ui/kit/list_detail_scaffold.dart';
import '../../core/ui/kit/records_table.dart';
import '../../features/money/application/receivables.dart';
import '../../features/money/domain/fee_band.dart';
import '../../features/money/presentation/invoicing/invoicing_reads.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/role_assignment.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/domain/workspace_role.dart';
import '../../features/workspace/presentation/member_labels.dart';
import '../../features/workspace/presentation/subscription_text.dart';
import '../../features/workspace/presentation/widgets/member_roles_card.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import '../../l10n/app_localizations.dart';
import 'member_batch_change.dart';
import 'member_change_task.dart';
import 'member_desk_providers.dart';
import 'member_plan.dart';
import 'member_record.dart';
import 'member_roles_task.dart';

/// The members' address; a member is `/members/<id>`.
const String membersPath = '/members';

/// What the person may see and do in the members' table.
typedef MembersDeskRights = ({
  bool seesEmail,
  bool seesFees,
  bool seesOpen,
  bool changes,
  bool givesRoles,
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
    // #3628 — the owner asks for the Administrator role, manageRoles gives
    // the space's own roles (the rule of the role card).
    givesRoles: canGiveRoles(me, permissions),
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
    final rights = membersDeskRights(
      ref.watch(myMemberProvider).value,
      ref.watch(myPermissionsProvider),
    );
    final read = ref.watch(workspaceMembersProvider);
    final format = appFormatOf(context);
    final visits = ref.watch(membersVisitsProvider);
    final view = _MembersView(
      context: context,
      rights: rights,
      rows: read.value ?? const <Member>[], // empty-ok: the table shows loading or failed while it is not read
      names:
          ref.watch(memberNamesProvider).value ??
          const {}, // empty-ok: an unread name shows blank
      emails: rights.seesEmail
          ? ref.watch(memberEmailsProvider).value ??
                const <
                  String,
                  String
                >{} // empty-ok: an unread address shows blank
          : const <String, String>{},
      bands: rights.seesFees
          ? ref.watch(feeBandsProvider).value
          : null, // empty-ok: the fee column is absent without the right
      currency:
          ref.watch(currentWorkspaceProvider).value?.currencyCode ??
          format.currencyCode,
      open: rights.seesOpen
          ? _openByMember(ref.watch(invoicingReceivablesProvider))
          : const <String, Map<String, int>>{},
      now: ref.watch(clockProvider).now(),
      visits: visits,
      roles:
          ref.watch(workspaceRolesProvider).value ??
          const <
            WorkspaceRole
          >[], // empty-ok: no own role is named before they are read
      assignments:
          ref.watch(workspaceRoleAssignmentsProvider).value ??
          const <
            String,
            Set<String>
          >{}, // empty-ok: no own role is held before they are read
    );
    return RecordsTable<Member>(
      tableId: 'members',
      rows: view.rows,
      state: switch (read) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      onRetry: () => ref.invalidate(workspaceMembersProvider),
      keyOf: (m) => m.id,
      searchText: (m) => '${view.names[m.id] ?? ''} ${view.emails[m.id] ?? ''}',
      onOpen: (m) => openRecord(context, membersPath, m.id),
      empty: Center(child: Text(context.l10n.directoryEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'name'),
      chips: view.chips(),
      // The plan fees add up per currency, with the table's own totals.
      amountOf: view.bands == null ? null : view.feeAmount,
      amountColumn: 'fee',
      formatAmount: (code, minor) => format.moneyIn(code).formatMinor(minor),
      columns: view.columns(),
      rowActions: rights.changes || rights.givesRoles ? view.rowActions : null,
      bulkActions: view.bulkActions(),
      cardBuilder: (context, m) => ListTile(
        title: Text(view.names[m.id] ?? '', overflow: TextOverflow.ellipsis),
        subtitle: Text(memberStatusLabel(context.l10n, m.status)),
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

/// What the members' table shows, read once per build.
class _MembersView {
  _MembersView({
    required this.context,
    required this.rights,
    required this.rows,
    required this.names,
    required this.emails,
    required this.bands,
    required this.currency,
    required this.open,
    required this.now,
    required this.visits,
    required this.roles,
    required this.assignments,
  });

  /// The space's roles and who holds which (#3628).
  final List<WorkspaceRole> roles;
  final Map<String, Set<String>> assignments;

  final BuildContext context;
  final MembersDeskRights rights;
  final List<Member> rows;
  final Map<String, String> names;
  final Map<String, String> emails;

  /// Null without the right to see fees (or while unread).
  final List<FeeBand>? bands;
  final String currency;
  final Map<String, Map<String, int>> open;
  final DateTime now;
  final MembersVisits visits;

  AppLocalizations get _l => context.l10n;
  AppFormat get _format => appFormatOf(context);

  String _fee(Member m) =>
      switch (planFeeOf(bands ?? const <FeeBand>[], m.subscriptionPct)) {
        NoPlan() => _l.memberNoSubscription,
        BandFee(:final cents) => _format.moneyIn(currency).formatMinor(cents),
        FeeUnavailable() => _l.membersFeeUnavailable,
      };

  RecordAmount? feeAmount(Member m) =>
      switch (planFeeOf(bands ?? const <FeeBand>[], m.subscriptionPct)) {
        BandFee(:final cents) => (currency: currency, minor: cents),
        _ => null,
      };

  String _visit(Member m) {
    final dates = _format.dates(DateShape.numeric);
    return switch (lastVisitOf(m.id, visits.reservations ?? const [], now)) {
      final on? => dates.format(on),
      null when visits.reservations != null => _l.membersNoVisitSince(
        dates.format(visits.since),
      ),
      null => '',
    };
  }

  List<RecordChip<Member>> chips() => [
    RecordChip(
      id: 'pending',
      label: _l.memberStatusPending,
      keeps: (m) => m.status == MemberStatus.pending,
    ),
    RecordChip(
      id: 'paused',
      label: _l.memberStatusPaused,
      keeps: (m) => m.status == MemberStatus.paused,
    ),
    if (rights.seesOpen)
      RecordChip(
        id: 'open',
        label: _l.membersChipOpen,
        keeps: (m) => open[m.id]?.isNotEmpty ?? false,
      ),
    // #3628 — the users: who can sign in to this business; the managed
    // profiles an administrator runs until the person claims them.
    RecordChip(
      id: 'users',
      label: _l.membersChipUsers,
      keeps: (m) =>
          !m.isManaged && !m.isKiosk && m.origin != MemberOrigin.guest,
    ),
    RecordChip(
      id: 'managed',
      label: _l.membersChipManaged,
      keeps: (m) => m.isManaged,
    ),
  ];

  /// [m]'s roles as the set they hold: ownership and the Administrator
  /// role first, then the space's own; never folded into one string.
  List<String> _rolesOf(Member m) {
    final locale = Localizations.localeOf(context).languageCode;
    return [
      if (m.isOwner) _l.roleOwner,
      if (m.coOwner == CoOwnerStatus.active) _l.memberCoOwnerChip,
      if (m.isAdmin && !m.isOwner)
        administratorName(roles, locale, _l.roleAdmin),
      for (final r in rolesHeldBy(m.id, roles, assignments))
        if (!r.builtin) r.nameIn(locale),
    ];
  }

  List<RecordColumn<Member>> columns() => [
    RecordColumn(
      id: 'name',
      label: _l.membersColName,
      flex: 3,
      hideable: false,
      sortKey: (m) => (names[m.id] ?? '').toLowerCase(),
      cell: (_, m) => Text(names[m.id] ?? '', overflow: TextOverflow.ellipsis),
    ),
    if (rights.seesEmail)
      RecordColumn(
        id: 'email',
        staysBeside: false,
        label: _l.membersColEmail,
        flex: 3,
        sortKey: (m) => emails[m.id] ?? '',
        cell: (_, m) =>
            Text(emails[m.id] ?? '', overflow: TextOverflow.ellipsis),
      ),
    RecordColumn(
      id: 'plan',
      staysBeside: false,
      label: _l.membersColPlan,
      flex: 2,
      sortKey: (m) => m.subscriptionPct,
      cell: (_, m) => Text(
        m.isKiosk
            ? _l.memberKioskLabel
            : subscriptionText(_l, _format, m.subscriptionPct),
      ),
    ),
    if (rights.seesFees)
      RecordColumn(
        id: 'fee',
        staysBeside: false,
        label: _l.membersColPlanFee,
        flex: 2,
        numeric: true,
        cell: (_, m) => Text(m.isKiosk ? '' : _fee(m)),
      ),
    RecordColumn(
      id: 'status',
      label: _l.membersColStatus,
      flex: 3,
      sortKey: (m) => m.status.index,
      cell: (_, m) => Text(memberStatusLabel(_l, m.status)),
    ),
    RecordColumn(
      id: 'roles',
      label: _l.rolesTitle,
      flex: 3,
      staysBeside: false,
      sortKey: (m) => _rolesOf(m).join(' '),
      cell: (_, m) => Text(switch (_rolesOf(m)) {
        final held when held.isEmpty => _l.baseRoleUser,
        final held => held.join(', '),
      }, overflow: TextOverflow.ellipsis),
    ),
    if (rights.seesOpen)
      RecordColumn(
        id: 'open',
        label: _l.invoicingColOpen,
        flex: 2,
        numeric: true,
        // One line per currency, never one sum across them.
        cell: (_, m) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in (open[m.id] ?? const <String, int>{}).entries)
              Text(_format.moneyIn(e.key).formatMinor(e.value)),
          ],
        ),
      ),
    RecordColumn(
      id: 'visit',
      staysBeside: false,
      label: _l.membersColLastVisit,
      flex: 2,
      sortKey: (m) =>
          lastVisitOf(m.id, visits.reservations ?? const [], now) ??
          DateTime(0),
      cell: (_, m) => Text(_visit(m)),
    ),
  ];

  List<RecordAction<Member>> rowActions(Member m) {
    final paused = m.status == MemberStatus.paused;
    return [
      if (rights.givesRoles)
        RecordAction(
          id: 'roles',
          label: _l.rolesTitle,
          icon: Icons.badge_outlined,
          onRun: (m) =>
              showMemberRolesTask(context, member: m, name: names[m.id] ?? ''),
        ),
      if (rights.changes)
        RecordAction(
          id: 'plan',
          label: _l.memberSubscriptionLabel,
          icon: Icons.tune,
          onRun: (m) => showMemberChangeTask(
            context,
            members: [m],
            change: const ChangePlan(0),
          ),
        ),
      if (rights.changes)
        RecordAction(
          id: 'pause',
          label: paused ? _l.memberReactivate : _l.memberPause,
          icon: paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
          onRun: (m) => showMemberChangeTask(
            context,
            members: [m],
            change: paused ? const ResumeMembers() : const PauseMembers(),
          ),
        ),
    ];
  }

  List<RecordBulkAction> bulkActions() => [
    if (rights.givesRoles)
      RecordBulkAction(
        id: 'give-role',
        label: _l.membersBulkGiveRole,
        icon: Icons.badge_outlined,
        onRun: (keys) => showGiveRoleTask(
          context,
          members: [
            for (final m in rows)
              if (keys.contains(m.id)) m,
          ],
        ),
      ),
    if (rights.changes)
      for (final (id, label, icon, change) in [
        ('plan', _l.membersBulkPlan, Icons.tune, const ChangePlan(0)),
        (
          'pause',
          _l.membersBulkPause,
          Icons.pause_circle_outline,
          const PauseMembers(),
        ),
        (
          'resume',
          _l.membersBulkResume,
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
              for (final m in rows)
                if (keys.contains(m.id)) m,
            ],
            change: change,
          ),
        ),
  ];
}
