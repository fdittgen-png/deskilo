// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- the expiry report's built-in bands: the letterhead, the title and the reference date, then a line for each lot
// (or piece) with where it is and what it holds on the left and its date and how far it is from the reference date on the right,
// and one line when nothing is expired or expiring. The data is stockExpiryReportData's.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';

ReportBands stockExpiryBands(AppLocalizations l10n) {
  final title = l10n.reportDocStockExpiry;
  return ReportBands(
    header: [
      '# {{ workspace }}',
      '> {{ workspace_address }}',
      '---',
      '# $title',
      '> ${l10n.customerStatementAsOf('{{ as_of }}')}'
          ' · {% if scope == "expired" %}${l10n.stockExpiryScopeExpired}{% endif %}'
          '{% if scope == "expiring" %}${l10n.stockExpiryScopeExpiring}{% endif %}'
          '{% if scope == "both" %}${l10n.stockExpiryScopeBoth}{% endif %}',
    ].join('\n'),
    continuation: '{{ workspace }} — $title\n---',
    body: [
      '{% if no_rows %}${l10n.stockExpiryNone}\n{% endif %}',
      '{% for row in rows %}'
          '**{{ row.item }}**{% if row.variant != "" %} · {{ row.variant }}{% endif %}'
          '{% if row.lot != "" %} · {{ row.lot }}{% endif %}{% if row.tag != "" %} · {{ row.tag }}{% endif %}'
          ' · {{ row.place }} · {{ row.quantity }}'
          ' | {{ row.expires }} · '
          '{% if row.state == "expired" %}${l10n.stockExpiryDaysPast('{{ row.days }}')}{% endif %}'
          '{% if row.state == "today" %}${l10n.taskRecorderValueToday}{% endif %}'
          '{% if row.state == "expiring" %}${l10n.stockExpiryDaysAhead('{{ row.days }}')}{% endif %}\n'
          '{% endfor %}',
    ].join('\n'),
    footer: '> {{ workspace }} · {{ issued_by }} · {{ issued }}',
  );
}
