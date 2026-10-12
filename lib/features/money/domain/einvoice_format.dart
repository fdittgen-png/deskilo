// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';

/// #2358 — the profile a UBL 2.1 document claims (BT-24, and BT-23 where
/// the profile wants one). The same EN 16931 content travels under each;
/// what changes is the identifier a validator selects its rules by and
/// the few elements the profile makes mandatory (electronic addresses,
/// the seller contact, the county).
enum UblProfile {
  /// The bare norm: what the download and the e-mail leg have always sent.
  en16931(customizationId: 'urn:cen.eu:en16931:2017'),

  /// Peppol BIS Billing 3.0 — what an access point accepts (BE B2B, the
  /// public buyers of most member states).
  peppolBis(
    customizationId:
        'urn:cen.eu:en16931:2017#compliant#'
        'urn:fdc:peppol.eu:2017:poacc:billing:3.0',
    profileId: 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0',
  ),

  /// XRechnung 3.0, the German CIUS: a Leitweg-ID in BT-10, the seller's
  /// contact and payment instructions are mandatory.
  xrechnung(
    customizationId:
        'urn:cen.eu:en16931:2017#compliant#'
        'urn:xeinkauf.de:kosit:xrechnung_3.0',
    profileId: 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0',
  ),

  /// CIUS-RO 1.0.1, what RO e-Factura accepts: the county of both
  /// addresses is mandatory.
  ciusRo(
    customizationId:
        'urn:cen.eu:en16931:2017#compliant#'
        'urn:efactura.mfinante.ro:CIUS-RO:1.0.1',
  );

  const UblProfile({required this.customizationId, this.profileId = ''});

  final String customizationId;

  /// BT-23, '' when the profile does not ask for one.
  final String profileId;

  /// Whether BT-34 and BT-49 (the electronic addresses) are mandatory.
  bool get needsEndpoints => this == peppolBis || this == xrechnung;
}

/// #2358 — one syntax a document can leave in. The channel decides it,
/// not the user: a Peppol access point takes Peppol BIS, the SdI only
/// FatturaPA, KSeF only FA(3), RO e-Factura only CIUS-RO; a French
/// accredited platform takes the EN 16931 CII under the French CIUS.
/// Factur-X (the PDF with its XML inside) stays the document a PERSON
/// receives: the e-mail leg and the generic upload.
enum EInvoiceFormat {
  facturX('pdf', 'application/pdf'),
  en16931Ubl('xml', 'application/xml'),
  en16931Cii('xml', 'application/xml'),
  peppolBis('xml', 'application/xml'),
  xrechnung('xml', 'application/xml'),
  ciusRo('xml', 'application/xml'),
  fatturaPa('xml', 'application/xml'),
  ksefFa3('xml', 'application/xml');

  const EInvoiceFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  /// The UBL profile this format is, or null when it is not UBL.
  UblProfile? get ublProfile => switch (this) {
    EInvoiceFormat.en16931Ubl => UblProfile.en16931,
    EInvoiceFormat.peppolBis => UblProfile.peppolBis,
    EInvoiceFormat.xrechnung => UblProfile.xrechnung,
    EInvoiceFormat.ciusRo => UblProfile.ciusRo,
    _ => null,
  };
}

/// The EAS code of the German Leitweg-ID: a buyer addressed by one is a
/// public body, and a public body in Germany receives XRechnung.
@visibleForTesting
const leitwegIdScheme = '0204';

/// What leaves for [provider] on [destination]. The customer's own
/// delivery service gets the hybrid PDF a person can open; so does the
/// generic upload, which predates the named channels and whose platforms
/// were configured for it.
EInvoiceFormat eInvoiceFormatFor({
  required String provider,
  required String destination,
  String buyerEndpointScheme = '',
}) {
  if (destination == 'customer') return EInvoiceFormat.facturX;
  return switch (provider) {
    'peppol' =>
      buyerEndpointScheme == leitwegIdScheme
          ? EInvoiceFormat.xrechnung
          : EInvoiceFormat.peppolBis,
    'fr_pa' => EInvoiceFormat.en16931Cii,
    'it_sdi' => EInvoiceFormat.fatturaPa,
    'pl_ksef' => EInvoiceFormat.ksefFa3,
    'ro_efactura' => EInvoiceFormat.ciusRo,
    _ => EInvoiceFormat.facturX,
  };
}
