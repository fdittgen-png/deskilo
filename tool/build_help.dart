// SPDX-License-Identifier: 0BSD
//
// Compiles the wiki user guides (docs/wiki/) into the in-app help assets
// (assets/help/). The wiki is the single source of truth: edit the guide
// there, run this tool, commit the regenerated assets.
//
// Transformations per locale:
//   - HTML <img src="images/x.jpg" …> tags (the wiki uses them for width
//     control) become plain markdown images pointing into the bundled
//     assets — one per line, since phones render a single column anyway.
//   - Wiki-internal page links ([User Guide](User-Guide)) lose the link
//     and keep the text: those pages don't exist inside the app.
//   - The "other languages" sentence is dropped — in-app help always
//     follows the app language.
//   - `<!-- anchor: id -->` above a heading is lifted into
//     assets/help/<lang>.anchors.json (id -> the heading's text) and
//     removed from the text, so the help screen can jump to the exact
//     object a help symbol names (#1016).
//
// Usage:
//   dart run tool/build_help.dart
//
// Images are copied from docs/wiki/images/ to assets/help/images/.

import 'dart:convert';
import 'dart:io';

/// The guides, per language, in reading order. A language compiles the
/// files it HAS: a guide that exists only in English joins the English
/// bundle and waits for its translations rather than mixing languages in
/// one document (#1018).
const guides = <String, List<String>>{
  'en': [
    'User-Guide.md',
    'Admin-Configuration-Guide.md',
    'Admin-Technical-Guide.md',
    'Environments-Guide.md',
  ],
  'fr': [
    'Guide-utilisateur.md',
    'Admin-Configuration-Guide.fr.md',
    'Admin-Technical-Guide.fr.md',
    'Environments-Guide.fr.md',
  ],
  'de': [
    'Benutzerhandbuch.md',
    'Admin-Configuration-Guide.de.md',
    'Admin-Technical-Guide.de.md',
    'Environments-Guide.de.md',
  ],
  'es': [
    'Guia-de-usuario.md',
    'Admin-Configuration-Guide.es.md',
    'Admin-Technical-Guide.es.md',
    'Environments-Guide.es.md',
  ],
  'it': [
    'Guida-utente.md',
    'Admin-Configuration-Guide.it.md',
    'Admin-Technical-Guide.it.md',
    'Environments-Guide.it.md',
  ],
};
const wikiDir = 'docs/wiki';
const outDir = 'assets/help';

/// `<!-- anchor: user.money.vat.rates -->` on the line above a heading.
/// An HTML comment renders as nothing on GitHub and in the app, so the
/// same source serves the wiki and the bundled guide (#1016).
final anchorComment = RegExp(r'<!--\s*anchor:\s*([a-z][a-z0-9]*(?:\.[a-z0-9-]+)+)\s*-->');

/// `<img src="images/x.jpg" width="240">` → capture the file name.
final htmlImg = RegExp(r'<img\s+src="images/([^"]+)"[^>]*>');

/// `[Label](Page-Name)` where the target is a bare wiki page (no scheme,
/// no slash, no anchor) — replaced by the label alone.
final wikiLink = RegExp(r'\[([^\]]+)\]\((?![a-z]+://|#|/)[A-Za-z0-9-]+\)');

/// The "other languages" sentence: an italic run naming the sibling
/// guides, present in every locale's intro line.
final otherLanguages = RegExp(r'\s*\*[^*]*\[[^\]]+\]\(User-Guide\)[^*]*\*|'
    r'\s*\*Autres langues[^*]*\*');

/// anchor -> the text of the heading it names, in this guide's language.
Map<String, String> anchorsOf(String source) {
  final anchors = <String, String>{};
  final lines = source.split('\n');
  for (var i = 0; i < lines.length - 1; i++) {
    final match = anchorComment.firstMatch(lines[i]);
    if (match == null) continue;
    // The heading it names is the next non-empty line, and it must be one.
    var j = i + 1;
    while (j < lines.length && lines[j].trim().isEmpty) {
      j++;
    }
    if (j >= lines.length || !lines[j].startsWith('#')) continue;
    anchors[match.group(1)!] = lines[j].replaceFirst(RegExp(r'^#+\s*'), '').trim();
  }
  return anchors;
}

String compile(String source) {
  var text = source;

  // The anchors are lifted into their own asset; the text loses them.
  text = text.replaceAll(anchorComment, '');

  // The <details> reference blocks (the giant one-image forms) are a
  // wiki-only affordance: the in-app renderer has no collapsing, and a
  // 13000-px image block is exactly what #765 removed from the help.
  text = text.replaceAll(RegExp(r'<details>[\s\S]*?</details>\n?'), '');

  // Drop the languages sentence first (it contains wiki links that would
  // otherwise survive as plain text).
  text = text.replaceAll(otherLanguages, '');

  // One markdown image per line, resolved against the bundled assets.
  text = text.replaceAllMapped(
    htmlImg,
    (m) => '\n\n![](assets/help/images/${m[1]})\n\n',
  );
  // The <p> wrappers are now empty shells.
  text = text.replaceAll(RegExp(r'</?p>'), '');

  // Wiki-internal page links: keep the label, lose the dead link.
  text = text.replaceAllMapped(wikiLink, (m) => m[1]!);

  // Blockquote lines whose only content was an image are now empty.
  text = text.replaceAll(RegExp(r'^>\s*$', multiLine: true), '');

  // Collapse the blank-line runs the removals leave behind.
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return '${text.trim()}\n';
}

/// What `build_help` writes for one locale, composed from the listed
/// sources that exist.
///
/// #1386 — this was inline in [main]. Nothing could assert that the
/// committed `assets/help/` equalled a fresh build, so a guide edited
/// without a regeneration shipped in-app help contradicting its own
/// source: `Admin-Configuration-Guide.de.md` said `## MwSt.` while the
/// generated `de.md` still said `## Umsatzsteuer`, and the help symbol
/// `config.vat.overview` resolved to the stale wording. Three lines, and
/// nothing to catch them — `lib/l10n` has had exactly this gate since
/// HARD RULE #4, and the other generated tree had none.
///
/// Pure, so `help_generated_test` can compare it against what is on disk.
typedef RenderedGuide = ({String markdown, String anchorsJson, List<String> present, List<String> absent});

RenderedGuide renderLocale(String locale) {
  final listed = guides[locale]!.map((name) => File('$wikiDir/$name')).toList();
  final sources = listed.where((f) => f.existsSync()).toList();
  final raw = sources.map((f) => f.readAsStringSync()).join('\n\n');
  return (
    markdown: compile(raw),
    anchorsJson:
        '${const JsonEncoder.withIndent('  ').convert(anchorsOf(raw))}\n',
    present: sources.map((f) => f.uri.pathSegments.last).toList(),
    absent: listed
        .where((f) => !f.existsSync())
        .map((f) => f.uri.pathSegments.last)
        .toList(),
  );
}

void main() {
  final images = Directory('$wikiDir/images');
  final outImages = Directory('$outDir/images')..createSync(recursive: true);

  for (final locale in guides.keys) {
    final rendered = renderLocale(locale);
    // #1259 — a guide this tool LISTS but cannot find used to disappear
    // without a word: `where(existsSync)` dropped it and the run still
    // reported success. Eight translated admin guides were absent that
    // way, so fr/de/es/it shipped in-app help carrying no operator
    // content at all while every build said it had worked.
    //
    // Named, not fatal: the four translations do not exist yet, and a
    // tool that refuses to run until they do would block the very work
    // that produces them. The ratchet in help_guide_parity_test is what
    // stops the gap growing.
    if (rendered.absent.isNotEmpty) {
      stderr.writeln('$locale: listed but absent — ${rendered.absent.join(', ')}');
    }
    if (rendered.present.isEmpty) {
      stderr.writeln('No guide for $locale in $wikiDir');
      exitCode = 1;
      return;
    }
    File('$outDir/$locale.md').writeAsStringSync(rendered.markdown);
    File('$outDir/$locale.anchors.json').writeAsStringSync(rendered.anchorsJson);
    stdout.writeln('wrote $outDir/$locale.md — ${rendered.present.length} '
        'guide(s), ${(jsonDecode(rendered.anchorsJson) as Map).length} anchors');
  }

  var copied = 0;
  for (final img in images.listSync().whereType<File>()) {
    if (!img.path.endsWith('.jpg')) continue;
    final name = img.uri.pathSegments.last;
    img.copySync('${outImages.path}/$name');
    copied++;
  }
  stdout.writeln('copied $copied images');
}
