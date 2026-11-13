// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the customer statement's built-in bands: the space's letterhead,
// the customer, the cutoff and the currency, each open document with the
// payment parts under it and what is still due, the payments and credits
// not yet applied, then the totals and the balance with who owes it. The
// data is customerStatementReportData's; its rows are one flat list.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';

ReportBands customerStatementBands(AppLocalizations l10n) {
  final title = l10n.reportDocCustomerStatement;
  // Each element is one independent line of the band (a label and its
  // value, or a heading): the lines are joined, never a sentence's pieces.
  return ReportBands(
    header: [
      '# {{ workspace }}',
      '> {{ workspace_address }}',
      '---',
      '{{ client_name }}',
      '> {{ client_address }}',
      '---',
      '# $title',
      '> ${l10n.customerStatementAsOf('{{ as_of }}')} · {{ currency }}',
    ].join('\n'),
    continuation: '{{ workspace }} — $title — {{ client_name }}\n---',
    body: [
      '{% for row in rows %}'
          '{% if row.kind == "document" %}**{{ row.number }}** · '
          '${l10n.invoicePdfIssuedOnDate('{{ row.issued }}')}'
          '{% if row.due != "" %} · ${l10n.customerStatementDue('{{ row.due }}')}{% endif %}'
          ' | {{ row.amount }}\n{% endif %}'
          '{% if row.kind == "part" %}> ${l10n.customerStatementPart('{{ row.on }}')}'
          '{% if row.waiting %} (${l10n.customerStatementAwaiting}){% endif %} | − {{ row.amount }}\n{% endif %}'
          '{% if row.kind == "due" %}'
          '{% if row.state == "credit_note" %}${l10n.customerStatementOwedToYou}'
          '{% else %}${l10n.customerStatementStillDue}{% endif %} | {{ row.amount }}\n---\n{% endif %}'
          '{% endfor %}'
          '{% if has_credits %}## ${l10n.customerStatementUnapplied}\n'
          '{% for row in rows %}{% if row.kind == "credit" %}'
          '{{ row.label }} · {{ row.on }} | − {{ row.amount }}\n'
          '{% endif %}{% endfor %}---\n{% endif %}',
      '${l10n.customerStatementTotalDue} | {{ still_due_total }}',
      '${l10n.customerStatementTotalUnapplied} | − {{ unapplied_total }}',
      '{% if balance_owed_by == "customer" %}**${l10n.customerStatementBalanceDue}**'
          '{% endif %}{% if balance_owed_by == "business" %}**${l10n.customerStatementBalanceOwed}**'
          '{% endif %}{% if balance_owed_by == "none" %}**${l10n.customerStatementBalanceNone}**'
          '{% endif %} | **{{ balance }}**',
    ].join('\n'),
    footer: '> {{ workspace }} · {{ issued_by }} · {{ issued }}',
  );
}

/// #3839 — the label of either statement kind.
String customerStatementKindLabel(AppLocalizations l10n, String key) =>
    key == 'customer_statement_period'
    ? l10n.reportDocCustomerStatementPeriod
    : l10n.reportDocCustomerStatement;

/// #3839 — the built-in bands of either statement kind.
ReportBands customerStatementBandsFor(AppLocalizations l10n, String key) =>
    key == 'customer_statement_period'
    ? customerStatementPeriodBands(l10n)
    : customerStatementBands(l10n);

/// #3839 — the period statement's built-in bands: the letterhead, the
/// customer, the period and the currency, the opening balance, each movement
/// on the day it counted with its own day when that differs, and the closing
/// balance (below zero when the business owes it). A period without a movement and a period before
/// the match history each say so in one line. The data is
/// customerStatementPeriodReportData's.
ReportBands customerStatementPeriodBands(AppLocalizations l10n) {
  final title = l10n.reportDocCustomerStatementPeriod;
  final words = {
    'invoice': l10n.invoicePdfTitle,
    'credit_note': l10n.customerStatementMoveCreditNote,
    'voided': l10n.customerStatementMoveVoided,
    'settled': l10n.customerStatementMoveSettled,
    'reopened': l10n.customerStatementMoveReopened,
    'written_off': l10n.customerStatementMoveWrittenOff,
    'paid': l10n.customerStatementMovePaid,
    'payment': l10n.customerStatementMovePayment,
    'credit': l10n.customerStatementMoveCredit,
    'moved': l10n.customerStatementMoveMoved,
    'applied': l10n.customerStatementMoveApplied,
    'freed': l10n.customerStatementMoveFreed,
    'allocated': l10n.customerStatementMoveAllocated,
  };
  return ReportBands(
    header: [
      '# {{ workspace }}',
      '> {{ workspace_address }}',
      '---',
      '{{ client_name }}',
      '> {{ client_address }}',
      '---',
      '# $title',
      '> ${l10n.customerStatementPeriodRange('{{ from }}', '{{ to }}')} · {{ currency }}',
      '{% if reconstructed %}> ${l10n.customerStatementReconstructed('{{ history_from }}')}{% endif %}',
    ].join('\n'),
    continuation: '{{ workspace }} — $title — {{ client_name }}\n---',
    body: [
      // A balance the business owes is shown below zero.
      '${l10n.customerStatementOpening} | {% if opening_owed_by == "business" %}− {% endif %}{{ opening }}',
      '---',
      '{% if no_movement %}> ${l10n.customerStatementNoMovement}\n{% endif %}'
          '{% for row in rows %}{{ row.on }} · '
          '${[for (final e in words.entries) '{% if row.what == "${e.key}" %}${e.value}{% endif %}'].join()}'
          ' {{ row.label }}'
          '{% if row.own != "" %} (${l10n.customerStatementDatedApart('{{ row.own }}')}){% endif %}'
          ' | {{ row.amount }}\n{% endfor %}---',
      '**${l10n.customerStatementClosing}** | **{% if closing_owed_by == "business" %}− {% endif %}{{ closing }}**',
    ].join('\n'),
    footer: '> {{ workspace }} · {{ issued_by }} · {{ issued }}',
  );
}
