// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is that the components of a Canadian rate add up to its tax
//
// #2361 — GST 5 % + QST 9.975 % on the price without the GST: CAD 1 000.00
// -> 50.00 + 99.75 -> 1 149.75. Server twin `vat_components_entry`
// (migration 0423, pgTAP 180); the values below are the same ones.
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_components.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quebec: CAD 1 000.00 -> GST 50.00, QST 99.75, total 1 149.75', () {
    final split = vatSplit(114975, 14.975);
    expect((split.netCents, split.vatCents), (100000, 14975));
    final parts = vatComponentsOf('CA', 14.975, split.netCents, split.vatCents);
    expect(parts.map((c) => c.scheme), ['GST', 'QST']);
    expect(parts.map((c) => c.taxCents), [5000, 9975]);
    expect(parts.map((c) => c.authority), ['CA', 'CA-QC']);
    expect(parts.every((c) => c.baseCents == 100000), isTrue,
        reason: 'the QST is levied on the price without the GST');
  });

  test('the components always add up to the tax, odd cents included', () {
    for (final gross in [3333, 100001, 7, 99999, 1]) {
      for (final percent in [14.975, 12.0, 11.0]) {
        final s = vatSplit(gross, percent);
        final parts = vatComponentsOf('CA', percent, s.netCents, s.vatCents);
        expect(parts.fold<int>(0, (a, c) => a + c.taxCents), s.vatCents,
            reason: '$gross at $percent');
      }
    }
    // The values the pgTAP file pins on the server.
    final odd = vatSplit(3333, 14.975);
    expect(vatComponentsOf('CA', 14.975, odd.netCents, odd.vatCents)
        .map((c) => c.taxCents), [145, 289]);
  });

  test('the other provinces and countries', () {
    List<String> schemes(String cc, double p) =>
        vatComponentsOf(cc, p, 10000, 1000).map((c) => c.scheme).toList();
    expect(schemes('CA', 5), ['GST']);
    for (final hst in [13.0, 14.0, 15.0]) {
      final parts = vatComponentsOf('ca', hst, 10000, 1300);
      expect(parts.single.scheme, 'HST');
      expect(parts.single.percent, hst);
    }
    expect(schemes('CA', 12), ['GST', 'PST']);
    expect(schemes('CA', 7.5), isEmpty);
    for (final cc in ['DE', 'FR', 'GB', 'CH', 'US', '']) {
      expect(schemes(cc, 5), isEmpty, reason: cc);
      expect(vatComponentsOf(cc, 14.975, 100000, 14975), isEmpty, reason: cc);
    }
  });

  test('the preview and the frozen total read the same components', () {
    final totals = vatTotalsOf(
      const [(amountCents: 114975, vatPercent: 14.975)],
      zeroCategory: 'O',
      sellerCountry: 'CA',
    );
    expect(totals.single.components.map((c) => c.taxCents), [5000, 9975]);
    final frozen = InvoiceVatTotal.fromJson(<String, Object?>{
      'percent': 14.975,
      'category': 'S',
      'gross_cents': 114975,
      'net_cents': 100000,
      'vat_cents': 14975,
      'components': [
        {'scheme': 'GST', 'authority': 'CA', 'percent': 5, 'base_cents': 100000, 'tax_cents': 5000},
        {'scheme': 'QST', 'authority': 'CA-QC', 'percent': 9.975, 'base_cents': 100000, 'tax_cents': 9975},
      ],
    });
    expect(frozen.components.map((c) => (c.scheme, c.taxCents)),
        [('GST', 5000), ('QST', 9975)]);
    // Without a seller country nothing is split (EU, UK, CH: unchanged).
    expect(
      vatTotalsOf(const [(amountCents: 114975, vatPercent: 14.975)],
          zeroCategory: 'O').single.components,
      isEmpty,
    );
  });

  test('the catalogue: GST-only for the provinces that do not tax a desk', () {
    final rates = vatCatalogueFor('CA');
    expect(rates.map((r) => r.percent), [5, 13, 14, 15, 14.975]);
    expect(rates.first.isDefault, isTrue);
    expect(rates.map((r) => r.label).any((l) => l.contains('PST')), isFalse);
    expect(rates.first.label, contains('BC'));
    // Every catalogue rate is either a plain tax or splits into its parts.
    for (final r in rates) {
      final parts = vatComponentsOf('CA', r.percent, 100000, 1);
      expect(parts, isNotEmpty, reason: r.label);
      expect(parts.fold<double>(0, (a, c) => a + c.percent), closeTo(r.percent, 1e-9));
    }
  });
}
