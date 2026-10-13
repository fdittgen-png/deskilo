// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:pdf/widgets.dart' as pw;

import '../../../l10n/app_localizations.dart';
import '../domain/invoice.dart';
import '../domain/swiss_qr_bill_invoice.dart';
import '../domain/swiss_qr_bill_pdf.dart';

/// #2360 — the QR-bill page of [invoice], in the document's language, or
/// null where none applies (see [swissQrBillOf]).
Future<pw.Page?> swissQrPageFor(
  AppLocalizations l10n,
  Invoice invoice,
  Map<String, Object?> paymentInstructions,
  String workspaceCountry, {
  required bool proforma,
  required Future<pw.Font> Function(String asset) font,
}) async {
  final bill = swissQrBillOf(
    invoice,
    iban: '${paymentInstructions['iban'] ?? ''}',
    qrIban: '${paymentInstructions['qr_iban'] ?? ''}',
    workspaceCountry: workspaceCountry,
    proforma: proforma,
  );
  if (bill == null) return null;
  return swissQrBillPage(
    bill: bill,
    strings: SwissQrBillStrings(
      receipt: l10n.qrBillReceipt,
      paymentPart: l10n.qrBillPaymentPart,
      account: l10n.qrBillAccount,
      reference: l10n.qrBillReference,
      additionalInfo: l10n.qrBillAdditionalInfo,
      payableBy: l10n.qrBillPayableBy,
      payableByAddress: l10n.qrBillPayableByAddress,
      currency: l10n.qrBillCurrency,
      amount: l10n.qrBillAmount,
      acceptancePoint: l10n.qrBillAcceptancePoint,
      separate: l10n.qrBillSeparate,
    ),
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
  );
}
