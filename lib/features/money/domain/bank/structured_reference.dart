// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The structured references a payer types and a bank line returns: the
// Swiss QR reference (27 digits, recursive modulus 10) and the ISO 11649
// creditor reference (`RF`, modulus 97). A string is one only when its
// check digits hold; anything else is free text. Pure Dart.
import '../swiss_qr_bill.dart';

/// [text] upper-cased without spaces: how a reference is stored and
/// compared.
String normalizeReference(String text) =>
    text.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// Whether [text] is a QR reference whose check digit holds.
bool isQrReference(String text) => isValidQrr(normalizeReference(text));

/// Whether [text] is an ISO 11649 creditor reference whose check digits
/// hold.
bool isCreditorReference(String text) => isValidScor(normalizeReference(text));

final _qrrCandidate = RegExp(r'(?<!\d)\d(?: ?\d){26}(?!\d)');
final _rfStart = RegExp(r'^RF\d{2}[A-Z0-9]*$');
final _group = RegExp(r'^[A-Z0-9]{1,4}$');

/// The ISO 11649 body is at most 21 characters after `RF` and its check.
const int _maxCreditorReference = 25;

/// The printed group length of a creditor reference.
const int _groupLength = 4;

/// The first valid QR or creditor reference written in [text] (a QR
/// reference's digits possibly grouped by single spaces, a creditor
/// reference possibly printed in groups of four), normalised; null when
/// there is none.
String? structuredReferenceIn(String text) {
  for (final m in _qrrCandidate.allMatches(text)) {
    final ref = normalizeReference(m.group(0)!);
    if (isValidQrr(ref)) return ref;
  }
  final words = text
      .toUpperCase()
      .split(RegExp(r'[^A-Z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  for (final (i, word) in words.indexed) {
    if (!_rfStart.hasMatch(word)) continue;
    String? found = isValidScor(word) ? word : null;
    var ref = word;
    // A printed reference continues while every group so far had four.
    for (var j = i + 1; j < words.length; j++) {
      final previous = words[j - 1];
      if (previous.length != _groupLength || !_group.hasMatch(words[j])) break;
      ref += words[j];
      if (ref.length > _maxCreditorReference) break;
      if (isValidScor(ref)) found = ref;
    }
    if (found != null) return found;
  }
  return null;
}
