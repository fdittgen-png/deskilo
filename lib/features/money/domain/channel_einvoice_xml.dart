// SPDX-License-Identifier: AGPL-3.0-or-later
import 'einvoice_format.dart';
import 'einvoice_input.dart';
import 'invoice_cii.dart';
import 'invoice_fatturapa.dart';
import 'invoice_ksef_fa3.dart';
import 'invoice_ubl.dart';

/// #2358 — the XML a channel receives, in the syntax it wants: a Peppol
/// access point the Peppol BIS UBL, the SdI the FatturaPA, KSeF the
/// FA(3), RO e-Factura the CIUS-RO UBL, a French accredited platform the
/// EN 16931 CII. The caller hands in what the download uses (the line
/// wording, the due date and the terms frozen with the invoice), so the
/// document that leaves and the one the user can save never disagree.
///
/// [EInvoiceFormat.facturX] is a PDF, built by the PDF pipeline; asking
/// for it here is a programming error.
String buildChannelEInvoiceXml(EInvoiceFormat format, EInvoiceInput input) =>
    switch (format) {
  EInvoiceFormat.facturX => throw ArgumentError.value(
    format,
    'format',
    'Factur-X is a PDF',
  ),
  EInvoiceFormat.en16931Cii => buildInvoiceCii(input),
  EInvoiceFormat.fatturaPa => buildInvoiceFatturaPa(input),
  EInvoiceFormat.ksefFa3 => buildInvoiceKsefFa3(input),
  EInvoiceFormat.en16931Ubl ||
  EInvoiceFormat.peppolBis ||
  EInvoiceFormat.xrechnung ||
  EInvoiceFormat.ciusRo => buildInvoiceUbl(
    input,
    profile: format.ublProfile ?? UblProfile.en16931,
  ),
};
