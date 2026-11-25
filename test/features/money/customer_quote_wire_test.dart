// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 — a sent revision is read the way the server answers it. Its `lines`
// are the invoice line snapshot the issuer froze (`label`, the exact facts in
// `commercial`), not the lines as they were entered: the fixture below is the
// line `standalone_invoice_line_v1` returned on the dev project for two hours
// at 150 EUR net and 20 %, inside a `customer_quote_v1` answer, and the Demo's
// quotes answer the same shape through the same reader.
import 'package:deskilo/core/demo/data/fake_customer_quotes.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// `customer_quote_v1` for a quote sent once: the frozen line is the real
/// snapshot, the draft is absent.
const Map<String, Object?> _sentOnTheServer = {
  'quote_id': 'q-1',
  'subject_id': 's-1',
  'reference': 'QUO-0001',
  'status': 'sent',
  'expired': false,
  'revisions': [
    {
      'revision': 1,
      'status': 'sent',
      'draft_version': 1,
      'issued_on': '2026-11-20',
      'valid_until': '2026-12-20',
      'buyer_reference': '',
      'purchase_order': '',
      'notes': '',
      'lines': [
        {
          'kind': 'service',
          'label': 'Consulting',
          'supply': 'general',
          'quantity': 1,
          'commercial': {
            'unit': {'code': 'hour', 'label': 'hours', 'un_ece_code': 'HUR'},
            'supply': 'general',
            'amounts': {
              'rule': 'half_up_per_line',
              'currency': 'EUR',
              'net_minor': '30000',
              'tax_minor': '6000',
              'gross_minor': '36000',
            },
            'line_id': '6f1b2c3d-0000-4000-8000-000000000001',
            'version': 1,
            'quantity': '2',
            'tax_facts': {
              'category': 'S',
              'tax_point': '2026-11-20',
              'vat_percent': 20,
            },
            'unit_price': {
              'basis': 'net',
              'amount': '150',
              'currency': 'EUR',
              'base_quantity': '1',
            },
          },
          'vat_percent': 20,
          'amount_cents': 36000,
          'vat_category': 'S',
        },
      ],
      'totals': {'total_cents': 36000, 'currency': 'EUR'},
      'content_digest': 'abc',
      'superseded': false,
    },
  ],
  'decision': null,
  'conversion': null,
};

void main() {
  test('a sent revision reads the frozen snapshot: what the customer was '
      'offered, not an empty line', () {
    final line = CustomerQuote.fromJson(_sentOnTheServer).current!.lines.single;

    expect(line.description, 'Consulting');
    expect(line.quantity, '2');
    expect(line.unitLabel, 'hours');
    expect(line.unitCode, 'hour');
    expect(line.unEceCode, 'HUR');
    expect(line.unitPrice, '150');
    expect(line.baseQuantity, '1');
    expect(line.grossPrice, isFalse);
    expect(line.lineId, '6f1b2c3d-0000-4000-8000-000000000001');
    expect(
      CustomerQuote.fromJson(_sentOnTheServer).current!.totals!.totalCents,
      36000,
    );
  });

  test('a frozen line the package cannot interpret is a read failure, never a line worth nothing', () {
    final revision = ((_sentOnTheServer['revisions']! as List).single as Map).cast<String, Object?>();
    final line = Map<String, Object?>.of(((revision['lines']! as List).single as Map).cast<String, Object?>());
    final commercial = Map<String, Object?>.of((line['commercial']! as Map).cast<String, Object?>())..['version'] = 9;
    Object? read(Map<String, Object?> frozen) => CustomerQuote.fromJson({
      ..._sentOnTheServer,
      'revisions': [
        {
          ...revision,
          'lines': [frozen],
        },
      ],
    });

    expect(
      () => read({...line, 'commercial': commercial}),
      throwsA(isA<JsonShapeException>().having((e) => e.key, 'key', 'lines[0].commercial')),
    );
    expect(
      () => read({...line, 'amount_cents': 500}..remove('commercial')),
      throwsA(isA<JsonShapeException>()),
      reason: 'amounts with no frozen facts is not a text line',
    );
    final text = (read({'kind': 'text', 'label': 'Thank you', 'quantity': 1}) as CustomerQuote).current!;
    expect(text.lines.single.description, 'Thank you');
  });

  test('a draft revision keeps the lines as they were entered', () {
    final draft = {
      ..._sentOnTheServer,
      'status': 'draft',
      'revisions': [
        {
          ...(_sentOnTheServer['revisions']! as List).single as Map,
          'status': 'draft',
          'totals': null,
          'lines': [
            {
              'description': 'Consulting',
              'quantity': '2',
              'unit': {'code': 'hour', 'label': 'hours', 'un_ece_code': 'HUR'},
              'unit_price': '150',
              'basis': 'net',
              'base_quantity': '1',
              'supply': 'general',
            },
          ],
        },
      ],
    };
    final line = CustomerQuote.fromJson(draft).draft!.lines.single;

    expect(line.description, 'Consulting');
    expect(line.unitPrice, '150');
  });

  test('the Demo answers the server\'s shape: a sent quote shows what was '
      'entered, in the same words through the same reader', () async {
    final quotes =
        FakeCustomerQuoteRepository(clock: () => DateTime(2026, 11, 20))
          ..seedSent(
            'ws-1',
            subjectId: 's-1',
            lines: [
              const StandaloneLine(
                description: 'Consulting',
                quantity: '2',
                unitCode: 'hour',
                unitLabel: 'hours',
                unitPrice: '150',
              ),
            ],
            issuedOn: DateTime(2026, 11, 20),
            validUntil: DateTime(2026, 12, 20),
          );

    final sent = (await quotes.quotes('ws-1')).single.current!;

    expect(sent.lines.single.description, 'Consulting');
    expect(sent.lines.single.quantity, '2');
    expect(sent.lines.single.unitLabel, 'hours');
    expect(sent.lines.single.unitPrice, '150');
    expect(sent.totals!.totalCents, 36000, reason: '300 net + 20 % VAT');
  });

  group('#4405 a wire field the server always sends is never defaulted', () {
    Map<String, Object?> prep({Object? accepted = '36000', Object? preview = const {'preview': {'total_cents': 36000, 'currency': 'EUR'}}}) => {
      'draft_id': 'd-1',
      'draft_revision': 2,
      'quote_revision': 1,
      'preview': {'missing': <String>[], 'preview': preview},
      'accepted_total_cents': accepted,
      'context_changed': false,
      'review_digest': 'abc',
    };

    test('an accepted total that is not an amount is a decoding error, not a zero', () {
      expect(QuoteConversionPrep.fromJson(prep()).acceptedTotalCents, 36000);
      expect(() => QuoteConversionPrep.fromJson(prep(accepted: 'n/a')), throwsFormatException);
      expect(() => QuoteConversionPrep.fromJson(prep(accepted: null)), throwsA(isA<JsonShapeException>()));
    });

    test('a preview with no total reads as no total, not as zero', () {
      final p = QuoteConversionPrep.fromJson(prep(preview: const {'missing': ['due_on']}));
      expect(p.wouldBeTotalCents, isNull);
    });

    test('a revision without its draft version is refused', () {
      final revision = Map<String, Object?>.of(((_sentOnTheServer['revisions']! as List).single as Map).cast<String, Object?>())
        ..remove('draft_version');
      expect(() => QuoteRevision.fromJson(JsonReader.of(revision, context: 'revision')), throwsA(isA<JsonShapeException>()));
    });
  });
}
