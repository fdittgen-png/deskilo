// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the default bands of the three book reports: the general
// ledger, the trial balance and the journals. One shape serves the three:
// the rows carry their own headings and totals (`book_rows`), so an owner
// redesigns the columns once and every book report follows.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_kind.dart';
import 'report_kind_labels.dart';

/// The bands of the book report [kindId], titled with its label.
ReportBands bookReportBands(AppLocalizations l10n, String kindId) {
  final kind = reportKindById(kindId);
  final title = kind == null ? kindId : reportKindLabel(l10n, kind);
  return ReportBands(
    header:
        '''
# {{ workspace }}
> {{ workspace_address }}
---
# $title
> {{ book_period }}''',
    continuation: '{{ workspace }} — $title — {{ book_period }}\n---',
    body:
        '= ${l10n.bookReportEntry} | ${l10n.bookReportDebit} | '
        '${l10n.bookReportCredit} | ${l10n.bookReportBalance}\n'
        '{% for row in book_rows %}'
        '{% if row.heading %}## {{ row.label }}\n'
        '{% else %}{% if row.strong %}= {{ row.label }}'
        '{% else %}{{ row.label }}{% if row.detail != "" %} · {{ row.detail }}{% endif %}'
        '{% endif %} | {{ row.debit }} | {{ row.credit }} | {{ row.balance }}\n'
        '{% endif %}{% endfor %}',
    footer: '> ${l10n.bookReportFooter}',
  );
}
