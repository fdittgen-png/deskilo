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
// **The answer.** Filed is something the platform GRANTS, so a refusal
// carries the reason it gave. Both derivations sat in a closure on the
// declarations screen, where arguing with them meant pumping a widget.
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

/// What the e-invoicing platform did with a declaration.
sealed class VatTransmission {
  const VatTransmission();
}

/// The platform took it: submitted, with its receipt.
class VatDeclarationFiled extends VatTransmission {
  const VatDeclarationFiled();
}

/// It came back, and [detail] is the platform's own words — "it did not
/// work" is not a reason anybody can act on.
class VatDeclarationRefused extends VatTransmission {
  const VatDeclarationRefused(this.detail);
  final String detail;
}

/// Declaring VAT, as the decisions behind it.
class VatDeclarations {
  const VatDeclarations(this._money);

  final MoneyRepository _money;

  /// Recomputes the period's draft and saves it.
  Future<void> declare({
    required String workspaceId,
    required String currency,
    required DateTime periodStart,
    required DateTime periodEnd,
    required Iterable<Invoice> invoices,
    required Map<String, InvoiceMatch> matches,
    required VatTaxPointBasis basis,
  }) async {
    final draft = vatDeclarationDraft(
      invoices: invoices,
      matches: matches,
      // #2355 — every payment recorded one by one: on receipts an
      // instalment-paid invoice declares each part in its own period.
      instalments: await _money.fetchInvoiceInstalments(workspaceId),
      periodStart: periodStart,
      periodEnd: periodEnd,
      basis: basis,
    );
    await _money.saveVatDeclaration(
      workspaceId: workspaceId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      lines: draft.lines,
      totalNetCents: draft.totalNetCents,
      totalVatCents: draft.totalVatCents,
      currency: currency,
      invoiceCount: draft.invoiceCount,
    );
  }

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

  /// Sends the declaration document and reports what came back.
  Future<VatTransmission> transmit({
    required String workspaceId,
    required String declarationId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final submission = await _money.sendVatDeclaration(
      workspaceId: workspaceId,
      declarationId: declarationId,
      fileName: fileName,
      // The declaration travels as the document the authority reads.
      mimeType: 'application/pdf',
      bytes: bytes,
    );
    return submission.accepted
        ? const VatDeclarationFiled()
        : VatDeclarationRefused(submission.detail);
  }

  /// Somebody filed it themselves, at the portal or through their
  /// accountant. The CHANNEL is the decision, and it is `manual`
  /// precisely because no platform answered: a caller free to name it
  /// could stamp a declaration `platform` that no platform ever saw.
  Future<void> fileByHand(String declarationId) =>
      _money.markVatDeclarationSubmitted(
        declarationId: declarationId,
        channel: 'manual',
      );
}
