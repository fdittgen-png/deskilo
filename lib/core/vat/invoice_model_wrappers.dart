// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- the invoice model's old-path wrappers, in ONE file: the only code
// in the invoice model's neighbourhood that reads the installed snapshot
// (ActiveTaxReference) or the workspace clock (WorkspaceTime). The package
// (deskilo_invoice_model) takes the reference and the day-of function as
// required parameters; these keep the old signatures and pass the globals.
// The old paths (invoice.dart, vat_compliance.dart, ...) re-export this file.
//
// It also holds the interchange family's two (#3376): `SageAccounts` (the
// package class reads the reference it is given; this subclass falls back to
// the installed snapshot, as the class always did) and `buildSafTFile` (fills
// the installed snapshot into a request that carries none).
//
// #3403 sweep: callers switch to WorkspaceContext, then THIS FILE goes -- not
// a plain shim delete.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    as interchange
    show SafTRequest, SageAccounts, buildSafTFile;
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    hide buildInvoiceCii,
    buildInvoiceKsefFa3,
    buildInvoiceUbl,
    checkEInvoiceReadiness,
    defaultExemptionMention,
    eInvoiceTotalsOf,
    euCountryCode,
    exemptionMentionFor,
    exigibilityMention,
    exportMention,
    frozenTaxPointBasis,
    isEuCountry,
    legalProfileOf,
    looksLikeEuVatId,
    nationalInvoiceMentions,
    qualifyClauses,
    reverseChargeMention,
    supplyVatCategory,
    taxPointsOf,
    vatTaxPointBasis,
    vatTaxPointLedger,
    vatTaxPointPolicy,
    vatTotalsOf;
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' as model
    show LegalClauseSnapshot, buildInvoiceCii, buildInvoiceKsefFa3, buildInvoiceUbl, checkEInvoiceReadiness, defaultExemptionMention, eInvoiceTotalsOf, euCountryCode, euMemberStatesOf, exemptionMentionFor, exigibilityMention, exigibilityOf, exportMention, frozenTaxPointBasis, isEuCountry, legalProfileOf, looksLikeEuVatId, nationalInvoiceMentions, qualifyClauses, reverseChargeMention, supplyVatCategory, taxPointBasisOf, taxPointsOf, vatBreakdownOf, vatTaxPointBasis, vatTaxPointLedger, vatTaxPointPolicy, vatTotalsOf;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import 'package:meta/meta.dart';

import '../time/workspace_time.dart';
import 'tax_reference_active.dart';

/// #2354 -- the member states, ONE set for the whole app (the rows of the
/// `eu_member` domain of the installed tax reference).
Set<String> get euMemberStates =>
    model.euMemberStatesOf(ActiveTaxReference.current);

String euCountryCode(String code, {TaxReferenceSet? reference}) =>
    model.euCountryCode(code, reference: reference ?? ActiveTaxReference.current);

bool isEuCountry(String code, {TaxReferenceSet? reference}) =>
    model.isEuCountry(code, reference: reference ?? ActiveTaxReference.current);

String supplyVatCategory({
  required VatTreatment treatment,
  required SupplyClass supply,
  required bool sellerVatRegistered,
  required String sellerCountry,
  required String buyerCountry,
  required String buyerCapacity,
  bool reverseChargeOn = true,
}) => model.supplyVatCategory(
  treatment: treatment,
  supply: supply,
  sellerVatRegistered: sellerVatRegistered,
  sellerCountry: sellerCountry,
  buyerCountry: buyerCountry,
  buyerCapacity: buyerCapacity,
  reverseChargeOn: reverseChargeOn,
  reference: ActiveTaxReference.current,
);

String defaultExemptionMention(
  String countryCode,
  VatRegime regime, {
  String vatId = '',
  String? asOf,
  TaxReferenceSet? reference,
}) => model.defaultExemptionMention(
  countryCode,
  regime,
  vatId: vatId,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

bool looksLikeEuVatId(
  String vatId, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.looksLikeEuVatId(
  vatId,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

String reverseChargeMention(
  String sellerCountry, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.reverseChargeMention(
  sellerCountry,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

String exportMention(
  String sellerCountry, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.exportMention(
  sellerCountry,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

String exemptionMentionFor({
  required String category,
  required String sellerCountry,
  required String sellerReason,
  required String buyerReason,
  required VatRegime regime,
  String? asOf,
}) => model.exemptionMentionFor(
  category: category,
  sellerCountry: sellerCountry,
  sellerReason: sellerReason,
  buyerReason: buyerReason,
  regime: regime,
  asOf: asOf,
  reference: ActiveTaxReference.current,
);

String exigibilityMention({
  required VatRegime regime,
  required String sellerCountry,
  required bool onPaymentBasis,
  String? asOf,
  TaxReferenceSet? reference,
}) => model.exigibilityMention(
  regime: regime,
  sellerCountry: sellerCountry,
  onPaymentBasis: onPaymentBasis,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

List<String> nationalInvoiceMentions({
  required String sellerCountry,
  required VatRegime regime,
  required String currency,
  required int untaxedCents,
  required bool correction,
  String rectifies = '',
  String correctionReason = '',
  String sellerVatId = '',
  String sellerLegalId = '',
  bool qstCharged = false,
}) => model.nationalInvoiceMentions(
  sellerCountry: sellerCountry,
  regime: regime,
  currency: currency,
  untaxedCents: untaxedCents,
  correction: correction,
  rectifies: rectifies,
  correctionReason: correctionReason,
  sellerVatId: sellerVatId,
  sellerLegalId: sellerLegalId,
  qstCharged: qstCharged,
  reference: ActiveTaxReference.current,
);

@visibleForTesting
LegalProfile legalProfileOf(LegalClauseSnapshot snapshot) =>
    model.legalProfileOf(snapshot, reference: ActiveTaxReference.current);

QualifiedClauses qualifyClauses(
  LegalClauseSnapshot snapshot,
  ReportStrings strings,
) => model.qualifyClauses(
  snapshot,
  strings,
  reference: ActiveTaxReference.current,
);

/// The same facts read from the LIVE settings (statements, letters,
/// previews): `LegalClauseSnapshot.live` with the installed reference.
LegalClauseSnapshot legalClauseSnapshotLive({
  required InvoiceLegal legal,
  required String sellerCountry,
  String buyerCountry = '',
  PaymentTerms? memberTerms,
  String? memberCapacity,
}) => model.LegalClauseSnapshot.live(
  legal: legal,
  sellerCountry: sellerCountry,
  buyerCountry: buyerCountry,
  memberTerms: memberTerms,
  memberCapacity: memberCapacity,
  reference: ActiveTaxReference.current,
);

VatTaxPointPolicy vatTaxPointPolicy(
  String country, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.vatTaxPointPolicy(
  country,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

/// The basis of a seller in [country] whose stored choice is [option].
VatTaxPointBasis vatTaxPointBasis(String country, VatTaxPointOption? option) =>
    model.vatTaxPointBasis(
      country,
      option,
      reference: ActiveTaxReference.current,
    );

@visibleForTesting
List<VatTaxPointAmount> taxPointsOf(
  Invoice invoice,
  List<TaxPointPayment> payments, {
  required VatTaxPointBasis basis,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => model.taxPointsOf(
  invoice,
  payments,
  basis: basis,
  reference: ActiveTaxReference.current,
  dayOf: dayOf,
);

@visibleForTesting
VatTaxPointBasis frozenTaxPointBasis(Invoice invoice, VatTaxPointBasis basis) =>
    model.frozenTaxPointBasis(
      invoice,
      basis,
      reference: ActiveTaxReference.current,
    );

List<VatTaxPointAmount> vatTaxPointLedger(
  Iterable<Invoice> invoices, {
  Map<String, InvoiceMatch> matches = const {},
  Map<String, List<TaxPointPayment>> instalments = const {},
  VatTaxPointBasis basis = VatTaxPointBasis.invoiceDate,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => model.vatTaxPointLedger(
  invoices,
  matches: matches,
  instalments: instalments,
  basis: basis,
  reference: ActiveTaxReference.current,
  dayOf: dayOf,
);

List<InvoiceVatTotal> vatTotalsOf(
  Iterable<({int amountCents, double vatPercent})> lines, {
  required String zeroCategory,
  String sellerCountry = '',
}) => model.vatTotalsOf(
  lines,
  zeroCategory: zeroCategory,
  sellerCountry: sellerCountry,
  reference: ActiveTaxReference.current,
);

/// The reference-reading forms of the tax-point questions on [InvoiceLegal].
extension InvoiceLegalTaxPoint on InvoiceLegal {
  /// The basis a seller in [country] declares on.
  VatTaxPointBasis taxPointBasis(String country) => model.taxPointBasisOf(
    this,
    country,
    reference: ActiveTaxReference.current,
  );

  /// The #896 two-value key for [country]: `payment` when the tax waits
  /// for the money, `invoice` otherwise -- what the printed mention reads.
  String exigibilityIn(String country) => model.exigibilityOf(
    this,
    country,
    reference: ActiveTaxReference.current,
  );
}

/// The breakdown the documents render, one entry per rate (the snapshot wins
/// whenever there is one): `vatBreakdownOf` with the installed reference.
extension InvoiceVatBreakdown on Invoice {
  List<InvoiceVatTotal> vatBreakdown({required String zeroCategory}) =>
      model.vatBreakdownOf(
        this,
        zeroCategory: zeroCategory,
        reference: ActiveTaxReference.current,
      );
}

class SageAccounts extends interchange.SageAccounts {
  const SageAccounts({
    super.debtors,
    super.sales,
    super.bank,
    super.taxCode,
    super.reference,
  });

  @override
  TaxReferenceSet get installedReference => ActiveTaxReference.current;
}

String buildSafTFile(interchange.SafTRequest request) =>
    interchange.buildSafTFile(
      request.withReference(request.reference ?? ActiveTaxReference.current),
    );

/// #3402 -- the document builders: the input carries the reference; when it
/// carries none, the installed snapshot is filled in.
String buildInvoiceUbl(
  EInvoiceInput input, {
  UblProfile profile = UblProfile.en16931,
}) => model.buildInvoiceUbl(
  input.withReference(input.reference ?? ActiveTaxReference.current),
  profile: profile,
);

String buildInvoiceCii(EInvoiceInput input) => model.buildInvoiceCii(
  input.withReference(input.reference ?? ActiveTaxReference.current),
);

String buildInvoiceKsefFa3(
  EInvoiceInput input, {
  DateTime? generatedAt,
  String systemInfo = 'DesKilo',
  DateTime? correctedIssuedAt,
}) => model.buildInvoiceKsefFa3(
  input.withReference(input.reference ?? ActiveTaxReference.current),
  generatedAt: generatedAt,
  systemInfo: systemInfo,
  correctedIssuedAt: correctedIssuedAt,
);

EInvoiceTotals eInvoiceTotalsOf({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
}) => model.eInvoiceTotalsOf(
  invoice: invoice,
  seller: seller,
  buyer: buyer,
  reference: ActiveTaxReference.current,
);

EInvoiceReadiness checkEInvoiceReadiness({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
  String destination = '',
  String iban = '',
}) => model.checkEInvoiceReadiness(
  invoice: invoice,
  seller: seller,
  buyer: buyer,
  destination: destination,
  iban: iban,
  reference: ActiveTaxReference.current,
);
