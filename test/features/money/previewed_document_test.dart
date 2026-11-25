// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4405 -- one previewed document for the standalone invoice and for the
// invoice an accepted quote would become: the lines, the tax per rate and the
// total; a document whose lines do not add up to the accepted total is refused.
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/previewed_document.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _line(String label, String id, int net, int tax, num pct) => {
  'kind': 'service',
  'label': label,
  'supply': 'general',
  'vat_percent': pct,
  'vat_category': 'S',
  'commercial': {
    'version': 1,
    'line_id': id,
    'quantity': '1',
    'unit': {'code': 'unit', 'label': 'x', 'un_ece_code': 'C62'},
    'unit_price': {'amount': '${net / 100}', 'currency': 'EUR', 'basis': 'net', 'base_quantity': '1'},
    'supply': 'general',
    'tax_facts': <String, Object?>{},
    'amounts': {'currency': 'EUR', 'net_minor': '$net', 'tax_minor': '$tax', 'gross_minor': '${net + tax}'},
  },
};

QuoteRevision _accepted(List<Map<String, Object?>> lines) => CustomerQuote.fromJson({
  'quote_id': 'q',
  'subject_id': 's',
  'reference': 'QUO-1',
  'status': 'accepted',
  'expired': false,
  'revisions': [
    {
      'revision': 1,
      'status': 'sent',
      'draft_version': 1,
      'issued_on': '2026-11-01',
      'valid_until': '2026-12-01',
      'lines': lines,
    },
  ],
}).revisions.single;

QuoteConversionPrep _prep({List<String> missing = const [], int accepted = 14000, int? wouldBe = 14000}) => QuoteConversionPrep(
  draftRevision: 1,
  missing: missing,
  acceptedTotalCents: accepted,
  wouldBeTotalCents: wouldBe,
  currency: 'EUR',
  contextChanged: false,
  reviewDigest: '',
);

void main() {
  final lines = [_line('Design', 'a', 10000, 2000, 20), _line('Print', 'b', 1800, 200, 10)];

  group('the server\'s preview is read one to one', () {
    test('a ready document: lines, total, currency and the tax per rate', () {
      final d = PreviewedDocument.fromJson({
        'missing': <String>[],
        'preview': {
          'lines': [lines.first],
          'total_cents': 12000,
          'currency': 'EUR',
          'vat_totals': [
            {'percent': 20, 'category': 'S', 'gross_cents': 12000, 'net_cents': 10000, 'vat_cents': 2000},
          ],
        },
      });
      expect(d.ready, isTrue);
      expect(d.totalCents, 12000);
      expect(d.vatTotals.single.vatCents, 2000);
    });

    test('a missing fact has no lines and no total', () {
      final d = PreviewedDocument.fromJson({'missing': ['due_on'], 'preview': null});
      expect(d.missing, ['due_on']);
      expect(d.ready, isFalse);
      expect(d.totalCents, 0);
    });
  });

  group('the invoice of an accepted quote', () {
    test('is the accepted revision\'s own lines, taxed per rate, at the total the issuer would freeze', () {
      final accepted = _accepted(lines);
      final d = _prep().documentOf(accepted);
      expect(d.ready, isTrue);
      expect(d.lines.map((l) => l.label), ['Design', 'Print']);
      expect(d.vatTotals.map((t) => t.percent), [20, 10], reason: 'the highest rate first');
      expect(d.vatTotals.map((t) => t.vatCents), [2000, 200]);
      expect(d.totalCents, 14000);
      expect(d.currency, 'EUR');
    });

    test('lines that do not add up to the accepted total are refused, never shown with one of the two', () {
      final d = _prep(accepted: 13000).documentOf(_accepted(lines));
      expect(d.ready, isFalse);
      expect(d.missing, [totalMismatchKey]);
      expect(d.lines, isEmpty);
      expect(d.totalCents, 0);
    });

    test('what the issuer cannot accept is passed on as it named it', () {
      final d = _prep(missing: ['due_on'], wouldBe: null).documentOf(_accepted(lines));
      expect(d.missing, ['due_on']);
      expect(d.ready, isFalse);
    });

    test('a changed total on the server side is its own to report: the lines still stand against what was accepted', () {
      final d = _prep(wouldBe: 15000).documentOf(_accepted(lines));
      expect(d.ready, isTrue);
      expect(d.totalCents, 15000);
    });
  });
}
