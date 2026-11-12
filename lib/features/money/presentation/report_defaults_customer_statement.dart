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
  return ReportBands(
    header:
        '# {{ workspace }}\n> {{ workspace_address }}\n---\n'
        '{{ client_name }}\n> {{ client_address }}\n---\n'
        '# $title\n> ${l10n.customerStatementAsOf('{{ as_of }}')} · {{ currency }}',
    continuation: '{{ workspace }} — $title — {{ client_name }}\n---',
    body:
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
        '{% endif %}{% endfor %}---\n{% endif %}'
        '${l10n.customerStatementTotalDue} | {{ still_due_total }}\n'
        '${l10n.customerStatementTotalUnapplied} | − {{ unapplied_total }}\n'
        '{% if balance_owed_by == "customer" %}**${l10n.customerStatementBalanceDue}**'
        '{% endif %}{% if balance_owed_by == "business" %}**${l10n.customerStatementBalanceOwed}**'
        '{% endif %}{% if balance_owed_by == "none" %}**${l10n.customerStatementBalanceNone}**'
        '{% endif %} | **{{ balance }}**',
    footer: '> {{ workspace }} · {{ issued_by }} · {{ issued }}',
  );
}
