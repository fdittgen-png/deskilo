// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#3292): the French VAT returns the Demo seeds — the filed one and
// the prepared one — are due on receipts (the tax point of French services):
// at four boundary clocks each return's gross is the money received in its
// quarter on taxable invoices, net of refunds paid, and its VAT per rate is the
// VAT those receipts carry, both recomputed here from the seeded matches, not
// from the VAT engine. The filed return's declared amounts are its lines;
// preparing the open quarter again or filing it changes neither. A receipt
// recorded later but dated inside the filed quarter leaves the filed return as
// it was and reaches the next return as a correction of that quarter, for the
// hand-stated amounts of the invoice it pays.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

/// What [money] received in [start]..[end] on its taxable invoices, read from
/// the matches and instalments: the gross, and per rate the VAT it carries
/// with the number of invoices only part-paid in the quarter (each may round
/// by a cent).
({int gross, Map<double, int> vat, Map<double, int> partial}) _received(
  FakeMoneyRepository money,
  DateTime start,
  DateTime end,
) {
  bool inside(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  var gross = 0;
  final vat = <double, int>{};
  final partial = <double, int>{};
  for (final i in money.invoices) {
    if (i.isVoided || i.vatTotals.isEmpty) continue;
    final match = money.invoiceMatchesStore[i.id];
    if (match == null || match.pending) continue;
    final instalments = money.invoiceInstalmentsStore[i.id] ?? const [];
    final receipts = instalments.isEmpty
        ? [(on: match.matchedAt, cents: match.paidCents)]
        : [for (final p in instalments) (on: p.on, cents: p.cents)];
    final cents = receipts
        .where((r) => inside(r.on))
        .fold(0, (int n, r) => n + r.cents);
    if (cents == 0) continue;
    // A credit note's refund pays money out: it lowers the quarter.
    final sign = i.totalCents < 0 ? -1 : 1;
    gross += sign * cents;
    final whole = cents == i.totalCents.abs();
    for (final t in i.vatTotals) {
      final share = whole
          ? t.vatCents
          : (t.vatCents * cents / i.totalCents.abs()).round() * sign;
      vat[t.percent] = (vat[t.percent] ?? 0) + share;
      if (!whole) partial[t.percent] = (partial[t.percent] ?? 0) + 1;
    }
  }
  return (gross: gross, vat: vat, partial: partial);
}

void _receiptsBasis(FakeMoneyRepository money, VatDeclaration d) {
  final expected = _received(money, d.periodStart, d.periodEnd);
  final regular = d.lines.where((l) => l.corrects.isEmpty).toList();
  expect(
    regular.fold(0, (int n, l) => n + l.grossCents),
    expected.gross,
    reason: '${d.id}: the gross is the money received in the quarter',
  );
  for (final l in regular) {
    expect(l.netCents + l.vatCents, l.grossCents, reason: '${d.id} ${l.percent}');
    expect(
      (l.vatCents - (expected.vat[l.percent] ?? 0)).abs(),
      lessThanOrEqualTo(expected.partial[l.percent] ?? 0),
      reason: '${d.id} ${l.percent} %: the VAT the receipts carry',
    );
  }
}

List<(double, int, int, int, String)> _lines(VatDeclaration d) => [
  for (final l in d.lines)
    (l.percent, l.grossCents, l.netCents, l.vatCents, l.corrects),
];

void main() {
  for (final now in [
    DateTime(2026, 5, 13, 10), // the Demo's own clock
    DateTime(2026, 3, 31, 23, 30), // the last half hour of a quarter
    DateTime(2026, 4, 1, 0, 30), // the first of the next
    DateTime(2027, 1, 1, 10), // a new year
  ]) {
    group('the Demo opened on $now', () {
      test('the filed and the prepared returns are due on receipts, as the '
          'seeded matches state them', () {
        final money = DemoFixture.build(now: now).money;
        expect(money.vatReturnBasis.rule, VatTaxPointRule.receipt);
        final filed = money.vatDeclarations.singleWhere((d) => d.isFiled);
        final prepared = money.vatDeclarations.singleWhere((d) => d.isPrepared);
        // The two quarters closed before the one [now] is in, in order.
        final quarter = DateTime(now.year, (now.month - 1) ~/ 3 * 3 + 1);
        expect(prepared.periodStart, DateTime(quarter.year, quarter.month - 3));
        expect(filed.periodStart, DateTime(quarter.year, quarter.month - 6));
        _receiptsBasis(money, filed);
        _receiptsBasis(money, prepared);
        expect(filed.submittedAt!.isAfter(now), isFalse);
        expect(prepared.createdAt.isAfter(now), isFalse);
      });

      test('the filed return keeps its snapshot: its declared amounts are its '
          'lines, and preparing and filing the next quarter change neither', () async {
        final money = DemoFixture.build(now: now).money;
        final filed = money.vatDeclarations.singleWhere((d) => d.isFiled);
        final prepared = money.vatDeclarations.singleWhere((d) => d.isPrepared);
        final declared = [
          for (final a in money.vatDeclared)
            if (!a.on.isBefore(filed.periodStart) && !a.on.isAfter(filed.periodEnd))
              a,
        ];
        expect(declared, hasLength(money.vatDeclared.length),
            reason: 'only the filed quarter is declared');
        for (final l in filed.lines) {
          final rate = declared.where((a) => a.percent == l.percent);
          expect(rate.fold(0, (int n, a) => n + a.grossCents), l.grossCents,
              reason: '${l.percent} % gross');
          expect(rate.fold(0, (int n, a) => n + a.netCents), l.netCents,
              reason: '${l.percent} % net');
        }
        expect({for (final a in declared) a.invoiceId}, hasLength(filed.invoiceCount));
        final filedBefore = _lines(filed);

        await money.saveVatDeclaration(
          workspaceId: 'ws-1',
          periodStart: prepared.periodStart,
          periodEnd: prepared.periodEnd,
        );
        final again = money.vatDeclarations.singleWhere((d) => d.id == prepared.id);
        expect(_lines(again), _lines(prepared));
        expect(again.invoiceCount, prepared.invoiceCount);
        expect(again.createdAt, prepared.createdAt);
        await money.markVatDeclarationSubmitted(
          declarationId: prepared.id,
          channel: 'manual',
          receipt: 'receipt',
        );
        final submitted = money.vatDeclarations.singleWhere((d) => d.id == prepared.id);
        expect(submitted.submittedAt, now);
        expect(submitted.number, startsWith('DECL-${now.year}-'));
        expect(_lines(money.vatDeclarations.singleWhere((d) => d.id == filed.id)),
            filedBefore);
      });

      test('a receipt recorded later, dated inside the filed quarter, corrects '
          'that quarter in the next return and leaves the filed one as it was', () async {
        final money = DemoFixture.build(now: now).money;
        final filed = money.vatDeclarations.singleWhere((d) => d.isFiled);
        final prepared = money.vatDeclarations.singleWhere((d) => d.isPrepared);
        final filedBefore = _lines(filed);
        final declaredBefore = [...money.vatDeclared];
        // A sale of the filed quarter, 120.00 at 20 % (100.00 + 20.00),
        // paid in full mid-quarter but recorded only now.
        final day = filed.periodStart.add(const Duration(days: 40));
        final template = money.invoices.firstWhere((i) => i.vatTotals.isNotEmpty);
        money.invoices.add(
          template.copyWith(
            id: 'late-sale',
            number: 'F-LATE-0001',
            issuedAt: day,
            period: null,
            lines: const [
              InvoiceLine(label: 'Day pass', amountCents: 12000, vatPercent: 20),
            ],
            totalCents: 12000,
            vatTotals: const [
              InvoiceVatTotal(
                percent: 20,
                category: 'S',
                grossCents: 12000,
                netCents: 10000,
                vatCents: 2000,
              ),
            ],
            replacesInvoiceId: null,
            settles: const [],
            dueOn: day,
          ),
        );
        money.invoiceMatchesStore['late-sale'] = InvoiceMatch(
          invoiceId: 'late-sale',
          paidCents: 12000,
          resolution: 'exact',
          matchedAt: day,
        );

        await money.saveVatDeclaration(
          workspaceId: 'ws-1',
          periodStart: prepared.periodStart,
          periodEnd: prepared.periodEnd,
        );
        final next = money.vatDeclarations.singleWhere((d) => d.id == prepared.id);
        final corrections = next.lines.where((l) => l.corrects.isNotEmpty).toList();
        expect(corrections, hasLength(1));
        final c = corrections.single;
        expect((c.percent, c.grossCents, c.netCents, c.vatCents),
            (20.0, 12000, 10000, 2000));
        expect(c.correctsStart, filed.periodStart);
        expect(c.correctsEnd, filed.periodEnd);
        expect(
          _lines(next).where((l) => l.$5.isEmpty).toList(),
          _lines(prepared),
          reason: 'the open quarter itself is unchanged',
        );
        expect(_lines(money.vatDeclarations.singleWhere((d) => d.id == filed.id)),
            filedBefore);
        expect(money.vatDeclared, declaredBefore);
      });
    });
  }
}
