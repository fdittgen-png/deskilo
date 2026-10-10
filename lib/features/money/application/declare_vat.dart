// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — what a VAT period declares, and what the platform said back.
//
// **The basis.** A period holds the tax points that fall inside it
// (#2355, `vat_tax_point.dart`): issued, paid, or performed, as the
// seller's country and option say — and the difference is not only the
// line totals but WHICH DOCUMENTS stand behind them, because the count
// printed on the form must be counted on the same date as the money. A
// voided invoice is behind nothing; a document counts once.
//
// **The server's figures (#2357).** The declaration stores what the
// server computes (`compute_vat_return`, 0402, the SQL twin of this
// engine); [vatDeclarationDraft] stays the Dart side of that pair, which
// the VAT report reads and `vat_return_parity_test.dart` pins.
//
// **Filed** is what the owner records after filing with the authority,
// with the receipt it gave: no upload marks a return filed.
import '../domain/invoice.dart';
import '../domain/money_repository.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_report.dart';
import '../domain/vat_tax_point.dart';

/// The numbers one filing period declares.
class VatDeclarationDraft {
  const VatDeclarationDraft({
    required this.lines,
    required this.totalNetCents,
    required this.totalVatCents,
    required this.invoiceCount,
  });

  final List<VatDeclarationLine> lines;
  final int totalNetCents;
  final int totalVatCents;

  /// How many documents stand behind [lines] — counted on the SAME date
  /// the lines were, so the form's count and its money cannot disagree.
  final int invoiceCount;
}

/// The draft for [periodStart]..[periodEnd], on the declared [basis]
/// (#2355: the country's tax point, or the option the workspace chose).
/// [instalments] are the payments recorded one by one per invoice.
VatDeclarationDraft vatDeclarationDraft({
  required Iterable<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  Map<String, List<TaxPointPayment>> instalments = const {},
  required DateTime periodStart,
  required DateTime periodEnd,
  required VatTaxPointBasis basis,
}) {
  final amounts = vatTaxPointLedger(
    invoices,
    matches: matches,
    instalments: instalments,
    basis: basis,
  );
  final lines = vatDeclarationLinesOf(amounts, periodStart, periodEnd);
  var net = 0;
  var vat = 0;
  for (final line in lines) {
    net += line.netCents;
    vat += line.vatCents;
  }
  final ids = {
    for (final a in amounts)
      if (a.within(periodStart, periodEnd)) a.invoiceId,
  };
  return VatDeclarationDraft(
    lines: lines,
    totalNetCents: net,
    totalVatCents: vat,
    invoiceCount: ids.length,
  );
}

/// Declaring VAT, as the decisions behind it.
class VatDeclarations {
  const VatDeclarations(this._money);

  final MoneyRepository _money;

  /// Prepares the period's return: the server computes its figures.
  Future<void> declare({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) =>
      _money.saveVatDeclaration(
        workspaceId: workspaceId,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

  /// #2355 — the VAT report of [start]..[end] on [basis]: the same tax
  /// points, from the same payments, the declaration sums.
  Future<VatReport> report({
    required String workspaceId,
    required Iterable<Invoice> invoices,
    required Map<String, InvoiceMatch> matches,
    required DateTime start,
    required DateTime end,
    required String zeroCategory,
    required VatTaxPointBasis basis,
  }) async =>
      buildVatReport(
        invoices,
        start: start,
        end: end,
        zeroCategory: zeroCategory,
        matches: matches,
        instalments: workspaceId.isEmpty
            ? const {}
            : await _money.fetchInvoiceInstalments(workspaceId),
        basis: basis,
      );

  /// The owner filed it with the authority (its portal, or through their
  /// accountant) and records the [receipt] reference it gave. The channel
  /// is `manual` because nothing in the app carried it.
  Future<void> fileByHand(String declarationId, {required String receipt}) =>
      _money.markVatDeclarationSubmitted(
        declarationId: declarationId,
        channel: 'manual',
        receipt: receipt,
      );
}
