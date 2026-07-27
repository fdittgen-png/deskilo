// SPDX-License-Identifier: 0BSD
import 'invoice_ubl.dart' show isEuCountry;

/// How a structured invoice TRAVELS — the question an XML export leaves
/// open ("fine, but where do I send this?").
enum EInvoiceTransport {
  /// Peppol: an access point delivers the file to the customer. No
  /// government platform sits in the path.
  peppol,

  /// A national clearance platform receives the invoice FIRST and hands
  /// it on (IT SdI, PL KSeF, RO e-Factura) — sending straight to the
  /// customer is not an option there.
  clearance,

  /// An accredited private platform carries the invoice and reports it
  /// to the tax administration (FR: plateformes agréées).
  accredited,

  /// No transmission channel is imposed: e-mail, a portal or Peppol —
  /// whatever the two parties agree on.
  bilateral,
}

/// Where a country expects invoices to go, per audience.
///
/// Deliberately carries NO dates and NO links: mandate calendars slip
/// every year and government URLs rot, while the channel and the accepted
/// syntax are stable enough to ship inside an app. The wiki keeps the
/// timeline; this only answers "which pipe, which syntax".
class EInvoiceRoute {
  const EInvoiceRoute({
    required this.transport,
    required this.businessChannel,
    required this.businessFormat,
    required this.publicChannel,
    this.ublAccepted = true,
  });

  /// Who moves the file for domestic BUSINESS customers.
  final EInvoiceTransport transport;

  /// The channel's own name — a proper noun, never translated
  /// ('Peppol', 'Chorus Pro', 'SdI', 'KSeF').
  final String businessChannel;

  /// The syntax that channel accepts — also a proper noun
  /// ('Peppol BIS Billing 3.0', 'FatturaPA', 'FA(3)').
  final String businessFormat;

  /// Channel for PUBLIC-SECTOR customers (Directive 2014/55/EU makes
  /// every EU authority able to receive an EN 16931 invoice).
  final String publicChannel;

  /// Whether the EN 16931 UBL 2.1 file this app exports is accepted on
  /// [businessChannel] as-is. False where the domestic mandate runs on a
  /// national syntax (FatturaPA, FA(3), CIUS-RO…) — the file then serves
  /// Peppol, public-sector and foreign customers, and the platform or the
  /// accountant converts it.
  final bool ublAccepted;
}

/// The EU default: no domestic transmission mandate, and Peppol as the
/// channel everyone can reach (it is what public buyers use).
const _euDefault = EInvoiceRoute(
  transport: EInvoiceTransport.bilateral,
  businessChannel: 'Peppol',
  businessFormat: 'Peppol BIS Billing 3.0 (UBL)',
  publicChannel: 'Peppol',
);

/// Country overrides — only where the domestic route genuinely differs
/// from [_euDefault]. Everything else (IE, AT, the Nordics, the Baltics…)
/// reaches its public buyers over Peppol and has no B2B channel mandate.
const Map<String, EInvoiceRoute> _routes = {
  // The reform runs on accredited platforms; the public portal is a
  // directory, not a mailbox — you pick a platform, it routes and reports.
  'FR': EInvoiceRoute(
    transport: EInvoiceTransport.accredited,
    businessChannel: 'Plateforme agréée (PA)',
    businessFormat: 'Factur-X, UBL or CII (EN 16931)',
    publicChannel: 'Chorus Pro',
  ),
  // Receiving has been mandatory since 2025, issuing phases in; no
  // platform is imposed — a mail attachment is a legal e-invoice.
  'DE': EInvoiceRoute(
    transport: EInvoiceTransport.bilateral,
    businessChannel: 'E-mail, Peppol or a portal',
    businessFormat: 'XRechnung or ZUGFeRD (EN 16931)',
    publicChannel: 'OZG-RE / ZRE (or Peppol)',
  ),
  // The one full Peppol B2B mandate in the union.
  'BE': EInvoiceRoute(
    transport: EInvoiceTransport.peppol,
    businessChannel: 'Peppol',
    businessFormat: 'Peppol BIS Billing 3.0 (UBL)',
    publicChannel: 'Mercurius (Peppol)',
  ),
  'IT': EInvoiceRoute(
    transport: EInvoiceTransport.clearance,
    businessChannel: 'SdI',
    businessFormat: 'FatturaPA',
    publicChannel: 'SdI',
    ublAccepted: false,
  ),
  'PL': EInvoiceRoute(
    transport: EInvoiceTransport.clearance,
    businessChannel: 'KSeF',
    businessFormat: 'FA(3)',
    publicChannel: 'PEF (Peppol)',
    ublAccepted: false,
  ),
  // CIUS-RO is UBL-based, but the profile adds its own mandatory data —
  // the plain EN 16931 file does not pass as-is.
  'RO': EInvoiceRoute(
    transport: EInvoiceTransport.clearance,
    businessChannel: 'RO e-Factura (SPV)',
    businessFormat: 'CIUS-RO',
    publicChannel: 'RO e-Factura (SPV)',
    ublAccepted: false,
  ),
  'ES': EInvoiceRoute(
    transport: EInvoiceTransport.bilateral,
    businessChannel: 'Facturae platform or a private one',
    businessFormat: 'Facturae, UBL or CII',
    publicChannel: 'FACe',
  ),
  'NL': EInvoiceRoute(
    transport: EInvoiceTransport.bilateral,
    businessChannel: 'Peppol',
    businessFormat: 'NLCIUS (UBL)',
    publicChannel: 'Digipoort (Peppol)',
  ),
  'PT': EInvoiceRoute(
    transport: EInvoiceTransport.bilateral,
    businessChannel: 'Peppol',
    businessFormat: 'CIUS-PT (UBL)',
    publicChannel: 'eSPap (Peppol)',
  ),
  'LU': EInvoiceRoute(
    transport: EInvoiceTransport.bilateral,
    businessChannel: 'Peppol',
    businessFormat: 'Peppol BIS Billing 3.0 (UBL)',
    publicChannel: 'Peppol',
  ),
};

/// Where [countryCode]'s e-invoices must travel — null outside the EU,
/// where no such obligation applies and the app shows no XML affordance.
EInvoiceRoute? eInvoiceRouteFor(String countryCode) {
  if (!isEuCountry(countryCode)) return null;
  return _routes[countryCode.toUpperCase()] ?? _euDefault;
}
