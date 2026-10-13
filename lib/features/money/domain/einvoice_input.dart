// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice.dart';

/// What every invoice-document builder (UBL, CII, FatturaPA) renders from:
/// the invoice with its SNAPSHOT parties, the localized position wording and
/// the payment details. One object instead of a growing argument list — a
/// new document field is added here and in one section of each syntax.
class EInvoiceInput {
  const EInvoiceInput({
    required this.invoice,
    required this.seller,
    required this.buyer,
    required this.lineText,
    this.iban = '',
    this.dueDate,
    this.paymentTerms = '',
  });

  final Invoice invoice;
  final InvoiceParty seller;
  final InvoiceParty buyer;

  /// The localized position wording, like the PDF.
  final String Function(InvoiceLine line) lineText;

  /// BT-84, the account the payer must transfer to; '' = omit the group.
  final String iban;

  /// BT-9 — when the money is due (BR-CO-25).
  final DateTime? dueDate;

  /// BT-20 — on what terms the money is due.
  final String paymentTerms;
}
