// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Launch and app-switcher backgrounds resolve bitmap sources in every resource
// configuration; an adaptive launcher XML cannot inflate inside a bitmap.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'lint_sources.dart';

void main() {
  test('every launch background bitmap resolves only raster resources', () {
    final root = directoryAt('android/app/src/main/res');
    final files = root.listSync(recursive: true).whereType<File>().toList();
    final backgrounds = files
        .where((f) => f.path.endsWith('/launch_background.xml'))
        .toList();
    expect(backgrounds, isNotEmpty);
    for (final background in backgrounds) {
      final doc = XmlDocument.parse(background.readAsStringSync());
      final bitmaps = doc.findAllElements('bitmap').toList();
      expect(bitmaps, isNotEmpty, reason: background.path);
      for (final bitmap in bitmaps) {
        final src = bitmap.getAttribute(
          'src',
          namespace: 'http://schemas.android.com/apk/res/android',
        )!;
        final match = RegExp(r'^@(drawable|mipmap)/([a-z0-9_]+)$')
            .firstMatch(src)!;
        final type = match.group(1)!;
        final name = match.group(2)!;
        final candidates = files.where((file) {
          final parts = file.path.split('/');
          return (parts[parts.length - 2] == type ||
                  parts[parts.length - 2].startsWith('$type-')) &&
              parts.last.split('.').first == name;
        }).toList();
        expect(candidates, isNotEmpty, reason: '$src must exist');
        for (final candidate in candidates) {
          expect(
            candidate.path,
            matches(r'\.(png|webp|jpg|jpeg|gif)$'),
            reason:
                '${background.path}: $src must never resolve XML (${candidate.path})',
          );
        }
      }
    }
  });
}
