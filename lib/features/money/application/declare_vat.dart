// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — what a VAT period declares, and what the platform said back.
//
// **The basis.** On the accrual basis a period holds what was ISSUED in
// it, on the cash basis what was PAID in it — and the difference is not
// only the line totals but WHICH DOCUMENTS stand behind them, because
// the count printed on the form must be counted on the same date as the
// money. A voided invoice is behind nothing; a document counts once.
//
// **The answer.** Filed is something the platform GRANTS, so a refusal
// carries the reason it gave. Both derivations sat in a closure on the
// declarations screen, where arguing with them meant pumping a widget.
import '../domain/invoice.dart';
import '../domain/money_repository.dart';
import '../domain/vat_declaration.dart';

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

/// The draft for [periodStart]..[periodEnd], on the declared basis.
VatDeclarationDraft vatDeclarationDraft({
  required Iterable<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required DateTime periodStart,
  required DateTime periodEnd,
  required bool onPaymentBasis,
}) {
  final lines = onPaymentBasis
      ? computeVatDeclarationLinesOnPayment(
          invoices: invoices,
          matches: matches,
          periodStart: periodStart,
          periodEnd: periodEnd,
        )
      : computeVatDeclarationLines(invoices, periodStart, periodEnd);
  var net = 0;
  var vat = 0;
  for (final line in lines) {
    net += line.netCents;
    vat += line.vatCents;
  }
  final last = periodEnd.add(const Duration(days: 1));
  final ids = <String>{};
  for (final invoice in invoices) {
    if (invoice.voidedAt != null) continue;
    final on =
        onPaymentBasis ? matches[invoice.id]?.matchedAt : invoice.issuedAt;
    if (on != null && !on.isBefore(periodStart) && on.isBefore(last)) {
      ids.add(invoice.id);
    }
  }
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
    required bool onPaymentBasis,
  }) async {
    final draft = vatDeclarationDraft(
      invoices: invoices,
      matches: matches,
      periodStart: periodStart,
      periodEnd: periodEnd,
      onPaymentBasis: onPaymentBasis,
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
