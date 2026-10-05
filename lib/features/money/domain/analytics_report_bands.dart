// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice_pdf_template.dart';

/// Editable report chrome surrounds the dashboard's authoritative charts.
ReportBands analyticsReportBands(String title) => ReportBands(
  header: '# $title\n{{ workspace }}\n> {{ period }}\n> {{ issued }}',
  continuation: '{{ workspace }} — $title — {{ period }}\n---',
  body: '',
  footer: '> {{ workspace }}',
);
