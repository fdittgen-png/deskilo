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
//
// Usage:
//   dart run tool/build_help.dart
//
// Images are copied from docs/wiki/images/ to assets/help/images/.

import 'dart:io';

const guides = <String, String>{
  'en': 'User-Guide.md',
  'fr': 'Guide-utilisateur.md',
  'de': 'Benutzerhandbuch.md',
  'es': 'Guia-de-usuario.md',
  'it': 'Guida-utente.md',
};
const wikiDir = 'docs/wiki';
const outDir = 'assets/help';

/// `<img src="images/x.jpg" width="240">` → capture the file name.
final htmlImg = RegExp(r'<img\s+src="images/([^"]+)"[^>]*>');

/// `[Label](Page-Name)` where the target is a bare wiki page (no scheme,
/// no slash, no anchor) — replaced by the label alone.
final wikiLink = RegExp(r'\[([^\]]+)\]\((?![a-z]+://|#|/)[A-Za-z0-9-]+\)');

/// The "other languages" sentence: an italic run naming the sibling
/// guides, present in every locale's intro line.
final otherLanguages = RegExp(r'\s*\*[^*]*\[[^\]]+\]\(User-Guide\)[^*]*\*|'
    r'\s*\*Autres langues[^*]*\*');

String compile(String source) {
  var text = source;

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

void main() {
  final images = Directory('$wikiDir/images');
  final outImages = Directory('$outDir/images')..createSync(recursive: true);

  for (final entry in guides.entries) {
    final source = File('$wikiDir/${entry.value}');
    if (!source.existsSync()) {
      stderr.writeln('Missing ${source.path}');
      exitCode = 1;
      return;
    }
    final out = File('$outDir/${entry.key}.md')
      ..writeAsStringSync(compile(source.readAsStringSync()));
    stdout.writeln('wrote ${out.path}');
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
