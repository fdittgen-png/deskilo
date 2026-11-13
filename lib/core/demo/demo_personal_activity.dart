// SPDX-License-Identifier: AGPL-3.0-or-later
// Personal history is a projection of the same stores as workspace money.
import '../../features/money/domain/account_activity.dart';
import '../../features/money/domain/ledger_entry.dart';
import '../../features/workspace/domain/workspace.dart';
import 'demo_personal_space.dart';

Iterable<AccountActivity> demoPersonalHistory(
  List<DemoPersonalSpace> spaces,
  String? userId,
  AccountActivityKind kind,
) sync* {
  for (final space in spaces) {
    final ids = demoMemberIdsFor(space, userId);
    if (ids.isEmpty) continue;
    final workspaceId = space.workspaces.myMember.workspaceId;
    final workspace = space.workspaces.workspaces
        .where((w) => w.id == workspaceId)
        .firstOrNull;
    if (workspace == null) continue;
    yield* switch (kind) {
      AccountActivityKind.invoices => _invoices(space, workspace, ids),
      AccountActivityKind.payments => _payments(space, workspace, ids),
      AccountActivityKind.usage => _usage(space, workspace, ids),
    };
  }
}

Iterable<AccountActivity> _invoices(
  DemoPersonalSpace space,
  Workspace workspace,
  Set<String> ids,
) sync* {
  for (final i in space.money.invoices.where((i) => ids.contains(i.memberId))) {
    yield AccountActivity(
      id: i.id,
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      occurredAt: i.issuedAt,
      reference: i.number,
      description: i.title,
      currency: i.currency,
      amountCents: i.totalCents,
      status: i.isVoided
          ? 'voided'
          : i.settledByInvoiceId != null
          ? 'regrouped'
          : 'issued',
    );
  }
}

Iterable<AccountActivity> _payments(
  DemoPersonalSpace space,
  Workspace workspace,
  Set<String> ids,
) sync* {
  for (final p in space.money.ledger.where(
    (p) =>
        ids.contains(p.memberId) &&
        p.category == LedgerCategory.payment &&
        p.kind == LedgerKind.credit,
  )) {
    yield AccountActivity(
      id: '${workspace.id}:${p.id}',
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      occurredAt: p.createdAt,
      reference: '',
      description: p.description,
      amountCents: p.amountCents,
      currency: workspace.currencyCode,
      status: 'confirmed',
    );
  }
  for (final p in space.money.paymentIntents.where(
    (p) =>
        ids.contains(p.memberId) &&
        (p.status == 'created' || p.status == 'failed'),
  )) {
    yield AccountActivity(
      id: '${workspace.id}:${p.id}',
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      occurredAt: p.createdAt,
      reference: p.reference,
      description: p.provider,
      amountCents: p.amountCents,
      currency: workspace.currencyCode,
      status: p.status,
    );
  }
}

Iterable<AccountActivity> _usage(
  DemoPersonalSpace space,
  Workspace workspace,
  Set<String> ids,
) sync* {
  for (final u in space.money.usageRecords.where(
    (u) => ids.contains(u.memberId),
  )) {
    yield AccountActivity(
      id: '${workspace.id}:${u.id}',
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      occurredAt: u.reservedFrom,
      reference: '',
      description: u.spaceLabel,
      currency: workspace.currencyCode,
      status: u.basis.name,
      minutes: u.countedMinutes,
    );
  }
}
