// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice_pdf_template.dart';

/// The configuration snapshot keeps labels as data, so the owner can
/// arrange its sections without losing the member and plan details. A
/// level's heading row may name its plan picture (#2898), printed under
/// the heading; a band that never asks for `row.image` prints none.
ReportBands configurationReportBands(String title) {
  return ReportBands(
    header: '# $title\n{{ workspace }}\n> {{ issued }}',
    continuation: '{{ workspace }} — $title — {{ issued }}\n---',
    body:
        '{% for row in configuration_rows %}'
        '{% if row.heading %}## {{ row.label }}\n'
        '{% if row.image %}![{{ row.image }}|xl|center]\n{% endif %}'
        '{% else %}{% if row.strong %}= {% endif %}'
        '{{ row.label }} | {{ row.value }} | {{ row.detail }}\n'
        '{% endif %}{% endfor %}',
    footer: '> {{ workspace }}',
  );
}
