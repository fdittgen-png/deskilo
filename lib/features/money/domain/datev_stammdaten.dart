// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The DATEV Debitoren/Kreditoren-Stammdaten (EXTF format category 16,
// version 5) written beside the Buchungsstapel: the name, address and VAT id
// of every Debitor the bookings use, so the Personenkonten arrive named.
//
// The file carries DATEV's first 35 columns, the ones DesKilo knows; the
// format reads by column position and leaves the later ones empty. Payment
// terms are not written: DATEV's Zahlungsbedingung is a key into the
// accountant's own terms, which DesKilo does not hold.
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'datev.dart';
import 'datev_fields.dart';
import 'invoice.dart';

/// The Stammdaten file name; DATEV keys on the header, not the name.
const String datevStammdatenFileName = 'EXTF_Debitoren_Kreditoren.csv';

/// The header of the Stammdaten, as the Buchungsstapel's but for category
/// 16 and without a period.
typedef DatevStammdatenHeader = ({
  DateTime generatedAt,
  String consultantNumber,
  String clientNumber,
  DateTime fiscalYearStart,
  int accountLength,
  String skr,
});

/// The column line: DATEV's fields 1 to 35 of the Debitoren/Kreditoren.
const List<String> _columns = [
  'Konto',
  'Name (Adressatentyp Unternehmen)',
  'Unternehmensgegenstand',
  'Name (Adressatentyp natürl. Person)',
  'Vorname (Adressatentyp natürl. Person)',
  'Name (Adressatentyp keine Angabe)',
  'Adressatentyp',
  'Kurzbezeichnung',
  'EU-Land',
  'EU-UStID',
  'Anrede',
  'Titel/Akad. Grad',
  'Adelstitel',
  'Namensvorsatz',
  'Adressart',
  'Straße',
  'Postfach',
  'Postleitzahl',
  'Ort',
  'Land',
  'Versandzusatz',
  'Adresszusatz',
  'Abweichende Anrede',
  'Abw. Zustellbezeichnung 1',
  'Abw. Zustellbezeichnung 2',
  'Kennz. Korrespondenzadresse',
  'Adresse Gültig von',
  'Adresse Gültig bis',
  'Telefon',
  'Bemerkung (Telefon)',
  'Telefon GL',
  'Bemerkung (Telefon GL)',
  'E-Mail',
  'Bemerkung (E-Mail)',
  'Internet',
];

/// The fixed field lengths of the Stammdaten this file writes.
abstract final class _Lengths {
  static const name = 50;
  static const shortName = 15;
  static const vatId = 13;
  static const street = 36;
  static const postalCode = 10;
  static const city = 30;
  static const phone = 60;
  static const email = 60;
  static const country = 2;
}

/// DATEV's Adressatentyp: 0 none given, 2 a company. A private member's
/// one-field name is not split into first and family name by guessing.
const String _noType = '0';
const String _company = '2';

String _q(String text, int max) =>
    csvCell(datevClip(text, max), dialect: CsvDialect.datev, quoteEmpty: true);

/// The Stammdaten of [parties] (party by Debitor), with the BOM: one row per
/// Debitor, in account order.
String buildDatevStammdaten(
  Map<String, InvoiceParty> parties,
  DatevStammdatenHeader header,
) {
  final stamp =
      '${ymd(header.generatedAt)}${hhmmss(header.generatedAt, separator: '')}000';
  final head = [
    '"EXTF"',
    '700',
    '16',
    '"Debitoren/Kreditoren"',
    '5',
    stamp,
    '',
    '""',
    '""',
    '',
    header.consultantNumber,
    header.clientNumber,
    ymd(header.fiscalYearStart),
    '${header.accountLength}',
    '',
    '',
    '""',
    '""',
    '',
    '',
    '',
    '""',
    '',
    '',
    '',
    '',
    header.skr,
    '',
    '',
    '',
    '',
  ].join(';');
  final rows = [
    for (final account in parties.keys.toList()..sort())
      _row(account, parties[account]!),
  ];
  return '$datevBom$head\r\n${_columns.join(';')}\r\n'
      '${rows.join('\r\n')}\r\n';
}

String _row(String account, InvoiceParty p) {
  final fields = List<String>.filled(_columns.length, '');
  final company = p.company.isNotEmpty;
  fields[0] = account;
  if (company) {
    fields[1] = _q(p.company, _Lengths.name);
  } else {
    fields[5] = _q(p.name, _Lengths.name);
  }
  fields[6] = company ? _company : _noType;
  fields[7] = _q(p.memberNumber, _Lengths.shortName);
  final vat = p.vatId.replaceAll(' ', '');
  final prefix = RegExp('^[A-Z]{2}').firstMatch(vat)?.group(0);
  if (prefix != null) {
    fields[8] = _q(prefix, _Lengths.country);
    fields[9] = _q(vat.substring(prefix.length), _Lengths.vatId);
  }
  fields[15] = _q(p.street, _Lengths.street);
  fields[17] = _q(p.postalCode, _Lengths.postalCode);
  fields[18] = _q(p.city, _Lengths.city);
  fields[19] = _q(p.country, _Lengths.country);
  fields[28] = _q(p.phone, _Lengths.phone);
  fields[32] = _q(p.email, _Lengths.email);
  return fields.join(';');
}
