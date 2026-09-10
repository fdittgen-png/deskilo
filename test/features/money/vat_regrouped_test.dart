// SPDX-License-Identifier: 0BSD
//
// #1076 — a regrouped invoice must still be declared.
//
// `accountingView` states the rule: a settlement "is NOT a sale: the
// revenue, the VAT and the receivables live on the invoices it
// regroups, which were issued, numbered and declared". The settlement
// leaves the list and its payment is ALLOCATED to those sources.
//
// Two things then lost the money anyway:
//   1. the declaration screen took its invoices from the accounting view
//      (settlement removed) but its matches RAW, so the settlement's
//      match resolved to no invoice and was skipped, while the sources
//      carried no match of their own;
//   2. `buildVatReport` skipped `isFolded` on the assumption that "the
//      settlement carries them" — but its only caller hands it the view,
//      from which the settlement has already been removed.
import 'package:deskilo/features/money/domain/accounting_view.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_report.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _inv(
  String id,
  int total, {
  InvoiceKind kind = InvoiceKind.full,
  List<SettledSource> settles = const [],
  String? settledBy,
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: id.toUpperCase(),
      issuedAt: DateTime.utc(2026, 8, 1),
      period: '2026-08',
      title: '2026-08',
      lines: [
        InvoiceLine(
          kind: 'subscription',
          label: '',
          amountCents: total,
          vatPercent: 20,
        ),
      ],
      totalCents: total,
      currency: 'EUR',
      memberName: 'Flo',
      memberAddress: '',
      workspaceName: 'ws',
      workspaceAddress: '',
      issuerName: 'Flo',
      signature: '',
      kind: kind,
      settles: settles,
      settledByInvoiceId: settledBy,
    );

SettledSource _src(String id, int total) => SettledSource(
      invoiceId: id,
      number: id.toUpperCase(),
      period: '2026-08',
      kind: InvoiceKind.full,
      totalCents: total,
      lines: const [],
    );

void main() {
  // Two €120 invoices at 20%, regrouped into one €240 settlement paid
  // inside the declared period. Expected VAT on either basis: €40.
  final a = _inv('a', 12000, settledBy: 's');
  final b = _inv('b', 12000, settledBy: 's');
  final s = _inv('s', 24000,
      kind: InvoiceKind.settlement,
      settles: [_src('a', 12000), _src('b', 12000)]);
  final rawMatches = {
    's': InvoiceMatch(
      invoiceId: 's',
      paidCents: 24000,
      resolution: 'exact',
      status: 'confirmed',
      matchedAt: DateTime.utc(2026, 9, 15),
      byName: 'Flo',
    ),
  };
  final start = DateTime.utc(2026, 9, 1);
  final end = DateTime.utc(2026, 9, 30);

  test('the cash-basis declaration reports the regrouped sources', () {
    final view = accountingView([a, b, s], rawMatches);
    final lines = computeVatDeclarationLinesOnPayment(
      invoices: view.invoices,
      matches: view.matches,
      periodStart: start,
      periodEnd: end,
    );
    final vat = lines.fold<int>(0, (sum, l) => sum + l.vatCents);
    expect(vat, 4000, reason: 'two €120 invoices at 20% = €40 of VAT');
  });

  test('the accountant VAT report reports them too, on both bases', () {
    final view = accountingView([a, b, s], rawMatches);

    final onPayment = buildVatReport(
      view.invoices,
      start: start,
      end: end,
      zeroCategory: 'Z',
      matches: view.matches,
    );
    expect(onPayment.positions, hasLength(2));
    expect(
      onPayment.positions.fold<int>(0, (sum, p) => sum + p.vatCents),
      4000,
    );

    // Invoice basis: the sources were issued in August.
    final onIssue = buildVatReport(
      view.invoices,
      start: DateTime.utc(2026, 8, 1),
      end: DateTime.utc(2026, 8, 31),
      zeroCategory: 'Z',
    );
    expect(onIssue.positions, hasLength(2));
    expect(
      onIssue.positions.fold<int>(0, (sum, p) => sum + p.vatCents),
      4000,
    );
  });
}
