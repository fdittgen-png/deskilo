// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — SAF-T Financial: the general ledger of a local book as the OECD
// tree, written from the posting engine's entries (`compute_postings`). One
// builder, one tree; each national variant is a [SafTFinancialProfile] that
// fixes the namespace, the version and what the authority requires on top
// (Norway: a grouping code per account and a standard VAT code per tax
// code; Luxembourg: a standard account per account and postal addresses).
//
// What it is: the master files (accounts with their opening and closing
// balance for the fiscal year, customers and suppliers by their sub-ledger
// number, the tax table with its dated rates) and the general ledger
// entries, one transaction per posting, every line naming its source
// document. What it is not: the source documents section, and the entity's
// complete books unless every operation passes through this system — the
// file says so in its own header.
//
// Nothing is invented: a mapping the reference store does not hold, a rate
// it does not know, a company or party field the authority requires and the
// data lacks, or an identifier longer than the schema allows stops the file,
// and each one is named.
import '../../../core/vat/tax_reference.dart';
import 'book_chart.dart';
import 'fiscal_year.dart';
import 'invoice.dart';
import 'posting.dart';
import 'saf_t_financial_xml.dart';
import 'supplier.dart';

/// Which SAF-T Financial declaration the file makes about itself.
enum SafTFinancialProfile {
  /// The OECD 2.0 tree, no national restriction: an exchange file.
  oecd(
    formatId: 'saft_oecd_full',
    country: '',
    namespace: 'urn:OECD:StandardAuditFile-Taxation/2.00',
    version: '2.00',
    accountingBasis: 'A',
    taxType: 'VAT',
    taxDescription: 'Value added tax',
  ),

  /// Skatteetaten's SAF-T Financial 1.30 (mandatory from the accounting
  /// period starting 1 January 2025).
  norway(
    formatId: 'saft_no',
    country: 'NO',
    namespace: 'urn:StandardAuditFile-Taxation-Financial:NO',
    version: '1.30',
    // The schema's only value: A, accounting.
    accountingBasis: 'A',
    // The schema's only values.
    taxType: 'MVA',
    taxDescription: 'Merverdiavgift',
  ),

  /// The Administration de l'enregistrement's FAIA 2.01 (the OECD 2.0
  /// tree as Luxembourg publishes it).
  luxembourg(
    formatId: 'faia_lu',
    country: 'LU',
    namespace: 'urn:OECD:StandardAuditFile-Taxation/2.00',
    version: '2.01',
    // One of the schema's documented values.
    accountingBasis: 'Invoice Accounting',
    // The schema's fixed value.
    taxType: 'TVA',
    taxDescription: 'Taxe sur la valeur ajoutée',
  ),

  /// #2379 — Erhvervsstyrelsen's Danish SAF-T Financial 2.1 (bogføringslov
  /// 2022, digital bookkeeping): the OECD tree in its own namespace, with
  /// the tax entity required in the header. The standard chart account
  /// (`StandardAccountID`) is optional in the schema and is not written.
  denmark(
    formatId: 'saft_dk',
    country: 'DK',
    namespace: 'urn:StandardAuditFile-Taxation-Financial:DK',
    version: '2.1',
    // The authority's own sample's value.
    accountingBasis: 'Regnskabsdata',
    taxType: 'VAT',
    // The schema's only value.
    taxDescription: 'VAT',
    taxEntityRequired: true,
    standardAccountRequired: false,
  );

  const SafTFinancialProfile({
    required this.formatId,
    required this.country,
    required this.namespace,
    required this.version,
    required this.accountingBasis,
    required this.taxType,
    required this.taxDescription,
    this.taxEntityRequired = false,
    this.standardAccountRequired = true,
  });

  /// The export format this profile writes.
  final String formatId;

  /// The country whose reference rows (`account_map`, `saf_t/…`) map the
  /// chart; empty for the OECD tree, which maps nothing.
  final String country;
  final String namespace;
  final String version;
  final String accountingBasis;
  final String taxType;

  /// The tax table's description of [taxType].
  final String taxDescription;

  /// Whether the header names its tax entity (Denmark: required).
  final bool taxEntityRequired;

  /// Whether every account must map to the authority's standard account
  /// (Norway, Luxembourg); Denmark's schema leaves it optional.
  final bool standardAccountRequired;

  /// #2379 — Denmark's file names the standard chart it refers to (the
  /// schema's fixed values) and carries its parties by number only.
  bool get denmarkShape => this == SafTFinancialProfile.denmark;

  /// The standard chart Denmark's `GeneralLedgerAccounts` names (fixed by
  /// the schema 2.1: `Standardkontoplanen`, version `20230131`).
  static const dkStandardChart = ('Standardkontoplanen', '20230131');

  /// The journal type Denmark's schema knows for [journal]: receivables,
  /// payables, adjustments, else the general ledger.
  static String dkJournalType(PostingJournal journal) => switch (journal) {
    PostingJournal.sales => 'AR',
    PostingJournal.purchases => 'AP',
    PostingJournal.other => 'AJ',
    PostingJournal.bank => 'GL',
  };

  static SafTFinancialProfile? ofFormat(String formatId) => [
    for (final p in values)
      if (p.formatId == formatId) p,
  ].firstOrNull;
}

/// The format ids the profiles write.
final Set<String> safTFinancialFormats = {
  for (final p in SafTFinancialProfile.values) p.formatId,
};

/// The person the authority may contact about the file: the one who made it.
class SafTContact {
  const SafTContact({
    required this.firstName,
    required this.lastName,
    this.phone = '',
  });

  final String firstName;
  final String lastName;
  final String phone;
}

/// A customer or a supplier as the master files describe it.
class SafTParty {
  const SafTParty({
    required this.name,
    this.street = '',
    this.city = '',
    this.postalCode = '',
    this.country = '',
    this.vatId = '',
  });

  final String name;
  final String street;
  final String city;
  final String postalCode;
  final String country;
  final String vatId;
}

/// The key of a party in [SafTFinancialRequest.partyDetails].
String safTPartyKey(String kind, String number) => '$kind:$number';

/// The address and tax number of every party [parties] names (the posted
/// documents of the fiscal year AND of the opening period, by document id):
/// a member as the document froze it, found among [invoices] by the
/// document's id; a supplier as [suppliers] registers it.
Map<String, SafTParty> safTPartyDetails({
  required Map<String, PostingParty> parties,
  required Iterable<Invoice> invoices,
  required Iterable<Supplier> suppliers,
}) {
  final byId = {for (final i in invoices) i.id: i};
  final registered = {for (final s in suppliers) s.number: s};
  final details = <String, SafTParty>{};
  for (final MapEntry(key: documentId, value: party) in parties.entries) {
    if (party.number.isEmpty) continue;
    final key = safTPartyKey(party.kind, party.number);
    if (party.kind == 'member') {
      if (byId[documentId]?.buyerParty case final buyer?) {
        details[key] = SafTParty(
          name: buyer.name,
          street: buyer.street,
          city: buyer.city,
          postalCode: buyer.postalCode,
          country: buyer.country,
          vatId: buyer.vatId,
        );
      }
    } else if (registered[party.number] case final s?) {
      details[key] = SafTParty(
        name: s.name,
        street: s.street,
        city: s.city,
        postalCode: s.postalCode,
        country: s.countryCode,
        vatId: s.taxIdentifier,
      );
    }
  }
  return details;
}

/// What one SAF-T Financial file is built from.
class SafTFinancialRequest {
  const SafTFinancialRequest({
    required this.profile,
    required this.period,
    required this.postings,
    required this.opening,
    required this.accountNames,
    required this.accountTypes,
    required this.parties,
    required this.partyDetails,
    required this.company,
    required this.contact,
    required this.currency,
    required this.softwareVersion,
    required this.createdAt,
    required this.reference,
    this.companyIban = '',
  });

  final SafTFinancialProfile profile;

  /// The fiscal year the file covers.
  final FiscalYear period;

  /// The year's postings, in the engine's order.
  final List<Posting> postings;

  /// Every posting of the book before [period]: the opening balances.
  final List<Posting> opening;
  final Map<String, String> accountNames;
  final Map<String, AccountType> accountTypes;

  /// The third party of each posted document, by document id.
  final Map<String, PostingParty> parties;

  /// The address and tax number of each party, by [safTPartyKey].
  final Map<String, SafTParty> partyDetails;
  final InvoiceParty company;
  final SafTContact contact;

  /// The book's currency.
  final String currency;
  final String softwareVersion;
  final DateTime createdAt;

  /// The reference store: the rates and the profile's mappings.
  final TaxReferenceSet reference;

  /// #2379 — the company's IBAN, which Denmark's header requires.
  final String companyIban;
}

/// What a missing fact is about.
enum SafTGapKind {
  /// An account the profile's chart map does not cover.
  standardAccount,

  /// A tax code with no standard code of the profile.
  standardTaxCode,

  /// A tax line whose rate group the reference does not know on its day.
  taxRate,

  /// A field of the company the schema requires.
  company,

  /// A field of the contact person the schema requires.
  contact,

  /// A third party without its number, or without a field the profile
  /// requires.
  party,

  /// An identifier longer than the schema allows; it is never cut.
  tooLong,
}

class SafTGap {
  const SafTGap(this.kind, this.subject);
  final SafTGapKind kind;

  /// The account, tax, field, party or value the gap is about.
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is SafTGap && other.kind == kind && other.subject == subject;

  @override
  int get hashCode => Object.hash(kind, subject);

  @override
  String toString() => 'SafTGap(${kind.name}: $subject)';
}

sealed class SafTFinancialResult {
  const SafTFinancialResult();
}

final class SafTFinancialFile extends SafTFinancialResult {
  const SafTFinancialFile(this.xml);
  final String xml;
}

/// Nothing was written; every gap is named.
final class SafTFinancialRefused extends SafTFinancialResult {
  const SafTFinancialRefused(this.gaps);
  final List<SafTGap> gaps;
}

/// The SAF-T Financial file of [request], or why there is none.
SafTFinancialResult buildSafTFinancial(SafTFinancialRequest request) =>
    SafTFinancialXml(request).write();
