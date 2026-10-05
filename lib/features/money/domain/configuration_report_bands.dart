// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice_pdf_template.dart';

/// The configuration snapshot keeps labels as data, so the owner can
/// arrange its sections without losing the member and plan details.
ReportBands configurationReportBands(String title) {
  return ReportBands(
    header: '# $title\n{{ workspace }}\n> {{ issued }}',
    continuation: '{{ workspace }} — $title — {{ issued }}\n---',
    body:
        '{% for row in configuration_rows %}'
        '{% if row.heading %}## {{ row.label }}\n'
        '{% else %}{% if row.strong %}= {% endif %}'
        '{{ row.label }} | {{ row.value }} | {{ row.detail }}\n'
        '{% endif %}{% endfor %}',
    footer: '> {{ workspace }}',
  );
}
