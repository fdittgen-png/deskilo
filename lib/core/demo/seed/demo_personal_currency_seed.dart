// SPDX-License-Identifier: AGPL-3.0-or-later
// A visitor's personal multi-currency view comes from that person's own
// purchases at two businesses. Companion memberships grant no extra powers.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/overage_policy.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../data/money/demo_invoice_identity.dart';
import '../demo_finance_projection.dart';
import '../demo_personal_space.dart';

typedef _Person = ({DemoPersonalSpace space, Member member});

void completeDemoPersonalCurrencies(
  List<DemoPersonalSpace> spaces, {
  required DateTime now,
  required List<DemoPersonalSpace> companionSpaces,
}) {
  final people = <String, _Person>{};
  for (final space in spaces) {
    for (final member in demoMembersOf(space)) {
      if (member.isKiosk || member.userId.isEmpty) continue;
      final previous = people[member.userId];
      if (previous == null || previous.member.status != MemberStatus.active) {
        people[member.userId] = (space: space, member: member);
      }
    }
  }
  for (final person in people.values) {
    _completePerson(person, spaces, companionSpaces, now);
  }
}

void _completePerson(
  _Person person,
  List<DemoPersonalSpace> spaces,
  List<DemoPersonalSpace> companions,
  DateTime now,
) {
  final userId = person.member.userId;
  var overview = demoFinanceForUser(spaces, userId);
  for (final space in companions) {
    if (overview.owedByCurrency.length >= 2) return;
    final workspace = space.workspaces.workspaces.firstWhere(
      (w) => w.id == space.workspaces.myMember.workspaceId,
    );
    if (overview.owedByCurrency.containsKey(workspace.currencyCode)) continue;
    final member = _companion(space, workspace.id, person, now);
    final credit =
        overview
            .inWorkspace(workspace.id)
            .inMyFavourByCurrency[workspace.currencyCode] ??
        0;
    _sale((
      space: space,
      workspace: workspace,
      member: member,
      now: now,
      credit: credit,
      source: person,
    ));
    overview = demoFinanceForUser(spaces, userId);
  }
  if (overview.owedByCurrency.length < 2) {
    throw StateError('demo account $userId needs two purchasing currencies');
  }
}

Member _companion(
  DemoPersonalSpace space,
  String workspaceId,
  _Person person,
  DateTime now,
) {
  final existing = demoMembersOf(space)
      .where((m) => m.userId == person.member.userId)
      .firstOrNull;
  if (existing != null) return existing;
  final source = person.member;
  final member = source.copyWith(
    id: '$workspaceId-visitor-${source.userId}',
    workspaceId: workspaceId,
    isAdmin: false,
    isOwner: false,
    coOwner: CoOwnerStatus.none,
    subscriptionPct: 0,
    overagePolicy: OveragePolicy.blocked,
    canReserveLevel: false,
    homeSiteId: null,
    managedAccess: const {},
    memberNumber: '$workspaceId-${source.userId}',
    origin: MemberOrigin.invited,
    joinedAt: now.toUtc(),
  );
  space.workspaces.otherMembers.add(member);
  space.workspaces.memberNames[member.id] =
      person.space.workspaces.memberNames[source.id] ?? source.managedName;
  space.workspaces.memberEmails[member.id] =
      person.space.workspaces.memberEmails[source.id] ?? '';
  return member;
}

void _sale(
  ({
    DemoPersonalSpace space,
    Workspace workspace,
    Member member,
    DateTime now,
    int credit,
    _Person source,
  })
  sale,
) {
  final (:space, :workspace, :member, :now, :credit, :source) = sale;
  final money = space.money;
  final identity = demoInvoiceIdentityFor(
    space.workspaces,
    memberId: member.id,
    actorMemberId: space.workspaces.myMember.id,
  );
  final previous = source.space.money.invoices
      .where((i) => i.memberId == source.member.id)
      .firstOrNull;
  final buyerCountry = source.space.workspaces.workspaces
      .firstWhere((w) => w.id == source.member.workspaceId)
      .countryCode;
  final service = money.services.firstWhere(
    (s) => s.workspaceId == workspace.id && s.active && s.priceCents > 0,
  );
  final period = yearMonth(now.year, now.month);
  if (money.invoices.any(
    (i) =>
        i.memberId == member.id &&
        i.period == period &&
        !i.isVoided &&
        i.kind != InvoiceKind.settlement,
  )) {
    throw StateError('personal demo sale would duplicate an invoice period');
  }
  final quantity = credit ~/ service.priceCents + 1;
  final amount = quantity * service.priceCents;
  final rate = money.vatRates
      .where(
        (r) =>
            r.active &&
            (service.vatRateId.isEmpty
                ? r.isDefault
                : r.id == service.vatRateId),
      )
      .firstOrNull;
  if (workspace.vatRegime == 'vat_registered' && rate == null) {
    throw StateError('personal demo sale requires the business tax rate');
  }
  final percent = rate == null
      ? 0.0
      : vatPercentAt(money.vatRates, rate.id, now) ?? rate.percent;
  final category = rate?.category ?? 'O';
  final split = vatSplit(amount, percent);
  final id = '${workspace.id}-personal-sale-${member.userId}';
  money.ledger.add(
    LedgerEntry(
      id: '$id-charge',
      memberId: member.id,
      kind: LedgerKind.charge,
      category: LedgerCategory.service,
      amountCents: amount,
      description: service.name,
      period: period,
      createdAt: now.toUtc(),
    ),
  );
  money.ledgerVatPercents['$id-charge'] = percent;
  money.invoices.add(
    Invoice(
      id: id,
      workspaceId: workspace.id,
      memberId: member.id,
      number: 'DEMO-${workspace.id}-${member.userId}',
      issuedAt: now.toUtc(),
      period: period,
      title: service.name,
      lines: [
        InvoiceLine(
          kind: 'service',
          label: service.name,
          quantity: quantity,
          amountCents: amount,
          vatPercent: percent,
          vatCategory: category,
        ),
      ],
      totalCents: amount,
      currency: workspace.currencyCode,
      memberName: space.workspaces.memberNames[member.id] ?? '',
      memberAddress: previous?.memberAddress ?? identity.memberAddress,
      workspaceName: workspace.name,
      workspaceAddress: workspace.address,
      issuerName: identity.issuerName,
      sellerParty: identity.seller,
      buyerParty:
          previous?.buyerParty?.copyWith(memberNumber: member.memberNumber) ??
          identity.buyer?.copyWith(
            street: previous?.memberAddress ?? identity.memberAddress,
            country: buyerCountry,
          ),
      signature: 'demo',
      dueOn: now.toUtc(),
      vatTotals: [
        InvoiceVatTotal(
          percent: percent,
          category: category,
          grossCents: amount,
          netCents: split.netCents,
          vatCents: split.vatCents,
        ),
      ],
    ),
  );
}
