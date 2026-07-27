// SPDX-License-Identifier: 0BSD
import 'package:xml/xml.dart';

import 'invoice.dart';
import 'vat_regime.dart';

/// EN 16931 as UN/CEFACT **CII** (Cross Industry Invoice, D16B) — the
/// syntax Factur-X embeds inside the PDF. Same semantics as the UBL
/// builder, different grammar: France, Germany and every hybrid workflow
/// exchange CII, so a coworking that sends one PDF sends this.
///
/// Profile: `urn:cen.eu:en16931:2017` (Factur-X EN 16931 / COMFORT) — the
/// app's positions carry enough for the full norm profile, so there is no
/// reason to downgrade to BASIC.
///
/// Element ORDER is the whole game in CII: every group is an XSD sequence,
/// and a document out of order is rejected before a single business rule is
/// read. The order below follows the norm's own mapping table.
String buildInvoiceCii({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String Function(InvoiceLine line) lineText,
  String iban = '',
}) {
  String amount(int cents) => (cents / 100).toStringAsFixed(2);
  /// CII dates are `format="102"` — YYYYMMDD, no separators.
  String stamp(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  final regime = vatRegimeFromWire(seller.vatRegime);
  final category = regime.taxCategoryCode;
  final exemptionCode = regime.exemptionReasonCode(seller.country);
  final charges =
      invoice.lines.where((l) => l.amountCents > 0).toList(growable: false);
  final chargesCents = charges.fold(0, (sum, l) => sum + l.amountCents);
  final prepaidCents = -invoice.lines
      .where((l) => l.amountCents < 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  final currency = invoice.currency;

  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('rsm:CrossIndustryInvoice', nest: () {
    builder.namespace(
        'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100', 'rsm');
    builder.namespace(
        'urn:un:unece:uncefact:data:standard:'
        'ReusableAggregateBusinessInformationEntity:100',
        'ram');
    builder.namespace(
        'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100', 'udt');

    void ram(String name, String text,
        [Map<String, String> attrs = const {}]) {
      builder.element('ram:$name', nest: () {
        attrs.forEach(builder.attribute);
        builder.text(text);
      });
    }

    void money(String name, int cents,
            [Map<String, String> attrs = const {}]) =>
        ram(name, amount(cents), attrs);

    void date(String name, DateTime value) {
      builder.element('ram:$name', nest: () {
        builder.element('udt:DateTimeString', nest: () {
          builder.attribute('format', '102');
          builder.text(stamp(value));
        });
      });
    }

    // ── Context: which guideline this document claims to follow ────────
    builder.element('rsm:ExchangedDocumentContext', nest: () {
      builder.element('ram:GuidelineSpecifiedDocumentContextParameter',
          nest: () {
        ram('ID', 'urn:cen.eu:en16931:2017');
      });
    });

    // ── The document itself ────────────────────────────────────────────
    builder.element('rsm:ExchangedDocument', nest: () {
      ram('ID', invoice.number);
      // 380 = commercial invoice; 384 = corrective (a replacement).
      ram('TypeCode', invoice.replacesNumber.isNotEmpty ? '384' : '380');
      date('IssueDateTime', invoice.issuedAt);
    });

    builder.element('rsm:SupplyChainTradeTransaction', nest: () {
      // ── Lines ────────────────────────────────────────────────────────
      for (final (i, line) in charges.indexed) {
        final quantity =
            line.quantity > 1 && line.amountCents % line.quantity == 0
                ? line.quantity
                : 1;
        final unitCents = line.amountCents ~/ quantity;
        builder.element('ram:IncludedSupplyChainTradeLineItem', nest: () {
          builder.element('ram:AssociatedDocumentLineDocument', nest: () {
            ram('LineID', '${i + 1}');
          });
          builder.element('ram:SpecifiedTradeProduct', nest: () {
            ram('Name', lineText(line));
          });
          builder.element('ram:SpecifiedLineTradeAgreement', nest: () {
            builder.element('ram:NetPriceProductTradePrice', nest: () {
              money('ChargeAmount', unitCents);
            });
          });
          builder.element('ram:SpecifiedLineTradeDelivery', nest: () {
            ram('BilledQuantity', '$quantity', {'unitCode': 'C62'});
          });
          builder.element('ram:SpecifiedLineTradeSettlement', nest: () {
            builder.element('ram:ApplicableTradeTax', nest: () {
              ram('TypeCode', 'VAT');
              ram('CategoryCode', category);
              // BR-E-05 wants the zero rate spelled out; BR-O-05 forbids
              // any rate at all.
              if (regime == VatRegime.exempt) {
                ram('RateApplicablePercent', '0');
              }
            });
            builder.element(
                'ram:SpecifiedTradeSettlementLineMonetarySummation',
                nest: () {
              money('LineTotalAmount', line.amountCents);
            });
          });
        });
      }

      // ── Who trades with whom ─────────────────────────────────────────
      void party(String element, InvoiceParty p, {required bool isSeller}) {
        builder.element('ram:$element', nest: () {
          ram('Name', p.name);
          // BT-30 — the identifier a category-O seller is allowed to carry
          // (BR-O-02 forbids the tax registration below).
          if (isSeller && p.legalId.isNotEmpty) {
            builder.element('ram:SpecifiedLegalOrganization', nest: () {
              ram('ID', p.legalId);
            });
          }
          builder.element('ram:PostalTradeAddress', nest: () {
            // Postcode FIRST — the CII sequence is not the human order.
            if (p.postalCode.isNotEmpty) ram('PostcodeCode', p.postalCode);
            if (p.street.isNotEmpty) {
              ram('LineOne', p.street.replaceAll('\n', ', '));
            }
            if (p.city.isNotEmpty) ram('CityName', p.city);
            ram('CountryID', p.country.toUpperCase());
          });
          final showVat =
              p.vatId.isNotEmpty && (!isSeller || !regime.forbidsVatId);
          if (showVat) {
            builder.element('ram:SpecifiedTaxRegistration', nest: () {
              ram('ID', p.vatId, {'schemeID': 'VA'});
            });
          }
        });
      }

      builder.element('ram:ApplicableHeaderTradeAgreement', nest: () {
        party('SellerTradeParty', seller, isSeller: true);
        party('BuyerTradeParty', buyer, isSeller: false);
      });
      // Mandatory even when empty: services have no delivery event.
      builder.element('ram:ApplicableHeaderTradeDelivery', nest: () {});

      builder.element('ram:ApplicableHeaderTradeSettlement', nest: () {
        ram('InvoiceCurrencyCode', currency);
        if (iban.isNotEmpty) {
          builder.element('ram:SpecifiedTradeSettlementPaymentMeans',
              nest: () {
            // 30 = credit transfer.
            ram('TypeCode', '30');
            builder.element('ram:PayeePartyCreditorFinancialAccount',
                nest: () {
              ram('IBANID', iban.replaceAll(' ', ''));
            });
          });
        }
        builder.element('ram:ApplicableTradeTax', nest: () {
          money('CalculatedAmount', 0);
          ram('TypeCode', 'VAT');
          if (seller.taxExemptionReason.isNotEmpty) {
            ram('ExemptionReason', seller.taxExemptionReason);
          }
          money('BasisAmount', chargesCents);
          ram('CategoryCode', category);
          if (exemptionCode.isNotEmpty) {
            ram('ExemptionReasonCode', exemptionCode);
          }
          if (regime == VatRegime.exempt) ram('RateApplicablePercent', '0');
        });
        final period = _periodDates(invoice.period);
        if (period != null) {
          builder.element('ram:BillingSpecifiedPeriod', nest: () {
            date('StartDateTime', period.start);
            date('EndDateTime', period.end);
          });
        }
        builder.element('ram:SpecifiedTradeSettlementHeaderMonetarySummation',
            nest: () {
          money('LineTotalAmount', chargesCents);
          money('TaxBasisTotalAmount', chargesCents);
          money('TaxTotalAmount', 0, {'currencyID': currency});
          money('GrandTotalAmount', chargesCents);
          if (prepaidCents > 0) money('TotalPrepaidAmount', prepaidCents);
          // The solde — what is left to pay.
          money('DuePayableAmount', invoice.totalCents);
        });
        if (invoice.replacesNumber.isNotEmpty) {
          builder.element('ram:InvoiceReferencedDocument', nest: () {
            ram('IssuerAssignedID', invoice.replacesNumber);
          });
        }
      });
    });
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// 'yyyy-MM' → the month's first and last day.
({DateTime start, DateTime end})? _periodDates(String? period) {
  if (period == null) return null;
  final parts = period.split('-');
  if (parts.length < 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return null;
  return (start: DateTime(year, month), end: DateTime(year, month + 1, 0));
}
