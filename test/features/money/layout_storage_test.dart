// SPDX-License-Identifier: 0BSD
//
// #875 — where a positioned layout lives, and that it survives.
//
// A layout is stored beside the bands, per report kind, inside the
// template every other edit rebuilds. The failure this guards against
// is the quiet one: an owner edits a reminder, the rebuild forgets the
// invoice layout, and the next invoice silently comes out banded.
// (The same rebuilds had already been dropping the envelope-window
// choice; that is pinned here too.)
import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:flutter_test/flutter_test.dart';

const _xml = '<report-layout><body><text>x</text></body></report-layout>';

void main() {
  test('a layout is stored per kind and read back by the same kind', () {
    final kinds = reportKinds(reminderLevels: 2);
    for (final kind in kinds) {
      final t = withLayout(InvoicePdfTemplate.empty, kind, '<!-- ${kind.id} -->');
      expect(layoutOf(t, kind), '<!-- ${kind.id} -->',
          reason: '${kind.id} did not survive a write/read round trip');
      for (final other in kinds) {
        if (other.id == kind.id) continue;
        expect(layoutOf(t, other), isNull,
            reason: '${kind.id} wrote into ${other.id}');
      }
    }
  });

  test('an empty layout removes the kind\'s entry — it falls back to bands',
      () {
    final invoice = reportKindById('invoice')!;
    var t = withLayout(InvoicePdfTemplate.empty, invoice, _xml);
    expect(layoutOf(t, invoice), isNotNull);
    t = withLayout(t, invoice, '   ');
    expect(layoutOf(t, invoice), isNull);
    expect(t.layouts, isEmpty, reason: 'nothing left to store');
  });

  test('layouts survive JSON, and an empty one is not written', () {
    const t = InvoicePdfTemplate(layouts: {'invoice': _xml, 'proforma': ''});
    final json = t.toJson();
    expect(json[InvoicePdfTemplate.keyLayouts], {'invoice': _xml, 'proforma': ''});
    final back = InvoicePdfTemplate.fromJson(json.cast<String, dynamic>());
    expect(back.layoutFor('invoice'), _xml);
    expect(back.layoutFor('proforma'), isNull,
        reason: 'an empty string means "use the bands", not a layout');
    expect(InvoicePdfTemplate.empty.toJson().containsKey('layouts'), isFalse,
        reason: 'a template with no layouts writes no key — pre-#875 '
            'templates and new ones stay byte-identical');
  });

  test('every rebuild carries the layouts AND the envelope choice through',
      () {
    const before = InvoicePdfTemplate(
      layouts: {'invoice': _xml},
      addressWindow: AddressWindow.right,
    );
    final rebuilt = <String, InvoicePdfTemplate>{
      'copyWith': before.copyWith(invoice: const ReportBands(header: 'h')),
      'withDoc': before.withDoc('agreement', const ReportBands(body: 'b')),
      'withTranslation':
          before.withTranslation('fr', InvoicePdfTemplate.empty),
      'withReminder': before.withReminder(1, const ReportBands(footer: 'f')),
      'forLocale(unknown)': before.forLocale('xx'),
      'forLocale(fr)': before
          .withTranslation('fr', const InvoicePdfTemplate(header: 'fr'))
          .forLocale('fr'),
    };
    for (final entry in rebuilt.entries) {
      expect(entry.value.layoutFor('invoice'), _xml,
          reason: '${entry.key} dropped the layout');
      expect(entry.value.addressWindow, AddressWindow.right,
          reason: '${entry.key} dropped the envelope window');
    }
  });

  test('a language overlay\'s layout wins for its kind, and only its kind',
      () {
    const base = InvoicePdfTemplate(
        layouts: {'invoice': 'base-invoice', 'statement': 'base-statement'});
    final fr = base.withTranslation(
        'fr', const InvoicePdfTemplate(layouts: {'invoice': 'fr-invoice'}));
    final seen = fr.forLocale('fr');
    expect(seen.layoutFor('invoice'), 'fr-invoice');
    expect(seen.layoutFor('statement'), 'base-statement');
    expect(fr.forLocale('').layoutFor('invoice'), 'base-invoice',
        reason: 'no language → the base');
  });
}
