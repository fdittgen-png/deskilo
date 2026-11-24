// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import 'invoice.dart';
import 'national_invoice_rules.dart';
import 'payment_reference_rules.dart';
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
    required this.reference,
    required this.paymentReferenceRules,
    required this.nationalRules,
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

  /// The tax reference the document is built on: the workspace's own.
  final TaxReferenceSet reference;

  /// #3429 -- the countries whose IBANs a payment slip accepts (QR-IBAN
  /// detection), from the installed payment slip add-ons.
  final PaymentReferenceRules paymentReferenceRules;

  /// #3429 -- the national decisions (exemption code, buyer legal id), from
  /// the installed invoice mentions add-ons.
  final NationalInvoiceRules nationalRules;
}
