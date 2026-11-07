// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The CA3 as an EDIFACT interchange for an EDI partner (EDI-TVA): the
// declarant (SIREN, name, address), the period, and one LIN per CA3 line with
// its code and its amounts in whole euros -- MOA 125 the base, MOA 124 the
// tax. Moved here unchanged from the application (#3332); the boxes are the
// ones the host filled from its tax reference.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

/// The SIREN of a French seller: the registration number's first nine digits,
/// else the nine after the key of an FR VAT id.
String frenchSiren({required String legalId, required String vatId}) {
  final legal = _digits(legalId);
  if (legal.length >= 9) return legal.substring(0, 9);
  final vat = _digits(vatId);
  return vat.length == 11 ? vat.substring(2) : '';
}

/// The CA3 of [context] as an EDIFACT interchange. [siren] is the declarant's
/// number (at least nine digits). Throws [FormatException] when it is shorter:
/// the contribution validates before it builds, so a caller of the contract
/// never sees it.
String ediTvaCa3(FilingContext context, {required String siren}) {
  final id = _digits(siren);
  if (id.length < 9) throw const FormatException('the declarant needs a SIREN');
  final declarant = id.substring(0, 9);
  final party = context.party;
  final createdAt = context.generatedAt;
  final reference = _reference(context);
  final segments = <String>[
    _seg(['UNH', '1', 'INFENT:D:00A:UN:TVA']),
    _seg(['BGM', '3310CA3::DGF', reference, '9']),
    _seg(['DTM', '137:${ymd(createdAt)}:102']),
    _seg(['DTM', '194:${ymd(context.periodStart)}:102']),
    _seg(['DTM', '206:${ymd(context.periodEnd)}:102']),
    _seg([
      'NAD',
      'FR',
      '$declarant::107',
      '',
      _escape(party.name),
      _escape(party.street),
      _escape(party.city),
      '',
      _escape(party.postalCode),
      'FR',
    ]),
    if (party.vatId.trim().isNotEmpty)
      _seg(['RFF', 'VA:${_escape(party.vatId.trim())}']),
  ];
  var n = 0;
  for (final box in context.boxes) {
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
String _reference(FilingContext context) {
  final number = context.number.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  final ref = number.isNotEmpty ? number : 'CA3${ymd(context.periodStart)}';
  return ref.length > 14 ? ref.substring(ref.length - 14) : ref;
}

String _digits(String text) => text.replaceAll(RegExp('[^0-9]'), '');
