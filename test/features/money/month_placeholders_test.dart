// SPDX-License-Identifier: 0BSD
//
// #1002 — a design references the period's month and composes the
// recurring position's wording itself: « Septembre 100 % ».
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/widgets/report_field_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the registry knows the month and the year, and seeds them empty', () {
    expect(InvoicePdfTemplate.placeholders, containsAll(['period_month', 'period_year']));
    expect(InvoicePdfTemplate.placeholderDefaults['period_month'], '');
  });

  test('a band composes « Septembre 100 % » from the line fields', () {
    final report = renderReportBands(
      bands: const ReportBands(
        header: '{{ period_month }} {{ period_year }}',
        body: '{% for line in lines %}'
            '{% if line.kind == "subscription" %}{{ line.month }} {{ line.pct }} %'
            '{% else %}{{ line.label }}{% endif %}\n{% endfor %}',
      ),
      data: {
        'period_month': 'Septembre',
        'period_year': '2026',
        'lines': [
          {'label': 'Participation 100 %', 'kind': 'subscription', 'pct': '100', 'month': 'Septembre', 'amount': '100,00 €'},
          {'label': 'Café', 'kind': 'service', 'pct': '', 'month': 'Septembre', 'amount': '2,00 €'},
        ],
      },
    )!;
    expect((report.header.single as ReportText).text, 'Septembre 2026');
    final body = report.body.whereType<ReportText>().map((t) => t.text).join('\n');
    expect(body, contains('Septembre 100 %'));
    expect(body, contains('Café'));
    expect(body, isNot(contains('Participation')));
  });

  test('the picker offers the wording as the lines scaffold', () {
    expect(reportFieldMarkup('lines'), contains('line.month'));
    expect(reportFieldMarkup('lines'), contains('line.pct'));
  });
}
