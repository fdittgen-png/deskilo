// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the Dart tax-point engine and its SQL twin compute the same
// return. The declaration stores the server's figures
// (`compute_vat_return`, migration 0402); the VAT report, the FEC and
// DATEV still read this engine. Both are pinned to ONE fixture: the
// invoices, payments and expected figures below are those of
// `supabase/tests/database/166_vat_return.sql`, so a change to either
// side that moves a cent fails one of the two files.
//
// France on receipts: a half-paid two-rate invoice, a settlement paid
// for its source, a refunded credit note, an invoice that printed the
// debits option, reverse-charged, exempt and zero-rated sales, a voided
// and an unpaid invoice. Germany on the service period: September
// services paid on 2 September, on 20 August, and unpaid.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/accounting_view.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';

const _receipts = {'seller_country': 'FR', 'vat_exigibility': 'payment'};
const _debits = {'seller_country': 'FR', 'vat_exigibility': 'invoice'};
const _german = {'seller_country': 'DE', 'vat_exigibility': 'invoice'};

/// 10:00 UTC, as the SQL fixture stores every instant.
DateTime _at(int month, int day) => DateTime.utc(2026, month, day, 10);

Invoice _invoice(
  String number,
  DateTime issuedAt,
  List<(int, double, String)> lines, {
  Map<String, Object?> legal = _receipts,
  String? period,
  InvoiceKind kind = InvoiceKind.full,
  DateTime? voidedAt,
  List<SettledSource> settles = const [],
}) {
  final total = lines.fold(0, (sum, l) => sum + l.$1);
  return Invoice(
    id: number,
    workspaceId: 'ws',
    memberId: 'm',
    number: number,
    issuedAt: issuedAt,
    period: period,
    title: number,
    lines: [
      for (final l in lines)
        InvoiceLine(label: number, amountCents: l.$1, vatPercent: l.$2),
    ],
    kind: kind,
    settles: settles,
    legalSnapshot: legal,
    vatTotals: [
      for (final l in {for (final l in lines) l.$2: l.$3}.entries)
        InvoiceVatTotal(
          percent: l.key,
          category: l.value,
          grossCents: 0,
          netCents: 0,
          vatCents: 0,
        ),
    ],
    totalCents: total,
    currency: 'EUR',
    memberName: 'M',
    memberAddress: '',
    workspaceName: 'Return',
    workspaceAddress: '',
    issuerName: 'M',
    signature: 's',
    voidedAt: voidedAt,
  );
}

InvoiceMatch _paid(String id, int cents, DateTime on) => InvoiceMatch(
  invoiceId: id,
  paidCents: cents,
  resolution: 'exact',
  matchedAt: on,
);

/// The France fixture, through the accountant's view as the server sees it.
({List<Invoice> invoices, Map<String, InvoiceMatch> matches}) _france() {
  final invoices = [
    _invoice('F-A', _at(8, 20), [(12000, 20, 'S'), (3300, 10, 'S')]),
    _invoice('F-AE', _at(9, 10), [(50000, 0, 'AE')]),
    _invoice('F-E', _at(9, 15), [(8000, 0, 'E')]),
    _invoice('F-Z', _at(9, 16), [(3000, 0, 'Z')]),
    _invoice('CN-1', _at(9, 18), [(-2400, 20, 'S')]),
    _invoice(
      'S-1',
      _at(9, 1),
      [(2400, 20, 'S')],
      kind: InvoiceKind.settlement,
      settles: const [
        SettledSource(
          invoiceId: 'F-G',
          number: 'F-G',
          period: null,
          kind: InvoiceKind.full,
          totalCents: 2400,
          lines: [],
        ),
      ],
    ),
    _invoice('F-G', _at(8, 25), [(2400, 20, 'S')]),
    _invoice('F-D', _at(9, 22), [(1200, 20, 'S')], legal: _debits),
    _invoice('F-V', _at(9, 3), [(9900, 20, 'S')], voidedAt: _at(9, 4)),
    _invoice('F-U', _at(9, 20), [(6000, 20, 'S')]),
  ];
  return accountingView(invoices, {
    'F-A': _paid('F-A', 15300, _at(10, 3)),
    'F-AE': _paid('F-AE', 50000, _at(9, 12)),
    'F-E': _paid('F-E', 8000, _at(9, 15)),
    'F-Z': _paid('F-Z', 3000, _at(9, 20)),
    'CN-1': _paid('CN-1', 2400, _at(9, 25)),
    'S-1': _paid('S-1', 2400, _at(9, 8)),
  });
}

final _instalments = {
  'F-A': [TaxPointPayment(_at(9, 5), 7650), TaxPointPayment(_at(10, 3), 7650)],
};

/// compute_vat_return's line shape: per (rate, category, tax point,
/// credit note), in its order.
List<(double, String, DateTime, bool, int, int, int, int)> _lines(
  List<Invoice> invoices,
  List<VatTaxPointAmount> amounts,
  DateTime start,
  DateTime end,
) {
  final byId = {for (final i in invoices) i.id: i};
  final sums = <(double, String, DateTime, bool), (int, int, Set<String>)>{};
  for (final a in amounts) {
    if (!a.within(start, end)) continue;
    final invoice = byId[a.invoiceId]!;
    final category = invoice.vatTotals
        .firstWhere((t) => t.percent == a.percent)
        .category;
    final key = (a.percent, category, a.on, invoice.isCreditNote);
    final seen = sums[key] ?? (0, 0, <String>{});
    sums[key] = (
      seen.$1 + a.grossCents,
      seen.$2 + a.netCents,
      seen.$3..add(a.invoiceId),
    );
  }
  final keys = sums.keys.toList()
    ..sort((x, y) {
      final byRate = y.$1.compareTo(x.$1);
      if (byRate != 0) return byRate;
      final byCategory = x.$2.compareTo(y.$2);
      if (byCategory != 0) return byCategory;
      final byDay = x.$3.compareTo(y.$3);
      if (byDay != 0) return byDay;
      return (x.$4 ? 1 : 0).compareTo(y.$4 ? 1 : 0);
    });
  return [
    for (final k in keys)
      (
        k.$1,
        k.$2,
        k.$3,
        k.$4,
        sums[k]!.$1,
        sums[k]!.$2,
        sums[k]!.$1 - sums[k]!.$2,
        sums[k]!.$3.length,
      ),
  ];
}

void main() {
  tearDown(WorkspaceTime.reset);

  group('France on receipts — the 166_vat_return.sql fixture', () {
    setUp(() => WorkspaceTime.install('Europe/Paris'));

    List<VatTaxPointAmount> ledger() {
      final view = _france();
      return vatTaxPointLedger(
        view.invoices,
        matches: view.matches,
        instalments: _instalments,
        basis: vatTaxPointBasis('FR', null),
      );
    }

    test('September: the same lines compute_vat_return returns', () {
      final view = _france();
      expect(
        _lines(
          view.invoices,
          ledger(),
          DateTime(2026, 9),
          DateTime(2026, 9, 30),
        ),
        [
          (20.0, 'S', DateTime(2026, 9, 5), false, 6000, 5000, 1000, 1),
          (20.0, 'S', DateTime(2026, 9, 8), false, 2400, 2000, 400, 1),
          (20.0, 'S', DateTime(2026, 9, 22), false, 1200, 1000, 200, 1),
          (20.0, 'S', DateTime(2026, 9, 25), true, -2400, -2000, -400, 1),
          (10.0, 'S', DateTime(2026, 9, 5), false, 1650, 1500, 150, 1),
          (0.0, 'AE', DateTime(2026, 9, 12), false, 50000, 50000, 0, 1),
          (0.0, 'E', DateTime(2026, 9, 15), false, 8000, 8000, 0, 1),
          (0.0, 'Z', DateTime(2026, 9, 20), false, 3000, 3000, 0, 1),
        ],
      );
    });

    test('the totals save_vat_declaration stores', () {
      final amounts = ledger();
      final lines = vatDeclarationLinesOf(
        amounts,
        DateTime(2026, 9),
        DateTime(2026, 9, 30),
      );
      expect(lines.fold(0, (s, l) => s + l.netCents), 68500);
      expect(lines.fold(0, (s, l) => s + l.vatCents), 1350);
      expect(
        {
          for (final a in amounts)
            if (a.within(DateTime(2026, 9), DateTime(2026, 9, 30))) a.invoiceId,
        },
        {'F-A', 'F-G', 'F-D', 'CN-1', 'F-AE', 'F-E', 'F-Z'},
        reason:
            'the settlement, the voided and the unpaid invoice count '
            'for nothing',
      );
    });

    test('October holds the other half; August nothing', () {
      final view = _france();
      expect(
        _lines(
          view.invoices,
          ledger(),
          DateTime(2026, 10),
          DateTime(2026, 10, 31),
        ).map((l) => (l.$1, l.$5, l.$6)),
        [(20.0, 6000, 5000), (10.0, 1650, 1500)],
      );
      expect(
        _lines(
          view.invoices,
          ledger(),
          DateTime(2026, 8),
          DateTime(2026, 8, 31),
        ),
        isEmpty,
      );
    });
  });

  group('Germany on the service period — the same fixture', () {
    setUp(() => WorkspaceTime.install('Europe/Berlin'));

    List<VatTaxPointAmount> ledger() {
      final invoices = [
        for (final n in ['D-1', 'D-2'])
          _invoice(
            n,
            _at(8, 25),
            [(12000, 19, 'S')],
            legal: _german,
            period: '2026-09',
          ),
        _invoice(
          'D-3',
          _at(8, 25),
          [(5950, 19, 'S')],
          legal: _german,
          period: '2026-09',
        ),
      ];
      return vatTaxPointLedger(
        invoices,
        matches: {
          'D-1': _paid('D-1', 12000, _at(9, 2)),
          'D-2': _paid('D-2', 12000, _at(8, 20)),
        },
        basis: vatTaxPointBasis('DE', null),
      );
    }

    test('paid 2 September: September; unpaid: the end of the month', () {
      final september = [
        for (final a in ledger())
          if (a.within(DateTime(2026, 9), DateTime(2026, 9, 30)))
            (a.on, a.grossCents, a.netCents, a.vatCents),
      ];
      expect(september, [
        (DateTime(2026, 9, 2), 12000, 10084, 1916),
        (DateTime(2026, 9, 30), 5950, 5000, 950),
      ]);
    });

    test('paid 20 August, before the service: August', () {
      final august = [
        for (final a in ledger())
          if (a.within(DateTime(2026, 8), DateTime(2026, 8, 31)))
            (a.on, a.grossCents, a.vatCents),
      ];
      expect(august, [(DateTime(2026, 8, 20), 12000, 1916)]);
    });
  });

  group('the basis an invoice froze', () {
    final unpaid = _invoice('X', _at(9, 22), [(1200, 20, 'S')]);

    test('printed on receipts, it waits for the money on an invoice-date '
        'basis', () {
      expect(
        frozenTaxPointBasis(unpaid, VatTaxPointBasis.invoiceDate),
        VatTaxPointBasis.receipt,
      );
    });

    test('printed on the debits, it is due when issued on receipts', () {
      expect(
        frozenTaxPointBasis(
          unpaid.copyWith(legalSnapshot: _debits),
          VatTaxPointBasis.receipt,
        ),
        VatTaxPointBasis.invoiceDate,
      );
    });

    test('a Spanish invoice on receipts keeps its country\'s backstop', () {
      expect(
        frozenTaxPointBasis(
          unpaid.copyWith(
            legalSnapshot: {
              'seller_country': 'ES',
              'vat_exigibility': 'payment',
            },
          ),
          const VatTaxPointBasis(VatTaxPointRule.servicePeriod),
        ),
        const VatTaxPointBasis(
          VatTaxPointRule.receipt,
          VatCashBackstop.endOfFollowingYear,
        ),
      );
    });

    test('no snapshot: the workspace basis', () {
      expect(
        frozenTaxPointBasis(
          unpaid.copyWith(legalSnapshot: null),
          VatTaxPointBasis.invoiceDate,
        ),
        VatTaxPointBasis.invoiceDate,
      );
    });
  });
}
