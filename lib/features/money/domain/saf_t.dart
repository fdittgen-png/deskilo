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
    builder.namespace('urn:OECD:StandardAuditFile-Tax:2.00');

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
      // Says out loud what this file is and is not.
      tag(
        'HeaderComment',
        'Invoicing subset: Header, MasterFiles and SourceDocuments. '
            'GeneralLedgerEntries and customer account numbers are omitted '
            'on purpose — the chart of accounts belongs to the accountant.',
      );
    });

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
