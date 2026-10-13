// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — the Swiss QR-bill (SIX "Swiss Implementation Guidelines QR-bill",
// data structure version 2.0, coding type 1). The payload is the text the
// QR code carries; the payment part and the receipt around it are drawn by
// `swiss_qr_bill_pdf.dart`.
//
//  * Creditor account: a CH or LI IBAN. A QR-IBAN (institution identifier
//    30000–31999 at positions 5–9) takes a QRR reference (26 digits and a
//    modulus-10 check digit); an ordinary IBAN takes an ISO 11649 creditor
//    reference (SCOR, `RF` + two check digits + up to 21 characters) or
//    none (NON). The two never mix.
//  * Addresses are structured (type `S`): name, street, house number,
//    postal code, town, country. The combined type `K` is being retired.
//  * Currency CHF or EUR; amount with two decimals, at most 999999999.99.
//  * Text is limited to the Latin character set of the guidelines.
//
// A QR-bill validator (SIX publishes one) has the last word; the rules are
// those of the guidelines, applied here before a document is drawn.
import 'package:meta/meta.dart';

/// A party of the bill: structured address.
@immutable
class SwissQrAddress {
  const SwissQrAddress({
    required this.name,
    this.street = '',
    this.houseNumber = '',
    required this.postalCode,
    required this.city,
    this.country = 'CH',
  });

  final String name;
  final String street;
  final String houseNumber;
  final String postalCode;
  final String city;
  final String country;

  /// A free street line split into street and house number
  /// ("Bahnhofstrasse 12a" → "Bahnhofstrasse", "12a").
  factory SwissQrAddress.fromLines({
    required String name,
    required String streetLine,
    required String postalCode,
    required String city,
    String country = 'CH',
  }) {
    final m = RegExp(r'^(.*?)[\s,]+(\d+[A-Za-z]?(?:[-/]\d+[A-Za-z]?)?)$')
        .firstMatch(streetLine.trim());
    return SwissQrAddress(
      name: name,
      street: m == null ? streetLine.trim() : m.group(1)!.trim(),
      houseNumber: m?.group(2) ?? '',
      postalCode: postalCode,
      city: city,
      country: country,
    );
  }

  /// Why this address cannot be on a bill; empty when it can.
  List<String> get problems => [
    if (clean(name).isEmpty || clean(name).length > 70) 'name',
    if (clean(street).length > 70) 'street',
    if (clean(houseNumber).length > 16) 'houseNumber',
    if (clean(postalCode).isEmpty || clean(postalCode).length > 16)
      'postalCode',
    if (clean(city).isEmpty || clean(city).length > 35) 'city',
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country.toUpperCase())) 'country',
  ];

  List<String> get fields => [
    'S',
    clean(name),
    clean(street),
    clean(houseNumber),
    clean(postalCode),
    clean(city),
    country.toUpperCase(),
  ];
}

/// The text of a field as the guidelines allow it: the Latin character set
/// (basic Latin, Latin-1 supplement and Latin Extended-A), no line breaks.
/// Anything else becomes a full stop, as the guidelines advise.
String clean(String text) {
  final out = StringBuffer();
  for (final r in text.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim().runes) {
    final ok = (r >= 0x20 && r <= 0x7E) || (r >= 0xA0 && r <= 0x17F);
    out.writeCharCode(ok ? r : 0x2E);
  }
  return out.toString();
}

/// An IBAN's checksum (ISO 13616, modulus 97).
bool ibanChecksumOk(String iban) {
  final s = iban.replaceAll(' ', '').toUpperCase();
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(s)) return false;
  final rearranged = s.substring(4) + s.substring(0, 4);
  var rest = 0;
  for (final c in rearranged.codeUnits) {
    final v = c >= 65 ? c - 55 : c - 48;
    rest = (v > 9 ? rest * 100 + v : rest * 10 + v) % 97;
  }
  return rest == 1;
}

/// Whether [iban] is a QR-IBAN: a Swiss or Liechtenstein IBAN whose
/// institution identifier (positions 5–9) lies in 30000–31999.
bool isQrIban(String iban) {
  final s = iban.replaceAll(' ', '').toUpperCase();
  if (s.length != 21 || !(s.startsWith('CH') || s.startsWith('LI'))) {
    return false;
  }
  final iid = int.tryParse(s.substring(4, 9));
  return iid != null && iid >= 30000 && iid <= 31999;
}

/// A CH or LI IBAN with a valid checksum (21 characters).
bool isSwissIban(String iban) {
  final s = iban.replaceAll(' ', '').toUpperCase();
  return s.length == 21 &&
      (s.startsWith('CH') || s.startsWith('LI')) &&
      ibanChecksumOk(s);
}

const _qrrTable = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5];

/// The recursive modulus-10 check digit of [digits] (the QRR reference's
/// 27th digit).
int qrrCheckDigit(String digits) {
  var carry = 0;
  for (final c in digits.codeUnits) {
    carry = _qrrTable[(carry + c - 48) % 10];
  }
  return (10 - carry) % 10;
}

/// The QRR reference of [number]: its digits, left-padded with zeros to
/// 26, plus the check digit; null when [number] has no digit or more than
/// 26.
String? qrrReferenceOf(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || digits.length > 26) return null;
  final body = digits.padLeft(26, '0');
  return '$body${qrrCheckDigit(body)}';
}

bool isValidQrr(String reference) =>
    RegExp(r'^\d{27}$').hasMatch(reference) &&
    qrrCheckDigit(reference.substring(0, 26)) ==
        int.parse(reference.substring(26));

/// The ISO 11649 creditor reference of [text] (letters and digits only,
/// at most 21 of them); null when nothing usable is left.
String? scorReferenceOf(String text) {
  final body = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (body.isEmpty || body.length > 21) return null;
  final n = _mod97('${body}RF00');
  final check = (98 - n).toString().padLeft(2, '0');
  return 'RF$check$body';
}

bool isValidScor(String reference) {
  final s = reference.replaceAll(' ', '').toUpperCase();
  if (!RegExp(r'^RF\d{2}[A-Z0-9]{1,21}$').hasMatch(s)) return false;
  return _mod97(s.substring(4) + s.substring(0, 4)) == 1;
}

int _mod97(String alnum) {
  var rest = 0;
  for (final c in alnum.codeUnits) {
    final v = c >= 65 ? c - 55 : c - 48;
    rest = (v > 9 ? rest * 100 + v : rest * 10 + v) % 97;
  }
  return rest;
}

/// The QR-bill of one invoice.
@immutable
class SwissQrBill {
  const SwissQrBill({
    required this.iban,
    required this.creditor,
    required this.amountCents,
    required this.currency,
    this.debtor,
    this.referenceType = 'NON',
    this.reference = '',
    this.additionalInfo = '',
  });

  /// The creditor's account, spaces ignored.
  final String iban;
  final SwissQrAddress creditor;
  final int amountCents;
  final String currency;
  final SwissQrAddress? debtor;

  /// `QRR`, `SCOR` or `NON`.
  final String referenceType;
  final String reference;
  final String additionalInfo;

  String get account => iban.replaceAll(' ', '').toUpperCase();

  /// The amount as the guidelines write it: `1949.75`.
  String get amountText =>
      '${amountCents ~/ 100}.${(amountCents % 100).toString().padLeft(2, '0')}';

  /// Everything that stops this bill being a valid one; empty when valid.
  List<String> get problems => [
    if (!isSwissIban(account)) 'iban',
    if (isQrIban(account) && referenceType != 'QRR') 'qrIbanNeedsQrr',
    if (!isQrIban(account) && referenceType == 'QRR') 'qrrNeedsQrIban',
    if (referenceType == 'QRR' && !isValidQrr(reference)) 'reference',
    if (referenceType == 'SCOR' && !isValidScor(reference)) 'reference',
    if (referenceType == 'NON' && reference.isNotEmpty) 'reference',
    if (!const {'QRR', 'SCOR', 'NON'}.contains(referenceType)) 'referenceType',
    if (currency != 'CHF' && currency != 'EUR') 'currency',
    if (amountCents <= 0 || amountCents > 99999999999) 'amount',
    if (clean(additionalInfo).length > 140) 'additionalInfo',
    ...creditor.problems.map((p) => 'creditor.$p'),
    if (debtor != null) ...debtor!.problems.map((p) => 'debtor.$p'),
  ];

  /// The text of the QR code: header, account, creditor, the unused
  /// ultimate creditor, amount, currency, debtor, reference, additional
  /// information and the `EPD` trailer, one value per line (CR LF).
  String get payload {
    final ref = referenceType == 'NON' ? '' : reference.replaceAll(' ', '');
    return [
      'SPC',
      '0200',
      '1',
      account,
      ...creditor.fields,
      ...List.filled(7, ''),
      amountText,
      currency,
      ...(debtor?.fields ?? List.filled(7, '')),
      referenceType,
      ref,
      clean(additionalInfo),
      'EPD',
    ].join('\r\n');
  }

  /// The IBAN in groups of four: `CH44 3199 9123 0008 8901 2`.
  String get accountGrouped => _groups(account, 4);

  /// The reference as printed: a QRR in `21 00000 00003 13947 14300 09017`,
  /// a SCOR in groups of four.
  String get referenceGrouped {
    if (referenceType == 'QRR') {
      final r = reference;
      final head = r.substring(0, 2);
      final rest = r.substring(2);
      return '$head ${_groups(rest, 5)}';
    }
    return referenceType == 'SCOR' ? _groups(reference, 4) : '';
  }

  /// The amount as printed: `1 949.75`.
  String get amountGrouped {
    final whole = (amountCents ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(' ');
      buf.write(whole[i]);
    }
    return '$buf.${(amountCents % 100).toString().padLeft(2, '0')}';
  }

  static String _groups(String text, int size) {
    final s = text.replaceAll(' ', '');
    final buf = <String>[];
    for (var i = 0; i < s.length; i += size) {
      buf.add(s.substring(i, i + size > s.length ? s.length : i + size));
    }
    return buf.join(' ');
  }

  /// The bill for an invoice of a Swiss seller, or null where none applies
  /// (no Swiss account, a credit note, a currency the bill does not carry,
  /// an address the guidelines refuse). A QR-IBAN takes a QRR reference
  /// built from [invoiceNumber]; an ordinary IBAN takes the SCOR.
  static SwissQrBill? forInvoice({
    required String iban,
    required String qrIban,
    required SwissQrAddress creditor,
    required SwissQrAddress? debtor,
    required int totalCents,
    required String currency,
    required String invoiceNumber,
    String additionalInfo = '',
  }) {
    final qr = qrIban.replaceAll(' ', '');
    final plain = iban.replaceAll(' ', '');
    final qrRef = qr.isEmpty ? null : qrrReferenceOf(invoiceNumber);
    SwissQrBill bill;
    if (qrRef != null && isQrIban(qr)) {
      bill = _make(
        qr,
        'QRR',
        qrRef,
        creditor,
        debtor,
        totalCents,
        currency,
        additionalInfo,
      );
    } else if (plain.isNotEmpty && !isQrIban(plain)) {
      final scor = scorReferenceOf(invoiceNumber);
      bill = _make(
        plain,
        scor == null ? 'NON' : 'SCOR',
        scor ?? '',
        creditor,
        debtor,
        totalCents,
        currency,
        additionalInfo,
      );
    } else {
      return null;
    }
    // A debtor the guidelines refuse is left out (the payer writes it in);
    // the creditor, the account and the amount cannot be.
    if (bill.debtor != null && bill.debtor!.problems.isNotEmpty) {
      bill = _make(
        bill.account,
        bill.referenceType,
        bill.reference,
        creditor,
        null,
        totalCents,
        currency,
        additionalInfo,
      );
    }
    return bill.problems.isEmpty ? bill : null;
  }

  static SwissQrBill _make(
    String account,
    String type,
    String reference,
    SwissQrAddress creditor,
    SwissQrAddress? debtor,
    int totalCents,
    String currency,
    String info,
  ) => SwissQrBill(
    iban: account,
    creditor: creditor,
    amountCents: totalCents,
    currency: currency,
    debtor: debtor,
    referenceType: type,
    reference: reference,
    additionalInfo: info,
  );
}
