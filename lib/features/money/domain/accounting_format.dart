// SPDX-License-Identifier: 0BSD

/// The accounting exports the app offers, and — the part that matters —
/// **what each one claims about itself** (#669).
///
/// These files are legally consequential. A wrong one is worse than
/// none: it is a false statement to a tax authority, and it gets unbound
/// by hand. So every format here carries its [claim] explicitly, and the
/// export sheet shows it. Three kinds, and the difference is not
/// cosmetic:
///
///  * [FormatClaim.regulatory] — this file is what a named authority
///    asks for, produced to their published spec and to the SCOPE that
///    spec defines for a system like this one. The FEC is one. So is a
///    SAF-T(PT) declared as invoicing-only, because Portugal defines
///    that variant precisely for systems that keep no ledger.
///  * [FormatClaim.exchange] — an accountant's software reads it and a
///    PERSON reviews and posts what it contains. DATEV and Sage are
///    these. No authority is being told anything, which is exactly why
///    they can be produced honestly without a chart of accounts.
///  * [FormatClaim.subset] — the shape is real but the file is
///    deliberately partial, and it says so in its own header. The
///    generic SAF-T is this: the OECD tree with `GeneralLedgerEntries`
///    omitted on purpose.
///
/// WHAT IS DELIBERATELY ABSENT, and why the epic stays open. The
/// ACCOUNTING variants of SAF-T — Portugal's `TaxAccountingBasis` 'C'
/// and 'I', Norway's, Luxembourg's FAIA, Poland's JPK_KR, Romania's
/// D406 — mandate `GeneralLedgerEntries` over a full chart of accounts.
/// DesKilo holds invoices and payments, not a ledger. That is a
/// data-model gap, not a formatting one, and no amount of exporting
/// closes it. Sage's German lines (KHK / Office Line) and the
/// per-country Sage products each need their own vendor import spec,
/// which is not public.
library;

/// What a produced file claims about itself. Never widen one of these
/// without the authority's own spec in hand.
enum FormatClaim { regulatory, exchange, subset }

/// One offerable export.
class AccountingFormat {
  const AccountingFormat({
    required this.id,
    required this.claim,
    required this.countries,
    required this.extension,
    this.needsAccounts = false,
    this.needsLegalId = false,
    this.uncertifiedSoftware = false,
  });

  /// Stable wire id — also the l10n key suffix and the test anchor.
  final String id;

  final FormatClaim claim;

  /// Uppercase ISO country codes this format is offered in. Empty means
  /// everywhere: a format with no national tie is useful to any
  /// accountant, and hiding it behind a country list would only make it
  /// unreachable for the ten countries that mandate nothing.
  final Set<String> countries;

  final String extension;

  /// The format posts to a chart of accounts DesKilo does not own, so
  /// the export must ASK for the numbers and show them before writing.
  /// Never invent them: every wrong code is unbooked by hand.
  final bool needsAccounts;

  /// The file is named after, or must carry, the company's registration
  /// number — refusing early beats producing a file the authority will
  /// reject on its name alone.
  final bool needsLegalId;

  /// The jurisdiction operates a software CERTIFICATION scheme and
  /// DesKilo is not certified under it.
  ///
  /// Portugal is the case that forced this field. Its spec is public and
  /// the file this app produces is true to it — but Portuguese
  /// taxpayers above the statutory threshold must use *certified*
  /// invoicing software, and a structurally perfect file from
  /// uncertified software does not satisfy that obligation. The file
  /// declares `SoftwareCertificateNumber` 0, which is the defined value
  /// for "not certified", and the export sheet says so out loud.
  ///
  /// Producing the file quietly and letting the owner assume it settles
  /// their obligation would be exactly the overclaim this whole registry
  /// exists to prevent.
  final bool uncertifiedSoftware;

  bool offeredIn(String countryCode) =>
      countries.isEmpty || countries.contains(countryCode.toUpperCase());
}

/// SAF-T, invoicing subset — the OECD tree, ledger omitted on purpose.
const safTFormat = AccountingFormat(
  id: 'saft',
  claim: FormatClaim.subset,
  countries: {},
  extension: 'xml',
);

/// Portugal's SAF-T declared as `TaxAccountingBasis = 'F'` (faturação).
///
/// This one IS regulatory, and the reason is worth stating because it
/// looks like it should not be: Portugal defines the invoicing-only
/// variant *for systems that do not keep books*. Declaring 'F' is not a
/// partial 'C' — it is a different, complete declaration, and omitting
/// `GeneralLedgerEntries` is what 'F' requires rather than something it
/// tolerates.
const safTPtFormat = AccountingFormat(
  id: 'saft_pt',
  claim: FormatClaim.regulatory,
  countries: {'PT'},
  extension: 'xml',
  needsLegalId: true,
  // See the field's own comment: the SPEC is met, the CERTIFICATION
  // obligation is a separate one and this app does not meet it.
  uncertifiedSoftware: true,
);

/// France's flat file, the one an audit demands.
const fecFormat = AccountingFormat(
  id: 'fec',
  claim: FormatClaim.regulatory,
  countries: {'FR'},
  extension: 'txt',
  needsAccounts: true,
  needsLegalId: true,
);

/// DATEV EXTF Buchungsstapel — what a German or Austrian Steuerberater
/// imports. Switzerland is NOT here: DATEV is a German-market product
/// and a Swiss fiduciary does not run it.
const datevFormat = AccountingFormat(
  id: 'datev',
  claim: FormatClaim.exchange,
  countries: {'DE', 'AT'},
  extension: 'csv',
  needsAccounts: true,
);

/// Sage 50's audit-trail CSV — the British and Irish import shape.
const sageFormat = AccountingFormat(
  id: 'sage50',
  claim: FormatClaim.exchange,
  countries: {'GB', 'IE'},
  extension: 'csv',
  needsAccounts: true,
);

/// A plain, self-describing CSV for every accountant with no national
/// mandate behind them — ten of the fourteen supported countries.
///
/// Offered EVERYWHERE rather than only where nothing is mandated: an
/// accountant in France may still prefer a readable file to an FEC, and
/// the format claims nothing that could mislead them.
const accountantCsvFormat = AccountingFormat(
  id: 'accountant_csv',
  claim: FormatClaim.exchange,
  countries: {},
  extension: 'csv',
);

/// The complete audit TRAIL — every invoice, payment, credit note and
/// write-off with who did what and when.
///
/// Named a trail, never an "audit file", and the distinction is the
/// whole point: a national audit file is a regulated artefact with a
/// schema and a validator, and this is not one. It is the evidence
/// behind the numbers, which is what an accountant or an inspector
/// actually asks for first.
const auditTrailFormat = AccountingFormat(
  id: 'audit_trail',
  claim: FormatClaim.exchange,
  countries: {},
  extension: 'csv',
);

/// Every format, in the order the sheet lists them: the country's own
/// regulatory file first when there is one, then exchange formats, then
/// the generic fallbacks. Someone under audit is looking for one
/// specific file and should not have to read past three alternatives to
/// find it.
const List<AccountingFormat> accountingFormats = [
  fecFormat,
  safTPtFormat,
  datevFormat,
  sageFormat,
  safTFormat,
  accountantCsvFormat,
  auditTrailFormat,
];

/// What to offer in [countryCode], most specific first.
List<AccountingFormat> formatsFor(String countryCode) => [
      for (final format in accountingFormats)
        if (format.offeredIn(countryCode)) format,
    ];
