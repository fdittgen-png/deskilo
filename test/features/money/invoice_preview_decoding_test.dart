// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 — preview_invoice is decoded strictly: no fabricated empty invoice,
// zero total, or truncated money.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/money/data/invoice_preview_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final shape = throwsA(isA<JsonShapeException>());

  Map<String, Object?> line({
    Object? kind = 'subscription',
    Object? label = 'Plan',
    Object? quantity = 1,
    Object? amount = 1500,
  }) =>
      {'kind': kind, 'label': label, 'quantity': quantity, 'amount_cents': amount};

  test('a present empty list and a total of 0 are valid', () {
    final p = decodeInvoicePreview({'lines': <Object?>[], 'total_cents': 0});
    expect(p.lines, isEmpty);
    expect(p.totalCents, 0);
  });

  test('lines and total decode exactly, in order', () {
    final p = decodeInvoicePreview({
      'lines': [
        line(),
        line(kind: 'overage', label: '', quantity: 3, amount: 450),
      ],
      'total_cents': 1950,
    });
    expect(p.lines.map((l) => l.kind), ['subscription', 'overage']);
    expect(p.lines.map((l) => l.quantity), [1, 3]);
    expect(p.lines.map((l) => l.amountCents), [1500, 450]);
    expect(p.lines.first.label, 'Plan');
    expect(p.totalCents, 1950);
  });

  test('a credit preview (negative amounts) stays valid', () {
    final p = decodeInvoicePreview({
      'lines': [line(kind: 'adjustment', amount: -2000)],
      'total_cents': -2000,
    });
    expect(p.totalCents, -2000);
    expect(p.lines.single.amountCents, -2000);
  });

  test('an integral double from a JSON codec is accepted', () {
    final p = decodeInvoicePreview({
      'lines': [line(amount: 1500.0)],
      'total_cents': 1500.0,
    });
    expect(p.totalCents, 1500);
  });

  test('a missing, null or wrong-type lines/total refuses', () {
    expect(() => decodeInvoicePreview({'total_cents': 0}), shape);
    expect(() => decodeInvoicePreview({'lines': null, 'total_cents': 0}), shape);
    expect(() => decodeInvoicePreview({'lines': <Object?>[]}), shape);
    expect(
      () => decodeInvoicePreview({'lines': <Object?>[], 'total_cents': null}),
      shape,
    );
    expect(() => decodeInvoicePreview({'lines': <String, Object?>{}, 'total_cents': 0}), shape);
    expect(() => decodeInvoicePreview({'lines': 'x', 'total_cents': 0}), shape);
    expect(
      () => decodeInvoicePreview({'lines': <Object?>[], 'total_cents': '100'}),
      shape,
    );
    expect(() => decodeInvoicePreview(null), shape);
    expect(() => decodeInvoicePreview(<Object?>[]), shape);
  });

  test('fractional or unsafe minor units are rejected, not truncated', () {
    expect(
      () => decodeInvoicePreview({'lines': <Object?>[], 'total_cents': 10.5}),
      shape,
    );
    expect(
      () => decodeInvoicePreview({'lines': [line(amount: 99.9)], 'total_cents': 99}),
      shape,
    );
    expect(
      () => decodeInvoicePreview({
        'lines': <Object?>[],
        'total_cents': 1e300,
      }),
      shape,
    );
    expect(
      () => decodeInvoicePreview({
        'lines': <Object?>[],
        'total_cents': double.nan,
      }),
      shape,
    );
    expect(
      () => decodeInvoicePreview({
        'lines': <Object?>[],
        'total_cents': 9007199254740993.0,
      }),
      shape,
    );
  });

  test('a line missing a required field or with a wrong type refuses', () {
    Object? decode(Map<String, Object?> l) =>
        decodeInvoicePreview({'lines': [l], 'total_cents': 0});
    expect(() => decode(line(kind: null)), shape);
    expect(() => decode(line(kind: 4)), shape);
    expect(() => decode(line(quantity: null)), shape);
    expect(() => decode(line(quantity: 1.5)), shape);
    expect(() => decode(line(amount: null)), shape);
    expect(() => decode(line(amount: '1500')), shape);
    expect(() => decode(line(label: 9)), shape);
    expect(() => decodeInvoicePreview({'lines': ['x'], 'total_cents': 0}), shape);
  });

  test('an unlabelled line keeps an empty label; vat_percent is optional', () {
    final p = decodeInvoicePreview({
      'lines': [
        line(label: null),
        {...line(), 'vat_percent': 20},
      ],
      'total_cents': 3000,
    });
    expect(p.lines.first.label, '');
    expect(p.lines.first.vatPercent, 0);
    expect(p.lines.last.vatPercent, 20);
  });
}
