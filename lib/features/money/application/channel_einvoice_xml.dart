// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert' show utf8;

import '../../../core/jurisdiction/jurisdiction_resolver.dart';
import '../domain/einvoice_format.dart';
import '../domain/einvoice_input.dart';
import '../domain/invoice_cii.dart';
import '../domain/invoice_ksef_fa3.dart';
import '../domain/invoice_ubl.dart';
import 'jurisdiction/installed_invoice_profiles.dart';
import 'jurisdiction/invoice_document_context_builder.dart';

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
  EInvoiceFormat.fatturaPa => _viaProfile(format, input),
  EInvoiceFormat.ksefFa3 => buildInvoiceKsefFa3(input),
  EInvoiceFormat.en16931Ubl ||
  EInvoiceFormat.peppolBis ||
  EInvoiceFormat.xrechnung ||
  EInvoiceFormat.ciusRo => buildInvoiceUbl(
    input,
    profile: format.ublProfile ?? UblProfile.en16931,
  ),
};

/// The document of [format] from the installed invoice profile that renders
/// it: the same bytes the builder in the application wrote before it moved.
/// A format with no profile is a programming error here (the composition is
/// compiled in), never a fallback.
String _viaProfile(EInvoiceFormat format, EInvoiceInput input) {
  final resolution = resolveInvoiceProfile(format.name, installedInvoiceProfiles);
  final profile = switch (resolution) {
    ResolvedProfile(:final profile) => profile,
    RefusedProfile(:final kind) => throw StateError(
      'no invoice profile for ${format.name}: ${kind.name}',
    ),
  };
  final checked = profile.validate(invoiceDocumentContextOf(input));
  final document = checked.document;
  if (document == null) {
    throw StateError(
      'the ${format.name} profile refused the document: '
      '${checked.result.codes.join(', ')}',
    );
  }
  return utf8.decode(profile.build(document).bytes);
}
