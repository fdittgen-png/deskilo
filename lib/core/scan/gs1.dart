// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- what a camera reads off a product or a place label, before anything is resolved: a GTIN's check
// digit is validated (a misread is said, never sent to the server), and a GS1 element string (the text of a GS1
// DataMatrix or QR) is parsed for its GTIN (AI 01), lot (10), expiry (17) and serial (21). Pure: no Flutter widgets.
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Whether [code] is a GTIN (8, 12, 13 or 14 digits) whose last digit is the check digit of the others.
@visibleForTesting
bool gtinValid(String code) {
  if (!RegExp(r'^\d+$').hasMatch(code) || ![8, 12, 13, 14].contains(code.length)) return false;
  var sum = 0;
  for (var i = 0; i < code.length - 1; i++) {
    final digit = code.codeUnitAt(code.length - 2 - i) - 0x30;
    sum += digit * (i.isEven ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == code.codeUnitAt(code.length - 1) - 0x30;
}

/// What a GS1 element string carries; every part but the GTIN may be absent.
class Gs1 {
  const Gs1({required this.gtin, this.lot, this.expiry, this.serial});

  final String gtin;
  final String? lot;

  /// The expiry day as `YYYY-MM-DD` (an AI 17 day of `00` means the last day of its month).
  final String? expiry;
  final String? serial;
}

const _gs = '\u001d';

/// Parses [raw] as a GS1 element string, with or without parentheses and a symbology identifier (`]d2`, `]Q3`);
/// null when it carries no valid GTIN (a misread, or not a GS1 code at all).
@visibleForTesting
Gs1? parseGs1(String raw) {
  var text = raw.trim();
  if (RegExp(r'^\][A-Za-z]\d').hasMatch(text)) text = text.substring(3);
  final elements = text.contains('(') ? _bracketed(text) : _flat(text);
  final gtin = elements['01'];
  if (gtin == null || !gtinValid(gtin) || gtin.length != 14) return null;
  final expiry = elements['17'];
  return Gs1(gtin: gtin, lot: elements['10'], expiry: expiry == null ? null : _day(expiry), serial: elements['21']);
}

Map<String, String> _bracketed(String text) => {
  for (final m in RegExp(r'\((\d{2})\)([^(]*)').allMatches(text)) m.group(1)!: m.group(2)!.replaceAll(_gs, ''),
};

Map<String, String> _flat(String text) {
  final out = <String, String>{};
  var i = 0;
  while (i + 2 <= text.length) {
    final ai = text.substring(i, i + 2);
    i += 2;
    final int? fixed = switch (ai) {
      '01' => 14,
      '17' => 6,
      _ => null,
    };
    if (fixed == null && ai != '10' && ai != '21') break;
    final end = fixed != null ? i + fixed : _endOfVariable(text, i);
    if (end > text.length) break;
    out[ai] = text.substring(i, end);
    i = end < text.length && text[end] == _gs ? end + 1 : end;
  }
  return out;
}

int _endOfVariable(String text, int from) {
  final gs = text.indexOf(_gs, from);
  final end = gs < 0 ? text.length : gs;
  return end - from > 20 ? from + 20 : end;
}

String? _day(String yymmdd) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
  final year = 2000 + int.parse(yymmdd.substring(0, 2));
  final month = int.parse(yymmdd.substring(2, 4));
  var day = int.parse(yymmdd.substring(4, 6));
  if (month < 1 || month > 12) return null;
  if (day == 0) day = DateTime(year, month + 1, 0).day;
  return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// What a scanned text is for the goods sheets.
enum GoodsCodeKind {
  /// A GTIN with a valid check digit: resolved as typed.
  gtin,

  /// A digit string of a GTIN's length whose check digit is wrong: a misread, said and not resolved.
  misread,

  /// A GS1 element string with a valid GTIN: resolved by its GTIN, its lot and expiry kept.
  gs1,

  /// Anything else (a place label, an own code): resolved as typed.
  other,
}

({GoodsCodeKind kind, Gs1? gs1}) classifyGoodsCode(String text) {
  final code = text.trim();
  final gs1 = parseGs1(code);
  if (gs1 != null) return (kind: GoodsCodeKind.gs1, gs1: gs1);
  if (RegExp(r'^\d+$').hasMatch(code) && [8, 12, 13, 14].contains(code.length)) {
    return (kind: gtinValid(code) ? GoodsCodeKind.gtin : GoodsCodeKind.misread, gs1: null);
  }
  return (kind: GoodsCodeKind.other, gs1: null);
}
