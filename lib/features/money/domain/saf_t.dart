// SPDX-License-Identifier: AGPL-3.0-or-later

import 'invoice.dart';
import 'saf_t_ledger.dart';
import 'saf_t_writer.dart';

export 'saf_t_ledger.dart' show SafTLedgerAccounts;
export 'saf_t_writer.dart' show SafTProfile;

/// The app version SAF-T records as the producing software
/// (`SoftwareVersion`). Cross-pinned to `pubspec.yaml` by test — an audit
/// file that names the wrong version is a lie about its own provenance.
const String safTSoftwareVersion = '1.0.3';

/// SAF-T — **Standard Audit File for Tax**, the OECD's XML for handing a
/// period of accounting data to an accountant or a tax administration.
/// Every national variant (PT, NO, PL, RO, LT, AT, LU…) is a restriction
/// of this same tree, so an importer that speaks any of them recognises
/// this file's shape.
///
/// What it contains is the INVOICING SUBSET — `Header`, `MasterFiles`
/// (customers + the tax table) and `SourceDocuments` (sales invoices and
/// the payments that settled them). That is deliberate, and it is the same
/// subset Portugal's billing SAF-T defines:
///
///  * `GeneralLedgerEntries` is **omitted**. Double entry needs account
///    numbers, and a chart of accounts belongs to the accountant, not to a
///    coworking app. Inventing '411'/'706' would look complete and create
///    work — every wrong code has to be unbooked by hand.
///  * `Customer/AccountID` is omitted for the same reason.
///
/// Amounts are the invoice's own snapshot: charges as lines, the month's
/// payments as `Payments`, and the solde as the invoice's `GrossTotal`.
/// Line amounts are tax-EXCLUSIVE, as SAF-T defines them — with DesKilo's
/// VAT-inclusive prices that means the extracted net, and the tax sits
/// beside it in `TaxInformation` (0072).
String buildSafTFile({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required InvoiceParty company,
  required String currency,
  required String softwareVersion,
  required DateTime createdAt,
  required String Function(InvoiceLine line) lineText,
  /// The word for a position with no better description.
  String fallbackDescription = 'Coworking',
  SafTProfile profile = SafTProfile.generic,
  /// #669 — when given, the file carries `GeneralLedgerEntries` derived
  /// from the same postings the FEC has produced since 0074: invoice ->
  /// debit customers / credit revenue + VAT, settlement -> debit bank /
  /// credit customers.
  ///
  /// WHAT THIS IS AND IS NOT. The postings are real double entry and
  /// they balance. They are NOT the entity's books: this app sees the
  /// sales cycle and nothing else — no rent, no salaries, no bank
  /// charges, no equipment. A national SAF-T that mandates
  /// `GeneralLedgerEntries` is asking for the complete books, and this
  /// section does not answer that. It answers the smaller, useful
  /// question an accountant's software actually asks: give me postings I
  /// can import instead of documents I have to key in.
  ///
  /// Null omits the section entirely, which is the honest default —
  /// there is no account mapping to invent one from.
  SafTLedgerAccounts? ledgerAccounts,
}) {
  final doc = SafTWriter(
    invoices: invoices,
    matches: matches,
    company: company,
    currency: currency,
    softwareVersion: softwareVersion,
    createdAt: createdAt,
    lineText: lineText,
    fallbackDescription: fallbackDescription,
    profile: profile,
    ledgerAccounts: ledgerAccounts,
  );
  return doc.write();
}
