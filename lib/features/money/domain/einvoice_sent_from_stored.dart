// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4120 -- what a sending is built from, and the document that left.
import 'dart:convert' show base64Decode;
import 'dart:typed_data';

/// What of an invoice's sending is its own and what would be today's
/// (`invoice_send_basis`, 0795).
class EInvoiceSendBasis {
  const EInvoiceSendBasis({
    this.iban,
    this.paymentToday = false,
    this.referenceToday = false,
  });

  /// Reads the server's answer.
  factory EInvoiceSendBasis.fromAnswer(Object? answer) {
    final map = answer is Map ? answer : const <String, Object?>{};
    final payment = map['payment'];
    return EInvoiceSendBasis(
      iban: payment is Map ? (payment['iban'] as String? ?? '') : null,
      paymentToday: map['payment_today'] == true,
      referenceToday: map['reference_today'] == true,
    );
  }

  /// Nothing of the sending differs from today: build it with today's
  /// values and name none (a source that froze nothing, such as the Demo).
  static const sameAsToday = EInvoiceSendBasis();

  /// The account the invoice stored ('' when it stored one without an
  /// IBAN); null: it stored none, so today's is used.
  final String? iban;

  /// The account is today's, not the invoice's own: say so before Send.
  final bool paymentToday;

  /// The tax reference is today's: say so before Send.
  final bool referenceToday;

  bool get anyToday => paymentToday || referenceToday;

  /// The account a sending carries. A stored payment block is the invoice's
  /// own, even an empty one: an invoice issued without an account is sent
  /// without one, whatever account the business has since. [today] is used
  /// only when the invoice stored no block at all, the case named before Send.
  String accountOr(String today) => iban ?? today;
}

/// The document an invoice's sending left with, as stored
/// (`invoice_sent_document`, 0795).
class SentEInvoiceDocument {
  const SentEInvoiceDocument({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.sha256,
  });

  factory SentEInvoiceDocument.fromAnswer(Object? answer) {
    final map = answer is Map ? answer : const <String, Object?>{};
    return SentEInvoiceDocument(
      fileName: map['file_name'] as String? ?? '',
      mimeType: map['mime_type'] as String? ?? '',
      bytes: base64Decode((map['bytes'] as String? ?? '').replaceAll('\n', '')),
      sha256: map['sha256'] as String? ?? '',
    );
  }

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String sha256;
}
