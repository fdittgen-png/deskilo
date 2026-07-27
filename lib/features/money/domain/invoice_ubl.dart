// SPDX-License-Identifier: 0BSD
import 'package:xml/xml.dart';

import 'invoice.dart';

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
/// Directive 2014/55/EU).
///
/// Mapping of the app's SOLDE model onto the norm:
///  * positive positions (subscription, overage, supplements,
///    services, packages, charge adjustments) → `InvoiceLine`s;
///  * confirmed payments/credits → `LegalMonetaryTotal/PrepaidAmount`
///    (BT-113), NOT negative lines — the norm's own place for amounts
///    already received;
///  * the invoice total (solde) → `PayableAmount` (BT-115).
///
/// The app does not track VAT (coworking communities are typically
/// VAT-exempt small operators), so every line carries tax category
/// `O` — services outside the scope of VAT (BT-151), with the
/// mandated exemption reason — and the tax total is zero. Everything
/// renders from the invoice's SNAPSHOT fields; [lineText] supplies the
/// localized position wording like the PDF.
String buildInvoiceUbl({
  required Invoice invoice,
  required String countryCode,
  required String Function(InvoiceLine line) lineText,
}) {
  String amount(int cents) => (cents / 100).toStringAsFixed(2);
  final charges =
      invoice.lines.where((l) => l.amountCents > 0).toList(growable: false);
  final chargesCents =
      charges.fold(0, (sum, l) => sum + l.amountCents);
  final prepaidCents = -invoice.lines
      .where((l) => l.amountCents < 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  final issueDate =
      invoice.issuedAt.toIso8601String().split('T').first;

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

    cbc('CustomizationID', 'urn:cen.eu:en16931:2017');
    cbc('ID', invoice.number);
    cbc('IssueDate', issueDate);
    // 380 = commercial invoice; 384 = corrective (a replacement).
    cbc('InvoiceTypeCode',
        invoice.replacesNumber.isNotEmpty ? '384' : '380');
    if (invoice.period != null) cbc('Note', invoice.period!);
    cbc('DocumentCurrencyCode', invoice.currency);
    if (invoice.replacesNumber.isNotEmpty) {
      builder.element('cac:BillingReference', nest: () {
        builder.element('cac:InvoiceDocumentReference', nest: () {
          cbc('ID', invoice.replacesNumber);
        });
      });
    }

    void party(String aggregate, String name, String address) {
      builder.element('cac:$aggregate', nest: () {
        builder.element('cac:Party', nest: () {
          builder.element('cac:PostalAddress', nest: () {
            if (address.isNotEmpty) {
              cbc('StreetName', address.replaceAll('\n', ', '));
            }
            builder.element('cac:Country', nest: () {
              cbc('IdentificationCode', countryCode.toUpperCase());
            });
          });
          builder.element('cac:PartyLegalEntity', nest: () {
            cbc('RegistrationName', name);
          });
        });
      });
    }

    party('AccountingSupplierParty', invoice.workspaceName,
        invoice.workspaceAddress);
    party('AccountingCustomerParty', invoice.memberName,
        invoice.memberAddress);

    builder.element('cac:TaxTotal', nest: () {
      cbc('TaxAmount', '0.00', {'currencyID': invoice.currency});
      builder.element('cac:TaxSubtotal', nest: () {
        cbc('TaxableAmount', amount(chargesCents),
            {'currencyID': invoice.currency});
        cbc('TaxAmount', '0.00', {'currencyID': invoice.currency});
        builder.element('cac:TaxCategory', nest: () {
          cbc('ID', 'O');
          cbc('TaxExemptionReason',
              'Services outside the scope of VAT');
          builder.element('cac:TaxScheme', nest: () {
            cbc('ID', 'VAT');
          });
        });
      });
    });

    builder.element('cac:LegalMonetaryTotal', nest: () {
      cbc('LineExtensionAmount', amount(chargesCents),
          {'currencyID': invoice.currency});
      cbc('TaxExclusiveAmount', amount(chargesCents),
          {'currencyID': invoice.currency});
      cbc('TaxInclusiveAmount', amount(chargesCents),
          {'currencyID': invoice.currency});
      if (prepaidCents > 0) {
        cbc('PrepaidAmount', amount(prepaidCents),
            {'currencyID': invoice.currency});
      }
      cbc('PayableAmount', amount(invoice.totalCents),
          {'currencyID': invoice.currency});
    });

    for (final (i, line) in charges.indexed) {
      builder.element('cac:InvoiceLine', nest: () {
        cbc('ID', '${i + 1}');
        cbc('InvoicedQuantity', '1', {'unitCode': 'C62'});
        cbc('LineExtensionAmount', amount(line.amountCents),
            {'currencyID': invoice.currency});
        builder.element('cac:Item', nest: () {
          cbc('Name', lineText(line));
          builder.element('cac:ClassifiedTaxCategory', nest: () {
            cbc('ID', 'O');
            builder.element('cac:TaxScheme', nest: () {
              cbc('ID', 'VAT');
            });
          });
        });
        builder.element('cac:Price', nest: () {
          cbc('PriceAmount', amount(line.amountCents),
              {'currencyID': invoice.currency});
        });
      });
    }
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}
