// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:characters/characters.dart';

/// [text] with its first letter in capitals, by the rules of [locale]: the
/// first user-perceived character (never a code unit, so a letter of two
/// code units stays whole) and the Turkish and Azerbaijani dotted capital
/// (`istanbul` is `İstanbul`). For a month, a city or a label a person reads.
String capitalizeFirst(String text, {String? locale}) {
  if (text.isEmpty) return text;
  final first = text.characters.first;
  final language = (locale ?? '').split(RegExp('[_-]')).first.toLowerCase();
  final dotted = (language == 'tr' || language == 'az') && first == 'i';
  return (dotted ? 'İ' : first.toUpperCase()) + text.substring(first.length);
}
