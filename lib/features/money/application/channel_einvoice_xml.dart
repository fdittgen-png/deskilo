// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert' show utf8;

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:meta/meta.dart';

import '../../../core/jurisdiction/jurisdiction_resolver.dart';
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
String buildChannelEInvoiceXml(
  EInvoiceFormat format,
  EInvoiceInput input, {

  /// The installed invoice profiles; a test passes a composition without one
  /// (a retired country) to prove the rest keeps working (#3338).
  List<InvoiceProfileContribution>? profiles,

  /// The issue date of the invoice a correction corrects (KSeF states it).
  DateTime? correctedIssuedAt,
}) => switch (format) {
  EInvoiceFormat.facturX => throw ArgumentError.value(
    format,
    'format',
    'Factur-X is a PDF',
  ),
  EInvoiceFormat.en16931Cii => buildInvoiceCii(input),
  EInvoiceFormat.fatturaPa => _viaProfile(
    format,
    input,
    profiles ?? installedInvoiceProfiles,
  ),
  EInvoiceFormat.ksefFa3 => _viaProfile(
    format,
    input,
    profiles ?? installedInvoiceProfiles,
    correctedIssuedAt: correctedIssuedAt,
  ),
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
String _viaProfile(
  EInvoiceFormat format,
  EInvoiceInput input,
  List<InvoiceProfileContribution> installed, {
  DateTime? correctedIssuedAt,
}) {
  final resolution = resolveInvoiceProfile(format.name, installed);
  final profile = switch (resolution) {
    ResolvedProfile(:final profile) => profile,
    RefusedProfile(:final kind) => throw StateError(
      'no invoice profile for ${format.name}: ${kind.name}',
    ),
  };
  final checked = profile.validate(
    invoiceDocumentContextOf(input, correctedIssuedAt: correctedIssuedAt),
  );
  final document = checked.document;
  if (document == null) {
    throw StateError(
      'the ${format.name} profile refused the document: '
      '${checked.result.codes.join(', ')}',
    );
  }
  return utf8.decode(profile.build(document).bytes);
}

/// The issue date of the invoice [invoice] corrects, found among [all] by the
/// technical reference it carries; null when it corrects none or the original
/// is not among them (a profile then states the correction's own date).
@visibleForTesting
DateTime? correctedIssuedAtOf(Invoice invoice, Iterable<Invoice> all) {
  final corrected = invoice.replacesInvoiceId;
  if (corrected == null) return null;
  for (final candidate in all) {
    if (candidate.id == corrected) return candidate.issuedAt;
  }
  return null;
}

/// [correctedIssuedAtOf] for a send: only a KSeF correction states the date
/// of the invoice it corrects, so only then is the [archive] asked. Any other
/// send never waits for it (an archive still loading, or failing, must not
/// hold back an ordinary UBL, CII or FatturaPA file).
Future<DateTime?> correctedIssuedAtForSend(
  EInvoiceFormat format,
  Invoice invoice,
  Future<List<Invoice>> Function() archive,
) async {
  if (format != EInvoiceFormat.ksefFa3 || invoice.replacesInvoiceId == null) {
    return null;
  }
  return correctedIssuedAtOf(invoice, await archive());
}
