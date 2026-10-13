// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:xml/xml.dart';

import '../../../core/time/date_text.dart';
import 'vat_compliance.dart';
import 'vat_declaration.dart';
import 'vat_filing_files.dart';

/// The MWST-Abrechnung as eCH-0217 version 2.0 (`VATDeclaration`), the XML
/// the ESTV ePortal takes for upload (#2360): the effective method, turnover
/// net (`grossOrNet` 1, the ESTV's recommendation), every amount to the
/// centime. `payableTax` is computed the way the standard prescribes (6.2.3):
/// the rate times the declared turnover, summed without rounding, less the
/// input tax, rounded to the centime at the end; the application checks it
/// (TVA-0006), so it can differ by a few centimes from the form's tax line
/// that adds the tax of each invoice.
///
/// Not mapped: 205 (supplies opted for; the lines do not say which taxed
/// supply was a letting that was exempt but for the option), 225, 235, 280,
/// 382/383, 410, 415, 420 and the other flows of funds (9xx). A first filing
/// is declared (`typeOfSubmission` 1); a rectification is another file.
/// Validated against the published XSD `eCH-0217-2-0-0.xsd`.
String ech0217Xml({
  required VatDeclaration declaration,
  required String uid,
  required String organisationName,
  required bool onReceipts,
  required DateTime generatedAt,
}) {
  final id = uid.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^CHE([1-9]\d{8})(MWST|TVA|IVA)?$').firstMatch(id);
  if (m == null || !isValidSwissUid(uid, requireSuffix: false)) {
    throw const VatFilingFileException(VatFilingFileProblem.uid);
  }
  var total = 0, abroad = 0, toForeign = 0, exempt = 0;
  var materials = 0, investments = 0;
  final turnoverByRate = <double, int>{};
  for (final line in declaration.lines) {
    if (line.isInput) {
      if (line.category == 'asset') {
        investments += line.vatCents;
      } else {
        materials += line.vatCents;
      }
      continue;
    }
    total += line.netCents;
    switch (line.category.isEmpty ? (line.percent > 0 ? 'S' : 'O') : line.category) {
      case 'Z' || 'G':
        toForeign += line.netCents;
      case 'AE' || 'O':
        abroad += line.netCents;
      case 'E':
        exempt += line.netCents;
      default:
        turnoverByRate[line.percent] = (turnoverByRate[line.percent] ?? 0) + line.netCents;
    }
  }
  // payableTax: the sum of rate x turnover in hundredths of a centime
  // (percent with two decimals x cents), less the input tax, half up.
  var taxMilli = 0;
  turnoverByRate.forEach((rate, cents) {
    taxMilli += (rate * 100).round() * cents;
  });
  final dueMilli = taxMilli - (materials + investments) * 10000;
  final payable = dueMilli.sign * ((dueMilli.abs() + 5000) ~/ 10000);
  final rates = turnoverByRate.keys.toList()..sort((a, b) => b.compareTo(a));
  final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
  void amount(String name, int cents, {bool always = false}) {
    if (cents != 0 || always) b.element(name, nest: _francs(cents));
  }

  b.element(
    'VATDeclaration',
    namespaces: {
      'http://www.ech.ch/xmlns/eCH-0217/2': null,
      _ech0058: 'eCH-0058',
    },
    nest: () {
      b.element(
        'generalInformation',
        nest: () {
          b
            ..element('uid', nest: 'CHE${m.group(1)}')
            ..element('organisationName', nest: organisationName.trim())
            ..element('generationTime', nest: _dateTimeUtc(generatedAt))
            ..element('reportingPeriodFrom', nest: isoDay(declaration.periodStart))
            ..element('reportingPeriodTill', nest: isoDay(declaration.periodEnd))
            ..element('typeOfSubmission', nest: '1')
            ..element('formOfReporting', nest: onReceipts ? '2' : '1')
            ..element('businessReferenceId', nest: _reference50(declaration));
          b.element(
            'sendingApplication',
            nest: () {
              b
                ..element('manufacturer', namespace: _ech0058, nest: 'DesKilo')
                ..element('product', namespace: _ech0058, nest: 'DesKilo')
                ..element('productVersion', namespace: _ech0058, nest: '1.0');
            },
          );
        },
      );
      b.element(
        'turnoverComputation',
        nest: () {
          amount('totalConsideration', total, always: true);
          amount('suppliesToForeignCountries', toForeign);
          amount('suppliesAbroad', abroad);
          amount('suppliesExemptFromTax', exempt);
        },
      );
      b.element(
        'effectiveReportingMethod',
        nest: () {
          b.element('grossOrNet', nest: '1');
          for (final rate in rates) {
            b.element(
              'suppliesPerTaxRate',
              nest: () {
                b
                  ..element('taxRate', nest: rate.toStringAsFixed(2))
                  ..element('turnover', nest: _francs(turnoverByRate[rate]!));
              },
            );
          }
          amount('inputTaxMaterialAndServices', materials);
          amount('inputTaxInvestments', investments);
        },
      );
      b.element('payableTax', nest: _francs(payable));
    },
  );
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// The eCH-0058 namespace: the children of `sendingApplication` live in it.
const _ech0058 = 'http://www.ech.ch/xmlns/eCH-0058/5';

/// `2026-10-13T08:05:09`, in UTC, as the standard asks.
String _dateTimeUtc(DateTime at) {
  final u = at.toUtc();
  return '${isoDay(u)}T${hhmmss(u)}';
}

/// The file reference of the return, at most 50 characters.
String _reference50(VatDeclaration declaration) {
  final number = declaration.number.trim();
  final text = number.isNotEmpty
      ? number
      : 'MWST-${isoDay(declaration.periodStart)}';
  return text.length > 50 ? text.substring(0, 50) : text;
}


/// Francs with centimes and a dot, as the standard reads amounts: `-12.05`.
String _francs(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${twoDigits(abs % 100)}';
}
