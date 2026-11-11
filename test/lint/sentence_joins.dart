// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3652 — the scan behind `sentence_one_message_test.dart`: a Dart string
// literal that interpolates a translated read (`l10n.x`, `strings.x`) beside
// another interpolation. Word order, spacing before punctuation and
// agreement cannot be right in five languages when a sentence is built from
// pieces; the sentence is ONE ARB message with placeholders.

/// A translated read inside an interpolation: `l10n.key`, `l10n?.key`,
/// `strings.key`, `context.l10n.key`.
final RegExp _read = RegExp(r'\b(?:l10n|strings|labels)\??\.\w+');

/// One interpolation: `${...}` (no nested braces) or `$name`.
final RegExp _interpolation = RegExp(r'\$\{[^{}]*\}|\$[A-Za-z_]\w*');

/// A single-line string literal containing at least one interpolation.
final RegExp _literal = RegExp(
  r"""'(?:[^'\\\n]|\\.)*\$(?:[A-Za-z_{])(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*\$(?:[A-Za-z_{])(?:[^"\\\n]|\\.)*" """
      .trim(),
);

/// The separator that joins independent facts and stays allowed.
const String independentFactJoin = ' · ';

/// The lines of [source] holding a joined sentence, as `line: text`.
List<String> sentenceJoins(String source) {
  final out = <String>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    for (final m in _literal.allMatches(line)) {
      final text = m.group(0)!;
      final parts = _interpolation.allMatches(text).toList();
      if (parts.length < 2) continue;
      if (!parts.any((p) => _read.hasMatch(p.group(0)!))) continue;
      // The text between two interpolations, and outside them.
      final between = <String>[];
      for (var k = 1; k < parts.length; k++) {
        between.add(text.substring(parts[k - 1].end, parts[k].start));
      }
      if (between.every((b) => b == independentFactJoin)) continue;
      out.add('${i + 1}: ${text.length > 90 ? text.substring(0, 90) : text}');
    }
  }
  return out;
}
