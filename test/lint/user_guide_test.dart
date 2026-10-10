// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The user guide and the setup guide are written once per language as
// chapter files (docs/guide/<family>) and everything else is derived from
// them: the five wiki guides per family, the in-app help and the static site.
// This is what keeps the five languages one guide and the derived files honest.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_guide_site.dart' as site;
import '../../tool/build_user_guide.dart';

const _langs = ['en', 'fr', 'de', 'es', 'it'];
final _anchor = RegExp(r'<!--\s*anchor:\s*([a-z][a-z0-9]*(?:\.[a-z0-9-]+)+)\s*-->');
final _image = RegExp(r'images/([a-z0-9-]+(?:--[a-z0-9-]+)?)\.(?:en|fr|de|es|it)(?:\.b[0-9a-f]+)?\.jpg');
final _section = RegExp(r'^### ', multiLine: true);

List<File> _chapters(Family family, String lang) {
  final dir = Directory(family.chaptersDir);
  if (!dir.existsSync()) return [];
  return dir.listSync().whereType<File>().where((f) => f.path.endsWith('.$lang.md')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _stem(File f) => f.uri.pathSegments.last.replaceFirst(RegExp(r'\.(en|fr|de|es|it)\.md$'), '');

void main() {
  for (final family in families) {
    group('the ${family.name} guide', () => _familyTests(family));
  }

  test('the wiki guides are what the chapters say', () {
    final images = imageIndex();
    for (final family in families) {
      for (final e in family.files.entries) {
        final built = assemble(e.key, images, family: family).markdown;
        if (built.isEmpty) continue;
        expect(File('docs/wiki/${e.value}').readAsStringSync(), built,
            reason: 'docs/wiki/${e.value} is stale — run: dart run tool/build_user_guide.dart');
      }
    }
  });

  test('the static site is what the wiki guides say', () {
    for (final family in families) {
      for (final e in family.files.entries) {
        final source = File('docs/wiki/${e.value}');
        if (!source.existsSync()) continue;
        final page = File('web/guide/${site.pageName(family.name, e.key)}');
        expect(page.existsSync(), isTrue, reason: '${page.path} is generated: dart run tool/build_guide_site.dart');
        expect(page.readAsStringSync(), site.renderPage(e.key, source.readAsStringSync(), book: family.name),
            reason: '${page.path} is stale — run: dart run tool/build_guide_site.dart');
      }
    }
  });
}

void _familyTests(Family family) {
  final exists = Directory(family.chaptersDir).existsSync();

  test('every chapter exists in all five languages', () {
    if (!exists) return;
    final en = _chapters(family, 'en').map(_stem).toList();
    expect(en, isNotEmpty);
    for (final lang in _langs.skip(1)) {
      expect(_chapters(family, lang).map(_stem).toList(), en,
          reason: '$lang must have exactly the chapters English has');
    }
  });

  test('the five languages are one guide: same anchors, same screenshots, same sections', () {
    for (final f in _chapters(family, 'en')) {
      final stem = _stem(f);
      final en = f.readAsStringSync();
      final anchors = _anchor.allMatches(en).map((m) => m[1]).toList();
      final images = _image.allMatches(en).map((m) => m[1]).toList();
      final sections = _section.allMatches(en).length;
      for (final lang in _langs.skip(1)) {
        final file = File('${family.chaptersDir}/$stem.$lang.md');
        if (!file.existsSync()) continue; // reported by the previous test
        final text = file.readAsStringSync();
        expect(_anchor.allMatches(text).map((m) => m[1]).toList(), anchors,
            reason: '$stem.$lang.md: anchors differ from English (same ids, same order)');
        expect(_image.allMatches(text).map((m) => m[1]).toList(), images,
            reason: '$stem.$lang.md: screenshots differ from English');
        expect(_section.allMatches(text).length, sections,
            reason: '$stem.$lang.md: section count differs from English');
      }
    }
  });

  test('every section names its audience, every link and screenshot resolves', () {
    if (!exists) return;
    final images = imageIndex();
    for (final lang in _langs) {
      final built = assemble(lang, images, family: family);
      expect(built.problems, isEmpty, reason: '$lang: ${built.problems.join('\n')}');
    }
  });

  test('a chapter never names an issue or a version', () {
    for (final lang in _langs) {
      for (final f in _chapters(family, lang)) {
        final text = f.readAsStringSync().replaceAll(_anchor, '');
        expect(RegExp(r'(?<![\w&/])#\d{3,5}\b').hasMatch(text), isFalse,
            reason: '${f.path} mentions an issue number — say what happens, not where it was tracked');
      }
    }
  });

  test('no anchor appears twice in one language', () {
    for (final lang in _langs) {
      final seen = <String>{};
      for (final f in _chapters(family, lang)) {
        for (final m in _anchor.allMatches(f.readAsStringSync())) {
          expect(seen.add(m[1]!), isTrue, reason: '$lang: anchor ${m[1]} is used twice');
        }
      }
    }
  });
}
