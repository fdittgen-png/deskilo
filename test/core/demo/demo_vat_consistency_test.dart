// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#3292): the French VAT returns the Demo seeds are the ones the
// application's own rules prepare — on receipts (the tax point of French
// services), from the seeded payments — so preparing the open quarter again
// changes no figure, the filed return keeps its declared amounts, and no date
// of a return lies after the Demo's now, across a year boundary.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'seeded French returns agree with a fresh preparation and filing',
    () async {
      for (final now in [DateTime(2026, 5, 13, 10), DateTime(2027, 1, 1, 10)]) {
        final money = DemoFixture.build(now: now).money;
        expect(money.vatReturnBasis.rule, VatTaxPointRule.receipt);
        final filed = money.vatDeclarations.singleWhere((d) => d.isFiled);
        final prepared = money.vatDeclarations.singleWhere((d) => d.isPrepared);
        expect(filed.submittedAt!.isAfter(now), isFalse);
        expect(prepared.createdAt.isAfter(now), isFalse);
        expect(money.vatDeclared, isNotEmpty);
        expect(prepared.lines.where((l) => l.corrects.isNotEmpty), isEmpty);

        await money.saveVatDeclaration(
          workspaceId: 'ws-1',
          periodStart: prepared.periodStart,
          periodEnd: prepared.periodEnd,
        );
        final refreshed = money.vatDeclarations.singleWhere(
          (d) => d.id == prepared.id,
        );
        expect(refreshed.totalNetCents, prepared.totalNetCents);
        expect(refreshed.totalVatCents, prepared.totalVatCents);
        expect(refreshed.invoiceCount, prepared.invoiceCount);
        expect(
          refreshed.lines
              .map(
                (l) => (
                  l.percent,
                  l.grossCents,
                  l.netCents,
                  l.vatCents,
                  l.corrects,
                ),
              )
              .toList(),
          prepared.lines
              .map(
                (l) => (
                  l.percent,
                  l.grossCents,
                  l.netCents,
                  l.vatCents,
                  l.corrects,
                ),
              )
              .toList(),
        );
        await money.markVatDeclarationSubmitted(
          declarationId: prepared.id,
          channel: 'manual',
          receipt: 'receipt',
        );
        final submitted = money.vatDeclarations.singleWhere(
          (d) => d.id == prepared.id,
        );
        expect(submitted.submittedAt, now);
        expect(submitted.number, startsWith('DECL-${now.year}-'));
      }
    },
  );
}
