// SPDX-License-Identifier: 0BSD
//
// #1061 / #1048 task 3.1 — the LETTER data builders, in domain/: the
// statement, the financial agreement, the monthly payments sheet, the
// workspace report and the reminder. Pure functions of a
// `ReportStrings`, their facts and what they describe — no BuildContext,
// no WidgetRef, no Flutter. The invoice builders and the legal mentions
// they share are report_data.dart.
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/time/workspace_time.dart';
import '../../events/domain/workspace_event.dart';
import '../../workspace/domain/workspace.dart';
import 'invoice.dart';
import 'invoice_legal.dart';
import 'invoice_line_text.dart';
import 'ledger_entry.dart';
import 'report_data.dart';
import 'report_facts.dart';
import 'report_strings.dart';
import 'statement.dart';

/// The statement data model (#476): the member's monthly summary as
/// report lines — subscription, overage, supplements, services,
/// packages and credits, with the balance as the total. Zero rows are
/// skipped so the document reads like the bill.
Map<String, Object?> statementReportData(
  ReportStrings strings, {
  required Statement statement,
  required String workspaceName,
  required String memberName,
  required String periodLabel,
  required String currencyCode,
  Workspace? workspace,
}) {
  final currency = moneyFormat(currencyCode);
  String money(int cents) => currency.formatMinor(cents);
  // #870 — the seller kind decides what the recurring position is
  // called; it must read the same here as on the invoice itself.
  final association = InvoiceLegal.fromJson(
    workspace?.invoiceLegal ?? const {},
  ).isAssociation;
  final lines = <Map<String, Object?>>[
    if (statement.feeCents > 0)
      {
        'label': subscriptionLabel(
          strings,
          statement.subscriptionPct,
          association: association,
        ),
        'amount': money(statement.feeCents),
        'negative': false,
      },
    if (statement.overageCents > 0)
      {
        'label': strings.overage(statement.extraHalfDays),
        'amount': money(statement.overageCents),
        'negative': false,
      },
    if (statement.accessorySupplementCents > 0)
      {
        'label': strings.accessorySupplements,
        'amount': money(statement.accessorySupplementCents),
        'negative': false,
      },
    if (statement.levelSupplementCents > 0)
      {
        'label': strings.levelReservations,
        'amount': money(statement.levelSupplementCents),
        'negative': false,
      },
    if (statement.officeSupplementCents > 0)
      {
        'label': strings.officeReservations,
        'amount': money(statement.officeSupplementCents),
        'negative': false,
      },
    if (statement.deskSupplementCents > 0)
      {
        'label': strings.deskReservations,
        'amount': money(statement.deskSupplementCents),
        'negative': false,
      },
    if (statement.creditsCents != 0)
      {
        'label': strings.paymentsCredits,
        'amount': money(statement.creditsCents),
        'negative': statement.creditsCents > 0,
      },
  ];
  return <String, Object?>{
    'workspace': workspaceName,
    'workspace_address': workspace?.address ?? '',
    'member': memberName,
    'number': '',
    'period': periodLabel,
    'issued': periodLabel,
    'issued_by': workspaceName,
    'replaces': '',
    'total': money(statement.balanceCents.abs()),
    'net_total': money(statement.feeCents + statement.overageCents),
    'vat_total': money(0),
    'charges': money(statement.feeCents + statement.overageCents),
    'payments': money(statement.creditsCents),
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': lines,
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(strings, workspace),
  };
}

/// The FINANCIAL AGREEMENT data model (#494): every standing price that
/// applies to a member — the subscription fee for their percentage, the
/// extra half-day, the service and package catalogue, whole-space and
/// accessory supplements. The owner/admin SENDS it; the member reads,
/// shares or downloads it self-service.
Map<String, Object?> agreementReportData(
  ReportStrings strings,
  AgreementFacts facts, {
  required String memberName,
  required int subscriptionPct,
}) {
  final workspace = facts.workspace;
  final currency = moneyFormat(workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.formatMinor(cents);
  final band = facts.bands
      .where((b) => b.fromPct < subscriptionPct && subscriptionPct <= b.toPct)
      .firstOrNull;
  final lines = <Map<String, Object?>>[
    if (band != null) ...[
      {
        'label': subscriptionLabel(
          strings,
          subscriptionPct,
          association: facts.association,
        ),
        'amount': money(band.feeCents),
      },
      {
        'label': strings.agreementExtraHalfDay,
        'amount': money(band.overageFeeCents),
      },
    ],
    for (final service in facts.services)
      {'label': service.name, 'amount': money(service.priceCents)},
    for (final package in facts.packages)
      {
        'label': '${package.name} (${package.days}d)',
        'amount': money(package.priceCents),
      },
    for (final level in facts.levels)
      if (level.bookableAsWhole && level.priceCents > 0)
        {
          'label': '${level.name} — ${strings.levelReservations}',
          'amount': money(level.priceCents),
        },
    for (final office in facts.offices)
      if (office.bookableAsWhole && office.priceCents > 0)
        {
          'label': '${office.name} — ${strings.officeReservations}',
          'amount': money(office.priceCents),
        },
    for (final desk in facts.desks)
      if (desk.bookableAsWhole && desk.priceCents > 0)
        {
          'label': '${desk.name} — ${strings.deskReservations}',
          'amount': money(desk.priceCents),
        },
    for (final accessory in facts.accessories)
      if (accessory.supplementCents > 0)
        {'label': accessory.name, 'amount': money(accessory.supplementCents)},
  ];
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': memberName,
    'subscription_pct': subscriptionPct,
    'number': '',
    'period': '',
    'issued': DateFormat.yMMMd(strings.dateLocale).format(facts.now),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': band == null ? '' : money(band.feeCents),
    'charges': '',
    'payments': '',
    'net_total': '',
    'vat_total': '',
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': lines,
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(strings, workspace),
  };
}

/// The MONTHLY PAYMENTS data model (#494): everything the member paid,
/// declared or had validated in [period] — the little balance sheet a
/// member can pull self-service.
Map<String, Object?> paymentsReportData(
  ReportStrings strings,
  PaymentsFacts facts, {
  required String period,
  required String memberName,
}) {
  final workspace = facts.workspace;
  final me = facts.me;
  final currency = moneyFormat(workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.formatMinor(cents);
  final dateFormat = DateFormat.yMMMd(strings.dateLocale);
  final ledger = facts.ledger
      .where(
        (entry) => entry.period == period && entry.kind == LedgerKind.credit,
      )
      .toList();
  final pending = facts.events
      .where(
        (event) =>
            event.isPending &&
            event.subjectMemberId == me?.id &&
            (event.type == EventType.payment ||
                event.type == EventType.expense) &&
            (event.payload['period'] as String? ?? period) == period,
      )
      .toList();
  final validatedCents = ledger.fold<int>(
    0,
    (sum, entry) => sum + entry.amountCents,
  );
  final pendingCents = pending.fold<int>(
    0,
    (sum, event) =>
        sum + ((event.payload['amount_cents'] as num?)?.toInt() ?? 0),
  );
  final statement = facts.statement;
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': memberName,
    'number': '',
    'period': period,
    'issued': dateFormat.format(facts.now),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': money(statement?.balanceCents ?? 0),
    'charges': '',
    'payments': money(validatedCents),
    'net_total': '',
    'vat_total': '',
    'validated_total': money(validatedCents),
    'pending_total': money(pendingCents),
    // #955 — pending payments and pending expense submissions apart.
    'pending_payments_total': money(pending
        .where((e) => e.type == EventType.payment)
        .fold<int>(0, (s, e) => s + ((e.payload['amount_cents'] as num?)?.toInt() ?? 0))),
    'pending_expenses_total': money(pending
        .where((e) => e.type == EventType.expense)
        .fold<int>(0, (s, e) => s + ((e.payload['amount_cents'] as num?)?.toInt() ?? 0))),
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': [
      for (final entry in ledger)
        {
          'label':
              '${dateFormat.format(WorkspaceTime.dateOf(entry.occurredOn ?? entry.createdAt))} · ${entry.description.isEmpty ? strings.paymentsCredits : entry.description}',
          'amount': money(entry.amountCents),
        },
      for (final event in pending)
        {
          'label':
              '${event.payload['note'] as String? ?? strings.eventTypePayment} — ${strings.paymentsPendingTag}',
          'amount': money(
            (event.payload['amount_cents'] as num?)?.toInt() ?? 0,
          ),
        },
    ],
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(strings, workspace),
  };
}

/// The WORKSPACE REPORT data model (#494): everything about the space —
/// identity, floor-plan counts, availability, features, prices.
Map<String, Object?> workspaceReportData(
  ReportStrings strings,
  WorkspaceFacts facts,
) {
  final workspace = facts.workspace;
  final currency = moneyFormat(workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.formatMinor(cents);
  final levels = facts.levels;
  final plans = facts.plans;
  final hours = facts.hours;
  String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  final dayNames = DateFormat.E(strings.dateLocale);
  final monday = DateTime(2024, 1, 1); // a Monday — weekday names only.
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': '',
    'number': '',
    'period': '',
    'issued': DateFormat.yMMMd(strings.dateLocale).format(facts.now),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': '',
    'charges': '',
    'payments': '',
    'net_total': '',
    'vat_total': '',
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'country': workspace?.countryCode ?? '',
    'currency': workspace?.currencyCode ?? '',
    'timezone': workspace?.timezone ?? '',
    'members_count': facts.membersCount,
    'levels_count': levels.length,
    'offices_count': plans.fold<int>(
      0,
      (sum, plan) => sum + plan.offices.length,
    ),
    'desks_count': plans.fold<int>(0, (sum, plan) => sum + plan.desks.length),
    'seats_count': plans.fold<int>(0, (sum, plan) => sum + plan.seats.length),
    'open_days': facts.openDays
        .map((d) => dayNames.format(monday.add(Duration(days: d - 1))))
        .join(', '),
    'work_hours':
        '${clock(hours.startMinutes)}–${clock(hours.halfBoundaryMinutes)}–${clock(hours.endMinutes)}',
    'features': [
      for (final label in facts.featureLabels) {'label': label},
    ],
    'lines': [
      for (final band in facts.bands)
        {
          'label':
              '${subscriptionLabel(strings, band.toPct, association: facts.association)}'
              ' (${band.fromPct + 1}–${band.toPct}%)',
          'amount': money(band.feeCents),
        },
      for (final service in facts.services)
        {'label': service.name, 'amount': money(service.priceCents)},
    ],
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(strings, workspace),
  };
}

/// The reminder-letter data model (#472/#474) — the invoice basics plus
/// the level, the letter date and the days the invoice sits open.
Map<String, Object?> reminderReportData(
  ReportStrings strings,
  ReminderFacts facts,
  Invoice invoice, {
  required int level,
}) {
  final currency = moneyFormat(invoice.currency);
  final dateFormat = DateFormat.yMMMd(strings.dateLocale);
  final now = facts.now;
  final workspace = facts.workspace;
  return <String, Object?>{
    'workspace': invoice.workspaceName,
    'workspace_address': invoice.workspaceAddress,
    // #946 — the site the document concerns, when it is not the default
    // one, and the other sites the month's attendance stood at.
    'site_name': siteNameOf(invoice),
    'site_address': siteAddressOf(invoice),
    'usage_sites': usageSitesOf(invoice),
    'member': invoice.clientName,
    'number': invoice.number,
    'issued': dateFormat.format(invoice.issuedAt),
    'total': currency.formatMinor(invoice.totalCents),
    'reminder_level': level,
    'reminder_date': dateFormat.format(now),
    'days_open': now.difference(invoice.issuedAt).inDays,
    // #480 — a reminder cites the same statutory payment clauses.
    ...legalMentionData(
      strings,
      workspace,
      seller: invoice.sellerParty,
      buyer: invoice.buyerParty,
      clientAddress: clientAddressOf(invoice, workspace, strings),
      clientName: clientNameOf(invoice),
      reverseCharged: invoice.isReverseCharged,
      counterpartyCategory: invoice.counterpartyCategory,
      memberTerms: facts.memberTerms,
    ),
  };
}
