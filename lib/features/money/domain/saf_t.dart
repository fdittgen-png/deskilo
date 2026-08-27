// SPDX-License-Identifier: 0BSD
import 'package:xml/xml.dart';

import 'invoice.dart';
import 'vat_rate.dart';
import 'vat_regime.dart';

/// The app version SAF-T records as the producing software
/// (`SoftwareVersion`). Cross-pinned to `pubspec.yaml` by test — an audit
/// file that names the wrong version is a lie about its own provenance.
const String safTSoftwareVersion = '1.0.0';

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
/// The four accounts the derived postings book to (#669).
///
/// Deliberately the same four the FEC, DATEV and Sage ask for, because
/// they are the same four postings — one mapping, asked for once, and no
/// second opinion about which account revenue lands in.
class SafTLedgerAccounts {
  const SafTLedgerAccounts({
    required this.customers,
    required this.revenue,
    required this.bank,
    required this.vat,
  });

  final String customers;
  final String revenue;
  final String bank;
  final String vat;
}

/// Which national declaration the file makes about itself (#669).
///
/// One tree, two headers. Every SAF-T variant is a restriction of the
/// same OECD structure, so a second builder would be a second place for
/// the invoice mapping to drift — and the mapping is the part that has
/// to agree with the document the customer holds.
enum SafTProfile {
  /// The OECD tree with `GeneralLedgerEntries` omitted, saying so in its
  /// own HeaderComment. Claims nothing national.
  generic,

  /// Portugal, `TaxAccountingBasis = 'F'` — faturação.
  ///
  /// This is NOT a partial version of the accounting variant. Portugal
  /// defines 'F' for systems that issue invoices and keep no books, and
  /// under 'F' the ledger sections are not merely tolerated as absent —
  /// they are not part of the declaration at all.
  ///
  /// What this file does NOT do is make its producer certified software.
  /// `SoftwareCertificateNumber` is written as 0, the defined value for
  /// uncertified, and the export sheet tells the owner what that means
  /// for them. See `accounting_format.dart`.
  portugal,
}

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
  String amount(int cents) => (cents / 100).toStringAsFixed(2);
  String day(DateTime date) => date.toIso8601String().split('T').first;

  final regime = vatRegimeFromWire(company.vatRegime);
  final zeroCategory = regime.taxCategoryCode;
  /// A TaxTable code has to be unique per rate, so a taxed rate carries
  /// its percentage: 'S20', 'S5.5'. A zero rate is just its category.
  String taxCode(double percent) =>
      percent > 0 ? 'S${_percent(percent)}' : zeroCategory;
  String percentage(double percent) => percent.toStringAsFixed(2);
  // Oldest first: an audit file reads like a journal.
  final ordered = [...invoices]
    ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
  final from = ordered.isEmpty ? createdAt : ordered.first.issuedAt;
  final to = ordered.isEmpty ? createdAt : ordered.last.issuedAt;
  // A voided invoice stays in the file (it happened) but carries no value.
  final live = ordered.where((i) => !i.isVoided).toList(growable: false);
  final invoiceTotal = live.fold(0, (sum, i) => sum + i.totalCents);
  final settled = [
    for (final invoice in ordered)
      if (matches[invoice.id] case final InvoiceMatch match
          when !match.pending && !invoice.isVoided)
        (invoice: invoice, match: match),
  ];
  final paidTotal = settled.fold(0, (sum, e) => sum + e.match.paidCents);
  // One customer per invoiced member — the snapshot on the document, not
  // the live profile, so a re-export of the same period never changes.
  final customers = <String, Invoice>{};
  for (final invoice in ordered) {
    customers.putIfAbsent(invoice.memberId, () => invoice);
  }

  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('AuditFile', nest: () {
    // The PT variant has its own namespace and version; an importer
    // keys on these before it reads a single element.
    builder.namespace(profile == SafTProfile.portugal
        ? 'urn:OECD:StandardAuditFile-Tax:PT_1.04_01'
        : 'urn:OECD:StandardAuditFile-Tax:2.00');

    void tag(String name, String text) {
      builder.element(name, nest: () => builder.text(text));
    }

    void address(InvoiceParty party) {
      builder.element('Address', nest: () {
        if (party.street.isNotEmpty) {
          tag('StreetName', party.street.replaceAll('\n', ', '));
        }
        if (party.city.isNotEmpty) tag('City', party.city);
        if (party.postalCode.isNotEmpty) tag('PostalCode', party.postalCode);
        tag('Country', party.country.toUpperCase());
      });
    }

    // ── Header: who, when, in what currency, over which period ─────────
    //
    // Portugal's header is a different declaration, not a decorated one:
    // its element ORDER is fixed by the schema, several elements are
    // mandatory that the generic tree does not carry, and
    // TaxAccountingBasis is the field that says what kind of file this
    // is at all. So it is built separately rather than patched.
    if (profile == SafTProfile.portugal) {
      builder.element('Header', nest: () {
        tag('AuditFileVersion', '1.04_01');
        // The NIF, digits only — the schema rejects anything else.
        tag('CompanyID', _digits(company.legalId));
        tag('TaxRegistrationNumber', _digits(company.vatId.isEmpty
            ? company.legalId
            : company.vatId));
        // 'F' = faturação. The whole reason this file can be produced
        // honestly by an app that keeps no ledger.
        tag('TaxAccountingBasis', 'F');
        tag('CompanyName', company.name);
        builder.element('CompanyAddress', nest: () {
          if (company.street.isNotEmpty) {
            tag('AddressDetail', company.street.replaceAll('\n', ', '));
          }
          if (company.city.isNotEmpty) tag('City', company.city);
          if (company.postalCode.isNotEmpty) {
            tag('PostalCode', company.postalCode);
          }
          tag('Country', company.country.toUpperCase());
        });
        tag('FiscalYear', '${from.year}');
        tag('StartDate', day(from));
        tag('EndDate', day(to));
        tag('CurrencyCode', currency);
        tag('DateCreated', day(createdAt));
        // 'Global' — the whole entity, not a branch.
        tag('TaxEntity', 'Global');
        tag('ProductCompanyTaxID', _digits(company.legalId));
        // 0 is the DEFINED value for software that is not certified in
        // Portugal, and DesKilo is not. Writing a plausible-looking
        // number here would be a false statement about the producer.
        tag('SoftwareCertificateNumber', '0');
        tag('ProductID', 'DesKilo/DesKilo');
        tag('ProductVersion', softwareVersion);
      });
    } else {
      builder.element('Header', nest: () {
        tag('AuditFileVersion', '2.00');
        tag('AuditFileCountry', company.country.toUpperCase());
        tag('AuditFileDateCreated', day(createdAt));
        tag('SoftwareCompanyName', 'DesKilo');
        tag('SoftwareID', 'DesKilo');
        tag('SoftwareVersion', softwareVersion);
        builder.element('Company', nest: () {
          if (company.legalId.isNotEmpty) {
            tag('RegistrationNumber', company.legalId);
          }
          tag('Name', company.name);
          address(company);
          if (company.vatId.isNotEmpty) {
            builder.element('TaxRegistration', nest: () {
              tag('TaxRegistrationNumber', company.vatId);
            });
          }
        });
        tag('DefaultCurrencyCode', currency);
        builder.element('SelectionCriteria', nest: () {
          tag('SelectionStartDate', day(from));
          tag('SelectionEndDate', day(to));
        });
        // Says out loud what this file is and is not. The two cases
        // differ in a way that MATTERS to whoever receives it: a file
        // with postings must not be read as a complete set of books.
        tag(
          'HeaderComment',
          ledgerAccounts == null
              ? 'Invoicing subset: Header, MasterFiles and SourceDocuments. '
                  'GeneralLedgerEntries and customer account numbers are '
                  'omitted on purpose — the chart of accounts belongs to '
                  'the accountant.'
              : 'Invoicing subset with derived postings. '
                  'GeneralLedgerEntries covers the SALES CYCLE ONLY — '
                  'invoices and the settlements against them, booked to '
                  'the accounts named at export time. It is NOT the '
                  'complete books of the entity: purchases, payroll, bank '
                  'charges and fixed assets never pass through this '
                  'system and are absent.',
        );
      });
    }

    // ── Master files: the parties and the tax treatment ────────────────
    builder.element('MasterFiles', nest: () {
      for (final entry in customers.entries) {
        final invoice = entry.value;
        final buyer = invoice.buyerParty ??
            InvoiceParty(
              name: invoice.memberName,
              street: invoice.memberAddress,
              country: company.country,
            );
        builder.element('Customer', nest: () {
          tag('CustomerID', entry.key);
          tag('Name', buyer.name.isEmpty ? invoice.memberName : buyer.name);
          address(buyer);
          if (buyer.vatId.isNotEmpty) {
            builder.element('TaxRegistration', nest: () {
              tag('TaxRegistrationNumber', buyer.vatId);
            });
          }
        });
      }
      // Every rate the file actually uses, once — a TaxTable listing a
      // rate no line carries invites the question of why it is there.
      final rates = <double>{
        for (final invoice in ordered)
          for (final total in invoice.vatBreakdown(zeroCategory: zeroCategory))
            total.percent,
      }.toList()
        ..sort((a, b) => b.compareTo(a));
      builder.element('TaxTable', nest: () {
        for (final percent in rates.isEmpty ? const [0.0] : rates) {
          builder.element('TaxTableEntry', nest: () {
            tag('TaxType', 'VAT');
            tag('TaxCode', taxCode(percent));
            tag(
              'Description',
              percent > 0
                  ? 'VAT ${_percent(percent)}%'
                  : company.taxExemptionReason.isEmpty
                      ? 'No VAT charged'
                      : company.taxExemptionReason,
            );
            tag('TaxPercentage', percentage(percent));
          });
        }
      });
    });

    // ── General ledger: the postings, when there is a mapping ─────────
    //
    // Between MasterFiles and SourceDocuments — the schema fixes the
    // order, and an importer that reads positionally silently mis-parses
    // a file that puts them the other way round.
    //
    // Omitted entirely without a mapping. A section of invented account
    // numbers would look complete and create work: every wrong code is
    // unbooked by hand.
    if (ledgerAccounts case final accounts?) {
      var debitTotal = 0;
      var creditTotal = 0;
      var lineNo = 0;
      // Counted first: SAF-T states the totals BEFORE the entries, so
      // they cannot be accumulated while writing them.
      for (final invoice in live) {
        debitTotal += invoice.chargesCents;
        creditTotal += invoice.chargesCents;
      }
      for (final e in settled) {
        debitTotal += e.match.paidCents;
        creditTotal += e.match.paidCents;
      }

      builder.element('GeneralLedgerEntries', nest: () {
        // Two journals, matching what the FEC writes: sales and bank.
        tag('NumberOfEntries', '${live.length + settled.length}');
        tag('TotalDebit', amount(debitTotal));
        tag('TotalCredit', amount(creditTotal));

        void line(String account, int debit, int credit, String text) {
          lineNo++;
          builder.element(debit > 0 ? 'DebitLine' : 'CreditLine', nest: () {
            tag('RecordID', '$lineNo');
            tag('AccountID', account);
            tag('SystemEntryDate', day(createdAt));
            tag('Description', text);
            tag(debit > 0 ? 'DebitAmount' : 'CreditAmount',
                amount(debit > 0 ? debit : credit));
          });
        }

        builder.element('Journal', nest: () {
          tag('JournalID', 'VE');
          tag('Description', 'Sales');
          for (final invoice in live) {
            builder.element('Transaction', nest: () {
              tag('TransactionID', invoice.number);
              tag('Period', '${invoice.issuedAt.month}');
              tag('TransactionDate', day(invoice.issuedAt));
              tag('Description', invoice.title);
              // The receivable at the GROSS, against revenue NET of tax
              // and the VAT beside it — one credit pair per rate, which
              // is what lets a mixed-rate month reconcile.
              line(accounts.customers, invoice.chargesCents, 0,
                  invoice.number);
              if (invoice.vatTotals.isEmpty) {
                line(accounts.revenue, 0, invoice.chargesCents,
                    invoice.number);
              } else {
                for (final total in invoice.vatTotals) {
                  line(accounts.revenue, 0, total.netCents, invoice.number);
                  if (total.vatCents > 0) {
                    line(accounts.vat, 0, total.vatCents, invoice.number);
                  }
                }
              }
            });
          }
        });

        builder.element('Journal', nest: () {
          tag('JournalID', 'BQ');
          tag('Description', 'Bank');
          for (final e in settled) {
            builder.element('Transaction', nest: () {
              tag('TransactionID', '${e.invoice.number}-P');
              // Dated when the money MOVED (0070), not when it was
              // recorded — or the ledger disagrees with the bank
              // statement it is reconciled against.
              tag('Period', '${e.match.matchedAt.month}');
              tag('TransactionDate', day(e.match.matchedAt));
              tag('Description', 'Payment ${e.invoice.number}');
              line(accounts.bank, e.match.paidCents, 0, e.invoice.number);
              line(accounts.customers, 0, e.match.paidCents,
                  e.invoice.number);
            });
          }
        });
      });
    }

    // ── Source documents: the invoices, and what settled them ──────────
    builder.element('SourceDocuments', nest: () {
      builder.element('SalesInvoices', nest: () {
        tag('NumberOfEntries', '${ordered.length}');
        tag('TotalDebit', '0.00');
        tag('TotalCredit', amount(invoiceTotal));
        for (final invoice in ordered) {
          builder.element('Invoice', nest: () {
            tag('InvoiceNo', invoice.number);
            builder.element('DocumentStatus', nest: () {
              // N = normal, A = annulled. An erroneous invoice is not
              // deleted from an audit file; it is marked.
              tag('InvoiceStatus', invoice.isVoided ? 'A' : 'N');
              tag(
                'InvoiceStatusDate',
                day(invoice.voidedAt ?? invoice.issuedAt),
              );
              tag(
                'SourceID',
                invoice.isVoided && invoice.voidedByName.isNotEmpty
                    ? invoice.voidedByName
                    : invoice.issuerName,
              );
            });
            tag('InvoiceDate', day(invoice.issuedAt));
            tag('InvoiceType', 'FT');
            tag('CustomerID', invoice.memberId);
            if (invoice.period != null) tag('Period', invoice.period!);
            final charges = invoice.lines
                .where((l) => l.amountCents > 0)
                .toList(growable: false);
            final breakdown =
                invoice.vatBreakdown(zeroCategory: zeroCategory);
            final netCents = breakdown.fold(0, (sum, t) => sum + t.netCents);
            final taxCents = breakdown.fold(0, (sum, t) => sum + t.vatCents);
            for (final (i, line) in charges.indexed) {
              final quantity =
                  line.quantity > 1 && line.amountCents % line.quantity == 0
                      ? line.quantity
                      : 1;
              final split = vatSplit(line.amountCents, line.vatPercent);
              builder.element('Line', nest: () {
                tag('LineNumber', '${i + 1}');
                final text = lineText(line);
                tag('Description', text.isEmpty ? fallbackDescription : text);
                tag('Quantity', '$quantity');
                tag('UnitOfMeasure', 'UN');
                tag('UnitPrice', amount(split.netCents ~/ quantity));
                tag('CreditAmount', amount(split.netCents));
                builder.element('TaxInformation', nest: () {
                  tag('TaxType', 'VAT');
                  tag('TaxCode', taxCode(line.vatPercent));
                  tag('TaxPercentage', percentage(line.vatPercent));
                  if (split.vatCents > 0) {
                    tag('TaxAmount', amount(split.vatCents));
                  }
                });
                if (line.vatPercent == 0 &&
                    company.taxExemptionReason.isNotEmpty) {
                  tag('TaxExemptionReason', company.taxExemptionReason);
                }
              });
            }
            builder.element('DocumentTotals', nest: () {
              tag('TaxPayable', amount(taxCents));
              tag('NetTotal', amount(netCents));
              // The solde: charges minus what the month already paid.
              tag('GrossTotal', amount(invoice.totalCents));
            });
          });
        }
      });

      builder.element('Payments', nest: () {
        tag('NumberOfEntries', '${settled.length}');
        tag('TotalDebit', amount(paidTotal));
        tag('TotalCredit', '0.00');
        for (final entry in settled) {
          builder.element('Payment', nest: () {
            tag('PaymentRefNo', entry.invoice.number);
            tag('TransactionDate', day(entry.match.matchedAt));
            tag('CustomerID', entry.invoice.memberId);
            builder.element('DocumentStatus', nest: () {
              tag('PaymentStatus', 'N');
              tag('PaymentStatusDate', day(entry.match.matchedAt));
              tag('SourceID', entry.match.byName);
            });
            builder.element('Line', nest: () {
              tag('LineNumber', '1');
              builder.element('SourceDocumentID', nest: () {
                tag('OriginatingON', entry.invoice.number);
                tag('InvoiceDate', day(entry.invoice.issuedAt));
              });
              tag('DebitAmount', amount(entry.match.paidCents));
            });
            builder.element('DocumentTotals', nest: () {
              tag('TaxPayable', '0.00');
              tag('NetTotal', amount(entry.match.paidCents));
              tag('GrossTotal', amount(entry.match.paidCents));
            });
          });
        }
      });
    });
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// '20' or '5.5' — a percentage without a pointless trailing zero, used
/// where it becomes part of a CODE rather than an amount.
String _percent(double percent) => percent == percent.roundToDouble()
    ? percent.toStringAsFixed(0)
    : percent.toString();

/// Digits only. Portuguese identifiers are numeric in the schema, and a
/// space or a country prefix that a user typed into the field is a
/// validation failure rather than a cosmetic difference.
String _digits(String value) => value.replaceAll(RegExp('[^0-9]'), '');
