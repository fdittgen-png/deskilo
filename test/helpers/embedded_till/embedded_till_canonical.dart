// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4452 (E01A) -- the one byte form of a terminal payload, so the Dart producer, the TypeScript adapter and the C++ firmware
// all compute the same digest from the same document. Canonical JSON: object keys in the byte order of their UTF-8 form, no
// whitespace outside strings, an absent field omitted (never null), arrays in their order, integers in decimal, no other
// number (a financial amount is a decimal STRING, never a float), strings escaped only for `"`, `\`, and the controls below
// U+0020 (as `\u00xx`, lower-case hex); every other character is emitted as its UTF-8 bytes.
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

/// A payload the canonical form cannot carry: a null, a float, a key that is not text.
class CanonicalFormRefused implements Exception {
  const CanonicalFormRefused(this.where);

  /// Where in the document, as a path like `pages[0].keys[2].label`.
  final String where;

  @override
  String toString() => 'CanonicalFormRefused($where)';
}

/// The canonical text of [value] (a map, a list, a string, an integer or a bool).
String canonicalJson(Object? value) {
  final out = StringBuffer();
  _write(out, value, r'$');
  return out.toString();
}

/// The canonical bytes of [value]: its canonical text in UTF-8.
List<int> canonicalBytes(Object? value) => utf8.encode(canonicalJson(value));

/// The lower-case hex SHA-256 of [bytes].
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

void _write(StringBuffer out, Object? v, String at) {
  switch (v) {
    case null:
      throw CanonicalFormRefused(at);
    case bool():
      out.write(v ? 'true' : 'false');
    case int():
      out.write(v);
    case String():
      _string(out, v);
    case List():
      out.write('[');
      for (var i = 0; i < v.length; i++) {
        if (i > 0) out.write(',');
        _write(out, v[i], '$at[$i]');
      }
      out.write(']');
    case Map():
      final keys = [
        for (final k in v.keys)
          if (k is String) k else throw CanonicalFormRefused(at),
      ]..sort(_byUtf8);
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        _string(out, keys[i]);
        out.write(':');
        _write(out, v[keys[i]], '$at.${keys[i]}');
      }
      out.write('}');
    default:
      throw CanonicalFormRefused(at);
  }
}

/// Orders by the bytes of the UTF-8 form, which is the order of the code points (not of UTF-16 units).
int _byUtf8(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return x.length - y.length;
}

void _string(StringBuffer out, String s) {
  out.write('"');
  for (final r in s.runes) {
    if (r == 0x22) {
      out.write(r'\"');
    } else if (r == 0x5c) {
      out.write(r'\\');
    } else if (r < 0x20) {
      out.write('\\u${r.toRadixString(16).padLeft(4, '0')}');
    } else {
      out.writeCharCode(r);
    }
  }
  out.write('"');
}
