// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Assembles the wiki guides of the two chapter-based families from their
// chapter files:
//
//   docs/guide/user/NN-<slug>.<lang>.md   ->  docs/wiki/User-Guide.md (+ fr de es it)
//   docs/guide/setup/NN-<slug>.<lang>.md  ->  docs/wiki/Setup-Guide.md (+ fr de es it)
//
// The chapters are the only hand-written source (docs/guide/AUTHORING.md).
// This tool joins them in file order, resolves each screenshot's logical
// name (`images/<id>.<lang>.jpg`) to the file of the build it was taken from
// and turns the guide's own links into wiki links (tool/guide_links.dart);
// a `help:` link may point into the other family. `tool/build_help.dart`
// then compiles the wiki into the in-app help.
//
//   dart run tool/build_user_guide.dart           write the guides
//   dart run tool/build_user_guide.dart --check   fail when they are not what the chapters say
import 'dart:convert';
import 'dart:io';

import 'guide_links.dart';

const wikiDir = 'docs/wiki';
const imagesDir = '$wikiDir/images';

/// A family of guides written as chapters.
class Family {
  const Family(this.name, this.chaptersDir, this.files);
  final String name;
  final String chaptersDir;

  /// language -> the wiki file that carries it.
  final Map<String, String> files;
}

const userFamily = Family('user', 'docs/guide/user', {
  'en': 'User-Guide.md',
  'fr': 'Guide-utilisateur.md',
  'de': 'Benutzerhandbuch.md',
  'es': 'Guia-de-usuario.md',
  'it': 'Guida-utente.md',
});

const setupFamily = Family('setup', 'docs/guide/setup', {
  'en': 'Setup-Guide.md',
  'fr': 'Guide-de-demarrage.md',
  'de': 'Einrichtungsanleitung.md',
  'es': 'Guia-de-puesta-en-marcha.md',
  'it': 'Guida-di-avvio.md',
});

const families = [userFamily, setupFamily];

/// Kept for the user family's callers.
const chaptersDir = 'docs/guide/user';
const guideFiles = <String, String>{
  'en': 'User-Guide.md',
  'fr': 'Guide-utilisateur.md',
  'de': 'Benutzerhandbuch.md',
  'es': 'Guia-de-usuario.md',
  'it': 'Guida-utente.md',
};

/// Words of the skeleton's audience line, per language.
const audienceWord = {'en': 'Audience', 'fr': 'Public', 'de': 'Zielgruppe', 'es': 'Público', 'it': 'Destinatari'};

class Assembled {
  Assembled(this.markdown, this.problems);
  final String markdown;
  final List<String> problems;
}

/// logical image name (`user-x.fr`) -> the newest file `user-x.fr.b<build>.jpg`.
Map<String, String> imageIndex() {
  final out = <String, String>{};
  final dir = Directory(imagesDir);
  if (!dir.existsSync()) return out;
  final built = RegExp(r'^(.*\.(?:en|fr|de|es|it))\.b[0-9a-f]+\.jpg$');
  final stamped = <String, DateTime>{};
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    final m = built.firstMatch(name);
    if (m == null) continue;
    final at = f.lastModifiedSync();
    final prev = stamped[m[1]!];
    if (prev == null || at.isAfter(prev)) {
      stamped[m[1]!] = at;
      out[m[1]!] = name;
    }
  }
  return out;
}

/// The chapters of [family] in [lang], joined (links untouched).
String joinChapters(Family family, String lang) {
  final dir = Directory(family.chaptersDir);
  if (!dir.existsSync()) return '';
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.$lang.md')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files.map((f) => f.readAsStringSync().trim()).join('\n\n');
}

Assembled assemble(String lang, Map<String, String> images, {Family family = userFamily}) {
  final problems = <String>[];
  var text = joinChapters(family, lang);
  if (text.isEmpty) return Assembled('', ['no chapter for $lang']);

  // Screenshots: the logical name -> the build-stamped file.
  text = text.replaceAllMapped(RegExp(r'images/([a-z0-9-]+(?:--[a-z0-9-]+)?\.(?:en|fr|de|es|it))(?:\.b[0-9a-f]+)?\.jpg'), (m) {
    final file = images[m[1]];
    if (file == null) {
      problems.add('image ${m[1]} has no shot yet');
      return m[0]!;
    }
    return 'images/$file';
  });

  // Every section names its audience, in the guide's language.
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('### ')) continue;
    var j = i + 1;
    while (j < lines.length && lines[j].trim().isEmpty) {
      j++;
    }
    if (j >= lines.length || !lines[j].startsWith('**${audienceWord[lang]}:**')) {
      problems.add('section "${lines[i]}" has no **${audienceWord[lang]}:** line');
    }
  }

  // A `help:` link may point into the other family's guide.
  final external = <String, String>{};
  for (final other in families.where((f) => f.name != family.name)) {
    final page = other.files[lang]!.replaceFirst(RegExp(r'\.md$'), '');
    for (final e in anchorSlugs(joinChapters(other, lang)).entries) {
      external[e.key] = '$page#${e.value}';
    }
  }
  final unknown = <String>[];
  text = toWikiLinks(text, unknown: unknown, external: external);
  for (final u in unknown) {
    problems.add('help:$u points at no anchor');
  }
  return Assembled('${text.trim()}\n', problems);
}

void main(List<String> args) {
  final check = args.contains('--check');
  final images = imageIndex();
  var bad = false;
  for (final family in families) {
    for (final e in family.files.entries) {
      final built = assemble(e.key, images, family: family);
      final target = File('$wikiDir/${e.value}');
      if (built.markdown.isEmpty) {
        if (family.name == 'user') {
          stderr.writeln('${e.key}: ${built.problems.join('; ')}');
          bad = true;
        }
        continue;
      }
      for (final p in built.problems) {
        stderr.writeln('${family.name}/${e.key}: $p');
      }
      if (check) {
        final now = target.existsSync() ? target.readAsStringSync() : '';
        if (now != built.markdown) {
          stderr.writeln('${target.path} is not what the chapters say — run: dart run tool/build_user_guide.dart');
          bad = true;
        }
      } else {
        target.writeAsStringSync(built.markdown);
        stdout.writeln('wrote ${target.path} — ${const LineSplitter().convert(built.markdown).length} lines, ${built.problems.length} problem(s)');
      }
    }
  }
  exitCode = bad ? 1 : 0;
}
