// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A guide never invents a label: every **bold** term in a chapter is a thing
// the reader sees on a screen, so it must be a label of the app in that
// language. This lists the bold terms that are not.
//
//   dart run tool/guide_labels.dart --lang fr docs/guide/user/02-reserve.fr.md
//
// The structural words of the skeleton (Steps, Good to know, Audience,
// See also, Tip, Careful) and the role names are allowed. Terms are matched
// case-insensitively as a substring of any ARB value; a hit that only
// matches a longer sentence is accepted, since buttons are often quoted by
// their first words. Exit code 1 when something is unknown.
import 'dart:convert';
import 'dart:io';

/// The skeleton's own words, per language (lower case, no colon).
const _structure = <String, Set<String>>{
  'en': {'steps', 'good to know', 'audience', 'see also', 'tip', 'careful', 'before you start', 'result'},
  'fr': {'étapes', 'bon à savoir', 'public', 'voir aussi', 'astuce', 'attention', 'avant de commencer', 'résultat'},
  'de': {'schritte', 'gut zu wissen', 'zielgruppe', 'siehe auch', 'tipp', 'achtung', 'bevor sie beginnen', 'ergebnis'},
  'es': {'pasos', 'conviene saber', 'público', 'véase también', 'consejo', 'atención', 'antes de empezar', 'resultado'},
  'it': {'passaggi', 'da sapere', 'destinatari', 'vedi anche', 'consiglio', 'attenzione', 'prima di iniziare', 'risultato'},
};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\{[^}]*\}'), '')
    .replaceAll(RegExp(r'[\s:.…!?]+$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

void main(List<String> args) {
  var lang = 'en';
  final files = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--lang') {
      lang = args[++i];
    } else {
      files.add(args[i]);
    }
  }
  if (files.isEmpty) {
    stderr.writeln('usage: dart run tool/guide_labels.dart --lang <en|fr|de|es|it> <chapter.md>…');
    exitCode = 2;
    return;
  }
  final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
  final labels = <String>{
    for (final e in arb.entries)
      if (!e.key.startsWith('@') && e.value is String) _norm(e.value as String),
  }..remove('');
  final haystack = labels.toList();
  final allowed = _structure[lang]!;
  final bold = RegExp(r'\*\*([^*\n]+?)\*\*');
  var unknown = 0;
  for (final path in files) {
    final lines = File(path).readAsLinesSync();
    // The title block of the front page is a slogan, not a screen.
    if (path.contains('00-front')) continue;
    var inFence = false;
    for (var n = 0; n < lines.length; n++) {
      final line = lines[n];
      if (line.trimLeft().startsWith('```')) inFence = !inFence;
      if (inFence) continue;
      for (final m in bold.allMatches(line)) {
        final term = _norm(m[1]!);
        if (term.isEmpty || allowed.contains(term)) continue;
        // Role names and workspace words may be a part of a label.
        final found = labels.contains(term) || haystack.any((l) => l.contains(term));
        if (!found) {
          unknown++;
          stdout.writeln('$path:${n + 1}: "${m[1]}" is not a label of the app ($lang)');
        }
      }
    }
  }
  stdout.writeln(unknown == 0 ? 'all bold terms are app labels' : '$unknown unknown term(s)');
  exitCode = unknown == 0 ? 0 : 1;
}
