// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Swiss VAT return as eCH-0217 version 2.0 XML. Moved here unchanged from
// the application (#3333): the lines of the context carry what the standard's
// turnover computation needs (rate, category, direction, opted supplies).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';
import 'package:xml/xml.dart';

/// Why the file cannot be written: the stable code the host words.
class Ech0217Refusal implements Exception {
  const Ech0217Refusal(this.code);

  final String code;

  @override
  String toString() => 'Ech0217Refusal: $code';
}

/// The category the server gives the acquisition tax on services bought from
/// abroad (CH 383).
const _acquisitionCategory = 'acquisition';

/// The nine digits of a valid Swiss UID, with or without dots and suffix, or
/// null: the checksum of the ninth digit is checked.
String? swissUidDigits(String uid) {
  final id = uid.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^CHE([1-9]\d{8})(MWST|TVA|IVA)?$').firstMatch(id);
  if (m == null || !isValidSwissUid(uid, requireSuffix: false)) return null;
  return m.group(1);
}

/// The MWST-Abrechnung as eCH-0217 version 2.0 (`VATDeclaration`), the XML
/// the ESTV ePortal takes for upload (#2360): the effective method, turnover
/// net (`grossOrNet` 1, the ESTV's recommendation), every amount to the
/// centime. `payableTax` is computed the way the standard prescribes (6.2.3):
/// the rate times the declared turnover, summed without rounding, less the
/// input tax, rounded to the centime at the end; the application checks it
/// (TVA-0006), so it can differ by a few centimes from the form's tax line
/// that adds the tax of each invoice.
///
/// The supplies opted for (205) are `opted`, the acquisition tax (383) one
/// `acquisitionTax` per rate, its tax owed in `payableTax` like a sale's.
/// Not mapped: 225, 235, 280, 382, 410, 415, 420 and the other flows of
/// funds (9xx). A first filing is declared (`typeOfSubmission` 1); a
/// rectification is another file. Validated against the published XSD
/// `eCH-0217-2-0-0.xsd` (tool/vat_filing/validate.sh).
String ech0217Xml(FilingContext context) {
  final uid = context.party.vatId;
  final organisationName = context.party.name;
  final onReceipts = context.party.onReceipts;
  final generatedAt = context.generatedAt;
  final m = swissUidDigits(uid);
  if (m == null) throw const Ech0217Refusal('uid');
  var total = 0, abroad = 0, toForeign = 0, exempt = 0, opted = 0;
  var materials = 0, investments = 0;
  final turnoverByRate = <double, int>{};
  final acquiredByRate = <double, int>{};
  for (final line in context.lines) {
    if (line.category == _acquisitionCategory) {
      acquiredByRate[line.percent] =
          (acquiredByRate[line.percent] ?? 0) + line.netCents;
      continue;
    }
    if (line.direction == 'input') {
      if (line.category == 'asset') {
        investments += line.vatCents;
      } else {
        materials += line.vatCents;
      }
      continue;
    }
    total += line.netCents;
    opted += line.optedNetCents;
    switch (line.category.isEmpty
        ? (line.percent > 0 ? 'S' : 'O')
        : line.category) {
      case 'Z' || 'G':
        toForeign += line.netCents;
      case 'AE' || 'O':
        abroad += line.netCents;
      case 'E':
        exempt += line.netCents;
      default:
        turnoverByRate[line.percent] =
            (turnoverByRate[line.percent] ?? 0) + line.netCents;
    }
  }
  // payableTax: the sum of rate x turnover in hundredths of a centime
  // (percent with two decimals x cents), sales and acquisitions alike, less
  // the input tax, half up.
  var taxMilli = 0;
  void addTax(double rate, int cents) {
    taxMilli += (rate * 100).round() * cents;
  }

  turnoverByRate.forEach(addTax);
  acquiredByRate.forEach(addTax);
  final dueMilli = taxMilli - (materials + investments) * 10000;
  final payable = dueMilli.sign * ((dueMilli.abs() + 5000) ~/ 10000);
  final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
  void amount(String name, int cents, {bool always = false}) {
    if (cents != 0 || always) b.element(name, nest: _francs(cents));
  }

  List<double> highestFirst(Map<double, int> byRate) =>
      byRate.keys.toList()..sort((x, y) => y.compareTo(x));
  void perRate(String name, Map<double, int> byRate) {
    for (final rate in highestFirst(byRate)) {
      b.element(
        name,
        nest: () {
          b
            ..element('taxRate', nest: rate.toStringAsFixed(2))
            ..element('turnover', nest: _francs(byRate[rate]!));
        },
      );
    }
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
            ..element('uid', nest: 'CHE$m')
            ..element('organisationName', nest: organisationName.trim())
            ..element('generationTime', nest: _dateTimeUtc(generatedAt))
            ..element(
              'reportingPeriodFrom',
              nest: ymd(context.periodStart, separator: '-'),
            )
            ..element(
              'reportingPeriodTill',
              nest: ymd(context.periodEnd, separator: '-'),
            )
            ..element('typeOfSubmission', nest: '1')
            ..element('formOfReporting', nest: onReceipts ? '2' : '1')
            ..element('businessReferenceId', nest: _reference50(context));
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
          amount('opted', opted);
          perRate('suppliesPerTaxRate', turnoverByRate);
          perRate('acquisitionTax', acquiredByRate);
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
  return '${ymd(u, separator: '-')}T${hhmmss(u)}';
}

/// The file reference of the return, at most 50 characters.
String _reference50(FilingContext context) {
  final number = context.number.trim();
  final text = number.isNotEmpty
      ? number
      : 'MWST-${ymd(context.periodStart, separator: '-')}';
  return text.length > 50 ? text.substring(0, 50) : text;
}

/// Francs with centimes and a dot, as the standard reads amounts: `-12.05`.
String _francs(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${twoDigits(abs % 100)}';
}
