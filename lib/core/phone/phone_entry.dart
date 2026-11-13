// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3650 — a phone number has two forms that are never confused: what the
// person typed, kept as it is, and the validated international form
// (E.164), present only when parsing succeeded for an explicit country. A
// national number needs that country; a number typed with + or 00 carries
// its own. An extension is kept apart. Validation says the number is
// possible for its country, not that it belongs to anyone or reaches
// WhatsApp.
//
// The links for messaging are built here and nowhere else
// (test/lint/phone_links_test.dart), from the validated form only: a number
// that is not validated opens nothing. Parsing uses phone_numbers_parser,
// pure Dart with its own metadata (MIT).
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as parser;

/// Why a typed number has no validated form.
enum PhoneProblem {
  /// A national number with no country to read it in.
  noCountry,

  /// Something other than digits, spaces, separators and an extension.
  notANumber,

  /// Digits that cannot be a number of that country.
  notValidForCountry,
}

/// A number as typed, and its validated international form.
class PhoneEntry {
  const PhoneEntry({
    required this.typed,
    this.e164,
    this.extension = '',
    this.country,
    this.problem,
  });

  /// Nothing typed.
  static const empty = PhoneEntry(typed: '');

  /// What the person typed, as they typed it.
  final String typed;

  /// `+<country code><national number>`; null when not validated.
  final String? e164;

  /// The extension, apart from the number ('' for none).
  final String extension;

  /// The ISO 3166 alpha-2 country of the validated number.
  final String? country;

  /// Why [e164] is null; null when validated or empty.
  final PhoneProblem? problem;

  bool get isEmpty => typed.trim().isEmpty;
  bool get isValidated => e164 != null;
}

final _extension = RegExp(
  r'\s*(?:;\s*ext\s*=|ext\.?|extension|x|#|poste|durchwahl|interno|int\.)\s*(\d{1,7})\s*$',
  caseSensitive: false,
);
final _allowed = RegExp(r'^[\d\s+().\-/]*$');

/// Parses [typed]: a number starting with + or 00 is read on its own; a
/// national number is read for [country] (ISO alpha-2), which must be given
/// — it is never guessed. Empty input is [PhoneEntry.empty].
PhoneEntry parsePhone(String typed, {String? country}) {
  final raw = typed.trim();
  if (raw.isEmpty) return PhoneEntry.empty;
  final ext = _extension.firstMatch(raw);
  final number = ext == null ? raw : raw.substring(0, ext.start).trim();
  final extension = ext?.group(1) ?? '';
  PhoneEntry refused(PhoneProblem p) =>
      PhoneEntry(typed: typed, extension: extension, problem: p);
  if (number.isEmpty || !_allowed.hasMatch(number)) {
    return refused(PhoneProblem.notANumber);
  }
  final international = number.startsWith('+') || number.startsWith('00');
  final iso = _isoOf(country);
  if (!international && iso == null) return refused(PhoneProblem.noCountry);
  try {
    final parsed = parser.PhoneNumber.parse(
      international && number.startsWith('00')
          ? '+${number.substring(2)}'
          : number,
      callerCountry: international ? null : iso,
    );
    if (!parsed.isValid()) return refused(PhoneProblem.notValidForCountry);
    return PhoneEntry(
      typed: typed,
      e164: parsed.international,
      extension: extension,
      country: parsed.isoCode.name,
    );
  } on parser.PhoneNumberException {
    return refused(PhoneProblem.notValidForCountry);
  }
}

parser.IsoCode? _isoOf(String? country) {
  final code = country?.trim().toUpperCase() ?? '';
  for (final iso in parser.IsoCode.values) {
    if (iso.name == code) return iso;
  }
  return null;
}

/// The calling code of [country] ("33" for FR), or '' for a country the
/// metadata does not know.
String callingCodeOf(String country) {
  final iso = _isoOf(country);
  return iso == null
      ? ''
      : parser.PhoneNumber(isoCode: iso, nsn: '').countryCode;
}

/// A validated number in its international spelling ("+33 6 12 34 56 78"),
/// which reads the same for every reader; the typed form for one that is
/// not validated. An extension follows.
String phoneDisplay(PhoneEntry entry) {
  final e164 = entry.e164;
  final iso = _isoOf(entry.country);
  if (e164 == null || iso == null) return entry.typed.trim();
  final number = parser.PhoneNumber(
    isoCode: iso,
    nsn: e164.substring(1 + callingCodeOf(iso.name).length),
  );
  final written =
      '+${number.countryCode} ${number.formatNsn(format: parser.NsnFormat.international)}';
  return entry.extension.isEmpty ? written : '$written ext. ${entry.extension}';
}

// ── the links ───────────────────────────────────────────────────────────

/// A WhatsApp chat with [entry], carrying [text] when given; null when the
/// number is not validated or has an extension (WhatsApp cannot carry one).
Uri? whatsappLink(PhoneEntry entry, {String? text}) {
  final e164 = entry.e164;
  if (e164 == null || entry.extension.isNotEmpty) return null;
  return Uri.https(
    'wa.me',
    '/${e164.substring(1)}',
    text == null ? null : {'text': text},
  );
}

/// [text] to send by WhatsApp to a contact the person picks there.
Uri whatsappShare(String text) => Uri.https('wa.me', '/', {'text': text});

/// A text message to [entry] with [body]; null when the number is not
/// validated or has an extension.
Uri? smsLink(PhoneEntry entry, {String? body}) {
  final e164 = entry.e164;
  if (e164 == null || entry.extension.isNotEmpty) return null;
  return Uri(
    scheme: 'sms',
    path: e164,
    queryParameters: body == null ? null : {'body': body},
  );
}

/// A text message with [body] to a contact the person picks.
Uri smsShare(String body) =>
    Uri(scheme: 'sms', path: '', queryParameters: {'body': body});
