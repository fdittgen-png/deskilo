// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The welcome page (web/welcome, #2390) is the page the project is
// communicated with, in the app's five languages. Its English lives in
// index.html and the other four in i18n.js, so nothing but a test notices
// a sentence added in English only, a screenshot missing in one language,
// or an inline script that the page's Content-Security-Policy would block
// in production while the local preview still worked.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _dir = 'web/welcome';
const _languages = ['fr', 'de', 'es', 'it'];

String _read(String name) => File('$_dir/$name').readAsStringSync();

/// The keys of one language block in i18n.js (`  fr: { ... }`).
Set<String> _keysOf(String i18n, String lang) {
  final start = i18n.indexOf('\n  $lang: {');
  if (start < 0) throw StateError('i18n.js has no "$lang" block');
  final end = i18n.indexOf('\n  }', start);
  return RegExp(
    r"^\s*'([\w.]+)':",
    multiLine: true,
  ).allMatches(i18n.substring(start, end)).map((m) => m.group(1)!).toSet();
}

void main() {
  final html = _read('index.html');
  final i18n = _read('i18n.js');
  final script = _read('welcome.js');

  final pageKeys = RegExp(r'data-i18n(?:-html|-alt|-aria)?="([^"]+)"')
      .allMatches(html)
      .map((m) => m.group(1)!)
      .toSet();
  // Strings the script writes itself (title, plan status) are in `en` too.
  final scriptKeys = _keysOf(i18n, 'en');

  test('the page has translatable text at all', () {
    expect(pageKeys.length, greaterThan(150));
    expect(scriptKeys, contains('meta.title'));
  });

  for (final lang in _languages) {
    test('every key on the page is translated into $lang', () {
      final keys = _keysOf(i18n, lang);
      expect(pageKeys.union(scriptKeys).difference(keys), isEmpty);
      expect(
        keys.difference(pageKeys.union(scriptKeys)),
        isEmpty,
        reason: 'a translation no element asks for is dead text',
      );
    });
  }

  test('every screenshot exists in all five languages', () {
    final shots = RegExp(r'data-shot="([^"]+)"')
        .allMatches(html)
        .map((m) => m.group(1)!)
        .toSet();
    expect(shots, isNotEmpty);
    final missing = [
      for (final shot in shots)
        for (final lang in ['en', ..._languages])
          if (!File('$_dir/img/$shot.$lang.webp').existsSync())
            '$shot.$lang.webp',
    ];
    expect(missing, isEmpty, reason: 'run tool/welcome_media.sh');
  });

  test('the media tool rebuilds exactly the screenshots the page uses', () {
    final tool = File('tool/welcome_media.sh').readAsStringSync();
    // A user-guide shot loses its "user-" prefix on the page; a setup-guide
    // shot keeps "setup-".
    final listed = RegExp(r'^\s+((?:user|setup)-[\w-]+)$', multiLine: true)
        .allMatches(tool)
        .map((m) => m.group(1)!.replaceFirst(RegExp('^user-'), ''))
        .toSet();
    final used = RegExp(r'data-shot="([^"]+)"')
        .allMatches(html)
        .map((m) => m.group(1)!)
        .toSet();
    expect(listed, used);
  });

  test('nothing inline that the Content-Security-Policy blocks', () {
    expect(html, contains("script-src 'self'"));
    expect(
      RegExp(r'<script(?![^>]*\bsrc=)').hasMatch(html),
      isFalse,
      reason: 'inline <script>',
    );
    expect(
      RegExp(r'\sstyle="').hasMatch(html),
      isFalse,
      reason: 'inline style attribute',
    );
    expect(
      RegExp(r'\son[a-z]+="').hasMatch(html),
      isFalse,
      reason: 'inline event handler',
    );
  });

  test('every local file the page references exists', () {
    final refs = RegExp(r'''(?:src|href)="(?!https?:|#|mailto:)([^"]+)"''')
        .allMatches(html)
        .map((m) => m.group(1)!);
    final missing = [
      for (final ref in refs)
        if (!File('$_dir/$ref').existsSync()) ref,
    ];
    expect(missing, isEmpty);
  });

  test('links leave the page by absolute URL, so a copy on another host '
      'still reaches the app', () {
    // A relative link to ../ would point at nothing on a personal server.
    expect(RegExp(r'href="\.\./').hasMatch(html), isFalse);
    expect(script, contains('https://fdittgen-png.github.io/deskilo/guide/'));
  });
}
