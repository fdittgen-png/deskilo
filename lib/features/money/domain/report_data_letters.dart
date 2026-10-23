// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1061 / #1048 task 3.1 — the LETTER data builders, in domain/: the
// statement, the financial agreement, the monthly payments sheet, the
// workspace report and the reminder. Pure functions of a
// `ReportStrings`, their facts and what they describe — no BuildContext,
// no WidgetRef, no Flutter. The invoice builders and the legal mentions
// they share are report_data.dart.
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/time/date_text.dart';
import '../../../core/time/workspace_time.dart';
import '../../events/domain/workspace_event.dart';
import '../../workspace/domain/workspace.dart';
import 'fee_band.dart';
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
        'amount': currency.formatMinor(statement.feeCents),
        'negative': false,
      },
    if (statement.overageCents > 0)
      {
        'label': strings.overage(statement.extraHalfDays),
        'amount': currency.formatMinor(statement.overageCents),
        'negative': false,
      },
    if (statement.accessorySupplementCents > 0)
      {
        'label': strings.accessorySupplements,
        'amount': currency.formatMinor(statement.accessorySupplementCents),
        'negative': false,
      },
    if (statement.levelSupplementCents > 0)
      {
        'label': strings.levelReservations,
        'amount': currency.formatMinor(statement.levelSupplementCents),
        'negative': false,
      },
    if (statement.officeSupplementCents > 0)
      {
        'label': strings.officeReservations,
        'amount': currency.formatMinor(statement.officeSupplementCents),
        'negative': false,
      },
    if (statement.deskSupplementCents > 0)
      {
        'label': strings.deskReservations,
        'amount': currency.formatMinor(statement.deskSupplementCents),
        'negative': false,
      },
    if (statement.creditsCents != 0)
      {
        'label': strings.paymentsCredits,
        'amount': currency.formatMinor(statement.creditsCents),
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
    'total': currency.formatMinor(statement.balanceCents.abs()),
    'net_total': currency.formatMinor(statement.feeCents + statement.overageCents),
    'vat_total': currency.formatMinor(0),
    'charges': currency.formatMinor(statement.feeCents + statement.overageCents),
    'payments': currency.formatMinor(statement.creditsCents),
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
  final band = feeBandFor(facts.bands, subscriptionPct);
  final lines = <Map<String, Object?>>[
    if (band != null) ...[
      {
        'label': subscriptionLabel(
          strings,
          subscriptionPct,
          association: facts.association,
        ),
        'amount': currency.formatMinor(band.feeCents),
      },
      {
        'label': strings.agreementExtraHalfDay,
        'amount': currency.formatMinor(band.overageFeeCents),
      },
    ],
    for (final service in facts.services)
      {'label': service.name, 'amount': currency.formatMinor(service.priceCents)},
    for (final package in facts.packages)
      {
        'label': '${package.name} (${package.days}d)',
        'amount': currency.formatMinor(package.priceCents),
      },
    for (final level in facts.levels)
      if (level.bookableAsWhole && level.priceCents > 0)
        {
          'label': '${level.name} — ${strings.levelReservations}',
          'amount': currency.formatMinor(level.priceCents),
        },
    for (final office in facts.offices)
      if (office.bookableAsWhole && office.priceCents > 0)
        {
          'label': '${office.name} — ${strings.officeReservations}',
          'amount': currency.formatMinor(office.priceCents),
        },
    for (final desk in facts.desks)
      if (desk.bookableAsWhole && desk.priceCents > 0)
        {
          'label': '${desk.name} — ${strings.deskReservations}',
          'amount': currency.formatMinor(desk.priceCents),
        },
    for (final accessory in facts.accessories)
      if (accessory.supplementCents > 0)
        {'label': accessory.name, 'amount': currency.formatMinor(accessory.supplementCents)},
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
    'total': band == null ? '' : currency.formatMinor(band.feeCents),
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
    'total': currency.formatMinor(statement?.balanceCents ?? 0),
    'charges': '',
    'payments': currency.formatMinor(validatedCents),
    'net_total': '',
    'vat_total': '',
    'validated_total': currency.formatMinor(validatedCents),
    'pending_total': currency.formatMinor(pendingCents),
    // #955 — pending payments and pending expense submissions apart.
    'pending_payments_total': currency.formatMinor(pending
        .where((e) => e.type == EventType.payment)
        .fold<int>(0, (s, e) => s + ((e.payload['amount_cents'] as num?)?.toInt() ?? 0))),
    'pending_expenses_total': currency.formatMinor(pending
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
          'amount': currency.formatMinor(entry.amountCents),
        },
      for (final event in pending)
        {
          'label':
              '${event.payload['note'] as String? ?? strings.eventTypePayment} — ${strings.paymentsPendingTag}',
          'amount': currency.formatMinor(
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
  final levels = facts.levels;
  final plans = facts.plans;
  final hours = facts.hours;
  final dayNames = DateFormat.E(strings.dateLocale);
  final monday = DateTime(2024); // a Monday — weekday names only.
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
        '${clockFromMinutes(hours.startMinutes)}–${clockFromMinutes(hours.halfBoundaryMinutes)}–${clockFromMinutes(hours.endMinutes)}',
    'features': [
      for (final label in facts.featureLabels) {'label': label},
    ],
    'lines': [
      for (final band in facts.bands)
        {
          'label':
              '${subscriptionLabel(strings, band.toPct, association: facts.association)}'
              ' (${band.fromPct + 1}–${band.toPct}%)',
          'amount': currency.formatMinor(band.feeCents),
        },
      for (final service in facts.services)
        {'label': service.name, 'amount': currency.formatMinor(service.priceCents)},
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
      // #1916 — a reminder cites the invoice's FROZEN clauses, once.
      frozen: invoice.legalClauses,
      legacy: isLegacyInvoice(invoice),
    ),
  };
}
