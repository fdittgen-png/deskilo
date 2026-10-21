// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:xml/xml.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/number_text.dart';
import 'invoice.dart';
import 'saf_t_ledger.dart';
import 'vat_rate.dart';
import 'vat_regime.dart';

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

/// Writes one SAF-T tree: the header, the master files, the optional
/// ledger and the source documents, each in its own method so the schema's
/// section order reads off [write].
class SafTWriter {
  SafTWriter({
    required this.invoices,
    required this.matches,
    required this.company,
    required this.currency,
    required this.softwareVersion,
    required this.createdAt,
    required this.lineText,
    required this.fallbackDescription,
    required this.profile,
    required this.ledgerAccounts,
  });

  final List<Invoice> invoices;
  final Map<String, InvoiceMatch> matches;
  final InvoiceParty company;
  final String currency;
  final String softwareVersion;
  final DateTime createdAt;
  final String Function(InvoiceLine line) lineText;
  final String fallbackDescription;
  final SafTProfile profile;
  final SafTLedgerAccounts? ledgerAccounts;

  final XmlBuilder builder = XmlBuilder();

  // #1077 — the currency's own grain, not the euro's.
  String amount(int minor) => minorToText(minor, currency);
  String day(DateTime date) => date.toIso8601String().split('T').first;

  late final regime = vatRegimeFromWire(company.vatRegime);
  late final zeroCategory = regime.taxCategoryCode;

  /// A TaxTable code has to be unique per rate, so a taxed rate carries
  /// its percentage: 'S20', 'S5.5'. A zero rate is just its category.
  String taxCode(double percent) =>
      percent > 0 ? 'S${percentText(percent)}' : zeroCategory;
  String percentage(double percent) => percent.toStringAsFixed(2);

  // Oldest first: an audit file reads like a journal.
  late final ordered = [...invoices]
    ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
  late final from = ordered.isEmpty ? createdAt : ordered.first.issuedAt;
  late final to = ordered.isEmpty ? createdAt : ordered.last.issuedAt;
  // A voided invoice stays in the file (it happened) but carries no value.
  late final live = ordered.where((i) => !i.isVoided).toList(growable: false);
  late final invoiceTotal = live.fold(0, (sum, i) => sum + i.totalCents);
  late final settled = [
    for (final invoice in ordered)
      if (matches[invoice.id] case final InvoiceMatch match
          when !match.pending && !invoice.isVoided)
        (invoice: invoice, match: match),
  ];
  late final paidTotal = settled.fold(0, (sum, e) => sum + e.match.paidCents);
  // One customer per invoiced member — the snapshot on the document, not
  // the live profile, so a re-export of the same period never changes.
  late final customers = () {
    final byMember = <String, Invoice>{};
    for (final invoice in ordered) {
      byMember.putIfAbsent(invoice.memberId, () => invoice);
    }
    return byMember;
  }();

  String write() {
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('AuditFile', nest: () {
      // The PT variant has its own namespace and version; an importer
      // keys on these before it reads a single element.
      builder.namespace(profile == SafTProfile.portugal
          ? 'urn:OECD:StandardAuditFile-Tax:PT_1.04_01'
          : 'urn:OECD:StandardAuditFile-Tax:2.00');
      header();
      masterFiles();
      generalLedger();
      sourceDocuments();
    });
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

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

  void header() {
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
                  'system and are absent. Credit notes reverse the sale; '
                  'expense reimbursements and goodwill adjustments netted '
                  'on an invoice, and write-offs, are not posted.',
        );
      });
    }
  }

  void masterFiles() {
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
                  ? 'VAT ${percentText(percent)}%'
                  : company.taxExemptionReason.isEmpty
                      ? 'No VAT charged'
                      : company.taxExemptionReason,
            );
            tag('TaxPercentage', percentage(percent));
          });
        }
      });
    });
  }

  void generalLedger() {
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
      var lineNo = 0;
      // Built first: SAF-T states the totals BEFORE the entries, so they
      // are the sums of the transactions about to be written.
      final sales = [...safTSalesTransactions(live, accounts), ...safTWriteOffs(settled, accounts)];
      final bank = [
        ...safTNettedReceipts(live, accounts),
        ...safTSettlements(settled, accounts),
      ];
      final all = [...sales, ...bank];

      builder.element('GeneralLedgerEntries', nest: () {
        // Two journals, matching what the FEC writes: sales and bank.
        tag('NumberOfEntries', '${all.length}');
        tag('TotalDebit', amount(all.fold(0, (s, t) => s + t.debitTotal)));
        tag('TotalCredit', amount(all.fold(0, (s, t) => s + t.creditTotal)));

        void journal(String id, String name, List<SafTLedgerTransaction> txs) {
          builder.element('Journal', nest: () {
            tag('JournalID', id);
            tag('Description', name);
            for (final t in txs) {
              builder.element('Transaction', nest: () {
                tag('TransactionID', t.id);
                tag('Period', '${t.date.month}');
                tag('TransactionDate', day(t.date));
                tag('Description', t.description);
                for (final l in t.lines) {
                  lineNo++;
                  builder.element(l.debit > 0 ? 'DebitLine' : 'CreditLine',
                      nest: () {
                    tag('RecordID', '$lineNo');
                    tag('AccountID', l.account);
                    tag('SystemEntryDate', day(createdAt));
                    tag('Description', l.text);
                    tag(l.debit > 0 ? 'DebitAmount' : 'CreditAmount',
                        amount(l.debit > 0 ? l.debit : l.credit));
                  });
                }
              });
            }
          });
        }

        journal('VE', 'Sales', sales);
        journal('BQ', 'Bank', bank);
      });
    }
  }

  void sourceDocuments() {
    // ── Source documents: the invoices, and what settled them ──────────
    builder.element('SourceDocuments', nest: () {
      salesInvoices();
      payments();
    });
  }

  void salesInvoices() {
    builder.element('SalesInvoices', nest: () {
      tag('NumberOfEntries', '${ordered.length}');
      tag('TotalDebit', '0.00');
      tag('TotalCredit', amount(invoiceTotal));
      ordered.forEach(salesInvoice);
    });
  }

  void salesInvoice(Invoice invoice) {
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
      final breakdown = invoice.vatBreakdown(zeroCategory: zeroCategory);
      final netCents = breakdown.fold(0, (sum, t) => sum + t.netCents);
      final taxCents = breakdown.fold(0, (sum, t) => sum + t.vatCents);
      for (final (i, line) in charges.indexed) {
        invoiceLine(i, line);
      }
      builder.element('DocumentTotals', nest: () {
        tag('TaxPayable', amount(taxCents));
        tag('NetTotal', amount(netCents));
        // The solde: charges minus what the month already paid.
        tag('GrossTotal', amount(invoice.totalCents));
      });
    });
  }

  void invoiceLine(int i, InvoiceLine line) {
    final split = vatSplit(line.amountCents, line.vatPercent);
    // #1091 — the UnitPrice below is the NET per unit, so the
    // quantity must divide the NET. See invoice_ubl.dart.
    final quantity = line.quantity > 1 && split.netCents % line.quantity == 0
        ? line.quantity
        : 1;
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
      if (line.vatPercent == 0 && company.taxExemptionReason.isNotEmpty) {
        tag('TaxExemptionReason', company.taxExemptionReason);
      }
    });
  }

  void payments() {
    builder.element('Payments', nest: () {
      tag('NumberOfEntries', '${settled.length}');
      tag('TotalDebit', amount(paidTotal));
      tag('TotalCredit', '0.00');
      settled.forEach(payment);
    });
  }

  void payment(({Invoice invoice, InvoiceMatch match}) entry) {
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
}

/// Digits only. Portuguese identifiers are numeric in the schema, and a
/// space or a country prefix that a user typed into the field is a
/// validation failure rather than a cosmetic difference.
String _digits(String value) => value.replaceAll(RegExp('[^0-9]'), '');
