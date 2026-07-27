// SPDX-License-Identifier: 0BSD
import 'package:xml/xml.dart';

import 'invoice.dart';
import 'vat_regime.dart';

/// The 27 EU member states — the e-invoice affordance shows only for
/// workspaces established in one of them (field decision: EU
/// guidelines apply to EU workspaces).
const Set<String> euCountryCodes = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR',
  'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL',
  'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
};

bool isEuCountry(String countryCode) =>
    euCountryCodes.contains(countryCode.toUpperCase());

/// EN 16931 e-invoice as UBL 2.1 XML (the EU norm's primary syntax,
/// Directive 2014/55/EU), CustomizationID `urn:cen.eu:en16931:2017`.
///
/// Mapping of the app's SOLDE model onto the norm:
///  * positive positions (subscription, overage, supplements, services,
///    packages, charge adjustments) → `InvoiceLine`s;
///  * confirmed payments/credits → `LegalMonetaryTotal/PrepaidAmount`
///    (BT-113), NOT negative lines — the norm's own place for amounts
///    already received;
///  * the invoice total (solde) → `PayableAmount` (BT-115).
///
/// Tax coding follows the seller's declared [VatRegime] (0069), because
/// the norm's fatal rules differ per category:
///  * `O` — outside the scope of VAT: no rate, no seller tax identifier
///    (BR-O-02/BR-O-05), reason code `VATEX-EU-O` (BR-O-10);
///  * `E` — exempt: rate 0, seller VAT identifier and an exemption reason
///    required (BR-E-02/BR-E-05/BR-E-10).
///
/// Element order follows the UBL 2.1 XSD sequence — a schema-invalid
/// document is rejected before any business rule is even evaluated.
/// Everything renders from the invoice's own SNAPSHOT (`seller`/`buyer`);
/// [lineText] supplies the localized position wording like the PDF.
String buildInvoiceUbl({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String Function(InvoiceLine line) lineText,
  /// BT-84, the account the payer must transfer to; '' = omit the group.
  String iban = '',
}) {
  String amount(int cents) => (cents / 100).toStringAsFixed(2);
  final regime = vatRegimeFromWire(seller.vatRegime);
  final category = regime.taxCategoryCode;
  final exemptionCode = regime.exemptionReasonCode(seller.country);
  final charges =
      invoice.lines.where((l) => l.amountCents > 0).toList(growable: false);
  final chargesCents = charges.fold(0, (sum, l) => sum + l.amountCents);
  final prepaidCents = -invoice.lines
      .where((l) => l.amountCents < 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  final issueDate = invoice.issuedAt.toIso8601String().split('T').first;
  final currency = invoice.currency;

  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('Invoice', nest: () {
    builder.namespace(
        'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
    builder.namespace(
        'urn:oasis:names:specification:ubl:schema:xsd:'
        'CommonBasicComponents-2',
        'cbc');
    builder.namespace(
        'urn:oasis:names:specification:ubl:schema:xsd:'
        'CommonAggregateComponents-2',
        'cac');

    void cbc(String name, String text,
        [Map<String, String> attrs = const {}]) {
      builder.element('cbc:$name', nest: () {
        attrs.forEach(builder.attribute);
        builder.text(text);
      });
    }

    void money(String name, int cents) =>
        cbc(name, amount(cents), {'currencyID': currency});

    cbc('CustomizationID', 'urn:cen.eu:en16931:2017');
    cbc('ID', invoice.number);
    cbc('IssueDate', issueDate);
    // 380 = commercial invoice; 384 = corrective (a replacement).
    cbc('InvoiceTypeCode', invoice.replacesNumber.isNotEmpty ? '384' : '380');
    cbc('DocumentCurrencyCode', currency);
    // BT-73/74 — the invoiced month as the norm states a period, not as
    // free-text prose in a note.
    final period = _periodDates(invoice.period);
    if (period != null) {
      builder.element('cac:InvoicePeriod', nest: () {
        cbc('StartDate', period.start);
        cbc('EndDate', period.end);
      });
    }
    if (invoice.replacesNumber.isNotEmpty) {
      builder.element('cac:BillingReference', nest: () {
        builder.element('cac:InvoiceDocumentReference', nest: () {
          cbc('ID', invoice.replacesNumber);
        });
      });
    }

    void party(String aggregate, InvoiceParty p, {required bool isSeller}) {
      builder.element('cac:$aggregate', nest: () {
        builder.element('cac:Party', nest: () {
          builder.element('cac:PostalAddress', nest: () {
            if (p.street.isNotEmpty) {
              cbc('StreetName', p.street.replaceAll('\n', ', '));
            }
            if (p.city.isNotEmpty) cbc('CityName', p.city);
            if (p.postalCode.isNotEmpty) cbc('PostalZone', p.postalCode);
            builder.element('cac:Country', nest: () {
              cbc('IdentificationCode', p.country.toUpperCase());
            });
          });
          // BT-31 / BT-48. A category-O seller must NOT carry one
          // (BR-O-02) — its identifier is the legal registration below.
          final showVat =
              p.vatId.isNotEmpty && (!isSeller || !regime.forbidsVatId);
          if (showVat) {
            builder.element('cac:PartyTaxScheme', nest: () {
              cbc('CompanyID', p.vatId);
              builder.element('cac:TaxScheme', nest: () {
                cbc('ID', 'VAT');
              });
            });
          }
          builder.element('cac:PartyLegalEntity', nest: () {
            cbc('RegistrationName', p.name);
            // BT-30 — with BT-31 absent this is what satisfies BR-CO-26.
            if (p.legalId.isNotEmpty) cbc('CompanyID', p.legalId);
          });
        });
      });
    }

    party('AccountingSupplierParty', seller, isSeller: true);
    party('AccountingCustomerParty', buyer, isSeller: false);

    // BT-81/84 — where to pay. 30 = credit transfer.
    if (iban.isNotEmpty) {
      builder.element('cac:PaymentMeans', nest: () {
        cbc('PaymentMeansCode', '30');
        builder.element('cac:PayeeFinancialAccount', nest: () {
          cbc('ID', iban.replaceAll(' ', ''));
        });
      });
    }

    builder.element('cac:TaxTotal', nest: () {
      money('TaxAmount', 0);
      builder.element('cac:TaxSubtotal', nest: () {
        money('TaxableAmount', chargesCents);
        money('TaxAmount', 0);
        builder.element('cac:TaxCategory', nest: () {
          cbc('ID', category);
          // BR-E-05 wants the 0 rate spelled out; BR-O-05 forbids a rate.
          if (regime == VatRegime.exempt) cbc('Percent', '0');
          if (exemptionCode.isNotEmpty) {
            cbc('TaxExemptionReasonCode', exemptionCode);
          }
          if (seller.taxExemptionReason.isNotEmpty) {
            cbc('TaxExemptionReason', seller.taxExemptionReason);
          }
          builder.element('cac:TaxScheme', nest: () {
            cbc('ID', 'VAT');
          });
        });
      });
    });

    builder.element('cac:LegalMonetaryTotal', nest: () {
      money('LineExtensionAmount', chargesCents);
      money('TaxExclusiveAmount', chargesCents);
      money('TaxInclusiveAmount', chargesCents);
      if (prepaidCents > 0) money('PrepaidAmount', prepaidCents);
      money('PayableAmount', invoice.totalCents);
    });

    for (final (i, line) in charges.indexed) {
      // Keep quantity × unit price arithmetically consistent: the real
      // quantity when the amount divides evenly by it, otherwise one
      // line at its full amount.
      final quantity = line.quantity > 1 && line.amountCents % line.quantity == 0
          ? line.quantity
          : 1;
      final unitCents = line.amountCents ~/ quantity;
      builder.element('cac:InvoiceLine', nest: () {
        cbc('ID', '${i + 1}');
        cbc('InvoicedQuantity', '$quantity', {'unitCode': 'C62'});
        money('LineExtensionAmount', line.amountCents);
        builder.element('cac:Item', nest: () {
          cbc('Name', lineText(line));
          builder.element('cac:ClassifiedTaxCategory', nest: () {
            cbc('ID', category);
            if (regime == VatRegime.exempt) cbc('Percent', '0');
            builder.element('cac:TaxScheme', nest: () {
              cbc('ID', 'VAT');
            });
          });
        });
        builder.element('cac:Price', nest: () {
          money('PriceAmount', unitCents);
        });
      });
    }
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// 'yyyy-MM' → the month's first and last calendar day.
({String start, String end})? _periodDates(String? period) {
  if (period == null) return null;
  final parts = period.split('-');
  if (parts.length < 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return null;
  final last = DateTime(year, month + 1, 0);
  final mm = month.toString().padLeft(2, '0');
  return (
    start: '$year-$mm-01',
    end: '$year-$mm-${last.day.toString().padLeft(2, '0')}',
  );
}
