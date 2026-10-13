// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — filing-ready files of a prepared VAT return, for the owner to
// hand to the channel that files it. The app transmits nothing: an
// ELSTER file goes to transmission software or a tax adviser (ERiC),
// an EDI-TVA file to the owner's EDI partner (partenaire EDI), and the
// owner records the receipt the authority gives back.
//
//  * DE — the UStVA as ELSTER XML (`Elster` / `Anmeldungssteuern art=
//    "UStVA"`): Jahr, Zeitraum (01–12 a month, 41–44 a quarter), the
//    Steuernummer and every Kennzahl the form filled, bases in whole
//    euros, tax amounts with cents, Kz 83 always.
//  * FR — the CA3 as an EDIFACT interchange (UNA/UNB/UNH … UNT/UNZ,
//    message INFENT, syntax UNOC 3): the declarant (SIREN, name,
//    address), the period, and one LIN per CA3 line with its code and
//    its amounts in whole euros — MOA 125 the base, MOA 124 the tax.
//
//  * CH — the MWST-Abrechnung as eCH-0217 XML (#2360), the standard the ESTV
//    ePortal takes for upload, validated against its published XSD. The
//    upload itself needs an ePortal account of the owner and is not done
//    here; the file is the digital link.
//  * GB — Making Tax Digital for VAT through bridging software (#2359):
//    one CSV row of the nine boxes under HMRC's own field names (boxes
//    1–5 in pounds and pence, 6–9 in whole pounds). The file IS the
//    digital link: the bridging software imports it as it is and a person
//    never retypes a figure. Submitting through HMRC's API, with its
//    fraud-prevention headers, needs a developer account and is not done
//    here.
//
// Both read the boxes `vatFormBoxes` fills, so the file and the PDF can
// never disagree.
import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import '../../../core/time/date_text.dart';
import 'vat_declaration.dart';
import 'vat_filing_ech0217.dart';

/// Why a filing file cannot be written for a declaration.
enum VatFilingFileProblem {
  /// A UStVA covers a calendar month or quarter.
  period,

  /// The declarant's tax number (Steuernummer, SIREN) is missing.
  taxNumber,

  /// A UK return names the VAT registration number (nine digits).
  vatNumber,

  /// A Swiss return names the UID (CHE-123.456.789 and its check digit).
  uid,
}

class VatFilingFileException implements Exception {
  const VatFilingFileException(this.problem);
  final VatFilingFileProblem problem;

  @override
  String toString() => 'VatFilingFileException: ${problem.name}';
}

/// Who files: the space as its settings describe it.
class VatFilingParty {
  const VatFilingParty({
    required this.countryCode,
    required this.name,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.vatId,
    required this.legalId,
    this.onReceipts = false,
  });

  final String countryCode;
  final String name;
  final String street;
  final String postalCode;
  final String city;
  final String vatId;

  /// The registration number (SIRET, Handelsregister …).
  final String legalId;

  /// Whether the space accounts for VAT on the consideration received (a
  /// Swiss return says `formOfReporting` 2), not on the invoice.
  final bool onReceipts;

  /// The country whose file exists here: `DE`, `FR`, else null.
  String? get fileCountry => switch (countryCode.trim().toUpperCase()) {
    'DE' => 'DE',
    'FR' => 'FR',
    'GB' || 'UK' => 'GB',
    'CH' => 'CH',
    _ => null,
  };
}

/// The filing file of [declaration] for [party]: its name and its text.
/// [taxNumber] is the Steuernummer a German file names. Throws
/// [VatFilingFileException] when the period or the number does not fit,
/// and [UnsupportedError] for a country without a file.
({String fileName, String text}) vatFilingFile({
  required VatDeclaration declaration,
  required VatFilingParty party,
  required DateTime now,
  String taxNumber = '',
}) {
  final start = isoDay(declaration.periodStart);
  return switch (party.fileCountry) {
    'DE' => (
      fileName: 'ustva-$start.xml',
      text: elsterUstvaXml(
        declaration: declaration,
        taxNumber: taxNumber,
        name: party.name,
        street: party.street,
        postalCode: party.postalCode,
        city: party.city,
        createdOn: now,
      ),
    ),
    'FR' => (
      fileName: 'edi-tva-ca3-$start.edi',
      text: ediTvaCa3(
        declaration: declaration,
        siren: frenchSiren(legalId: party.legalId, vatId: party.vatId),
        vatId: party.vatId,
        name: party.name,
        street: party.street,
        postalCode: party.postalCode,
        city: party.city,
        createdAt: now,
      ),
    ),
    'GB' => (
      fileName: 'mtd-vat-return-$start.csv',
      text: mtdBridgingCsv(declaration: declaration, vatId: party.vatId),
    ),
    'CH' => (
      fileName: 'mwst-abrechnung-$start.xml',
      text: ech0217Xml(
        declaration: declaration,
        uid: party.vatId,
        organisationName: party.name,
        onReceipts: party.onReceipts,
        generatedAt: now,
      ),
    ),
    _ => throw UnsupportedError('no filing file for ${party.countryCode}'),
  };
}

/// The HMRC field names of the nine boxes, in the order of the form.
const _mtdFields = [
  'vatDueSales',
  'vatDueAcquisitions',
  'totalVatDue',
  'vatReclaimedCurrPeriod',
  'netVatDue',
  'totalValueSalesExVAT',
  'totalValuePurchasesExVAT',
  'totalValueGoodsSuppliedExVAT',
  'totalAcquisitionsExVAT',
];

/// The nine boxes of the UK return as one CSV row for MTD bridging
/// software (#2359). [vatId] is the registration number; the row names its
/// nine digits as `vrn`.
@visibleForTesting
String mtdBridgingCsv({
  required VatDeclaration declaration,
  required String vatId,
}) {
  final upper = vatId.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final digits = _digits(upper.startsWith('GB') || upper.startsWith('XI') ? upper.substring(2) : upper);
  if (digits.length < 9) {
    throw const VatFilingFileException(VatFilingFileProblem.vatNumber);
  }
  final values = <String, String>{};
  for (final box in vatFormBoxes(
    'GB',
    declaration.lines,
    periodEnd: declaration.periodEnd,
  )) {
    if (box.hasBase && box.baseKey.isNotEmpty) {
      values[box.baseKey] = (box.netCents ~/ 100).toString();
    }
    if (box.hasTax && box.taxKey.isNotEmpty) {
      values[box.taxKey] = _euros(box.vatCents);
    }
  }
  final header = ['vrn', 'periodStart', 'periodEnd', ..._mtdFields];
  final row = [
    digits.substring(0, 9),
    isoDay(declaration.periodStart),
    isoDay(declaration.periodEnd),
    for (final field in _mtdFields) values[field] ?? '0',
  ];
  return '${header.join(',')}\r\n${row.join(',')}\r\n';
}

/// The SIREN of a French seller: the registration number's first nine
/// digits, else the nine after the key of an FR VAT id.
@visibleForTesting
String frenchSiren({required String legalId, required String vatId}) {
  final legal = _digits(legalId);
  if (legal.length >= 9) return legal.substring(0, 9);
  final vat = _digits(vatId);
  return vat.length == 11 ? vat.substring(2) : '';
}

/// The ELSTER Zeitraum of [declaration]: `01`..`12` for a month, `41`..`44`
/// for a quarter; anything else is not a UStVA period.
String _elsterPeriod(VatDeclaration declaration) {
  final start = declaration.periodStart;
  final end = declaration.periodEnd;
  final months = (end.year - start.year) * 12 + end.month - start.month + 1;
  if (start.day != 1 || end != DateTime(end.year, end.month + 1, 0)) {
    throw const VatFilingFileException(VatFilingFileProblem.period);
  }
  if (months == 1) return twoDigits(start.month);
  if (months == 3 && (start.month - 1) % 3 == 0) {
    return '${41 + (start.month - 1) ~/ 3}';
  }
  // The annual return (Umsatzsteuererklärung) is another form.
  throw const VatFilingFileException(VatFilingFileProblem.period);
}

/// The UStVA of [declaration] as ELSTER XML.
@visibleForTesting
String elsterUstvaXml({
  required VatDeclaration declaration,
  required String taxNumber,
  required String name,
  required String street,
  required String postalCode,
  required String city,
  required DateTime createdOn,
}) {
  final zeitraum = _elsterPeriod(declaration);
  if (_digits(taxNumber).length < 10) {
    throw const VatFilingFileException(VatFilingFileProblem.taxNumber);
  }
  final kz = <String, String>{};
  for (final box in vatFormBoxes(
    'DE',
    declaration.lines,
    periodEnd: declaration.periodEnd,
  )) {
    if (box.hasBase && box.baseKey.isNotEmpty) {
      kz[box.baseKey] = (box.netCents ~/ 100).toString();
    }
    if (box.hasTax && box.taxKey.isNotEmpty) {
      kz[box.taxKey] = _euros(box.vatCents);
    }
  }
  final keys = kz.keys.toList()
    ..sort(
      (a, b) => int.parse(a.substring(2)).compareTo(int.parse(b.substring(2))),
    );
  final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(
    'Elster',
    namespaces: {'http://www.elster.de/elsterxml/schema/v11': null},
    nest: () {
      b.element(
        'TransferHeader',
        attributes: {'version': '11'},
        nest: () {
          b
            ..element('Verfahren', nest: 'ElsterAnmeldung')
            ..element('DatenArt', nest: 'UStVA')
            ..element('Vorgang', nest: 'send-Auth');
        },
      );
      b.element(
        'DatenTeil',
        nest: () {
          b.element(
            'Nutzdatenblock',
            nest: () {
              b.element(
                'NutzdatenHeader',
                attributes: {'version': '11'},
                nest: () {
                  b.element('NutzdatenTicket', nest: '1');
                },
              );
              b.element(
                'Nutzdaten',
                nest: () {
                  b.element(
                    'Anmeldungssteuern',
                    attributes: {
                      'art': 'UStVA',
                      'version': '${declaration.periodEnd.year}_01',
                    },
                    nest: () {
                      b.element(
                        'DatenLieferant',
                        nest: () {
                          b
                            ..element('Name', nest: name)
                            ..element('Strasse', nest: street)
                            ..element('PLZ', nest: postalCode)
                            ..element('Ort', nest: city);
                        },
                      );
                      b.element('Erstellungsdatum', nest: ymd(createdOn));
                      b.element(
                        'Steuerfall',
                        nest: () {
                          b.element(
                            'Umsatzsteuervoranmeldung',
                            nest: () {
                              b
                                ..element(
                                  'Jahr',
                                  nest: '${declaration.periodStart.year}',
                                )
                                ..element('Zeitraum', nest: zeitraum)
                                ..element(
                                  'Steuernummer',
                                  nest: _digits(taxNumber),
                                );
                              for (final k in keys) {
                                b.element(k, nest: kz[k]);
                              }
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// The CA3 of [declaration] as an EDIFACT interchange for an EDI partner.
@visibleForTesting
String ediTvaCa3({
  required VatDeclaration declaration,
  required String siren,
  required String vatId,
  required String name,
  required String street,
  required String postalCode,
  required String city,
  required DateTime createdAt,
}) {
  final id = _digits(siren);
  if (id.length < 9) {
    throw const VatFilingFileException(VatFilingFileProblem.taxNumber);
  }
  final declarant = id.substring(0, 9);
  final reference = _reference(declaration);
  final segments = <String>[
    _seg(['UNH', '1', 'INFENT:D:00A:UN:TVA']),
    _seg(['BGM', '3310CA3::DGF', reference, '9']),
    _seg(['DTM', '137:${ymd(createdAt)}:102']),
    _seg(['DTM', '194:${ymd(declaration.periodStart)}:102']),
    _seg(['DTM', '206:${ymd(declaration.periodEnd)}:102']),
    _seg([
      'NAD',
      'FR',
      '$declarant::107',
      '',
      _escape(name),
      _escape(street),
      _escape(city),
      '',
      _escape(postalCode),
      'FR',
    ]),
    if (vatId.trim().isNotEmpty) _seg(['RFF', 'VA:${_escape(vatId.trim())}']),
  ];
  var n = 0;
  for (final box in vatFormBoxes(
    'FR',
    declaration.lines,
    periodEnd: declaration.periodEnd,
  )) {
    final key = box.baseKey.isNotEmpty ? box.baseKey : box.taxKey;
    if (key.isEmpty) continue;
    n++;
    segments.add(_seg(['LIN', '$n', '', '${_escape(box.code)}:$key:ZZ']));
    if (box.hasBase) {
      segments.add(_seg(['MOA', '125:${box.netCents ~/ 100}']));
    }
    if (box.hasTax) {
      segments.add(_seg(['MOA', '124:${box.vatCents ~/ 100}']));
    }
  }
  segments.add(_seg(['UNT', '${segments.length + 1}', '1']));
  final stamp = createdAt.toUtc();
  return [
    "UNA:+.? '",
    _seg([
      'UNB',
      'UNOC:3',
      '$declarant:ZZ',
      'DGFIP:ZZ',
      '${ymd(stamp).substring(2)}:${hhmm(stamp, separator: '')}',
      reference,
    ]),
    ...segments,
    _seg(['UNZ', '1', reference]),
  ].join('\n');
}

/// A segment: its elements joined by `+`, closed by `'`.
String _seg(List<String> elements) {
  var end = elements.length;
  while (end > 1 && elements[end - 1].isEmpty) {
    end--;
  }
  return "${elements.sublist(0, end).join('+')}'";
}

/// EDIFACT release: `?` before each of `? + : '`.
String _escape(String text) =>
    text.replaceAllMapped(RegExp(r"[?+:']"), (m) => '?${m[0]}');

/// The interchange reference: the DECL- number, else the period.
String _reference(VatDeclaration declaration) {
  final number = declaration.number.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  final ref = number.isNotEmpty ? number : 'CA3${ymd(declaration.periodStart)}';
  return ref.length > 14 ? ref.substring(ref.length - 14) : ref;
}

String _digits(String text) => text.replaceAll(RegExp('[^0-9]'), '');

/// Euros with cents and a dot, as ELSTER reads amounts: `-12.05`.
String _euros(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${twoDigits(abs % 100)}';
}
