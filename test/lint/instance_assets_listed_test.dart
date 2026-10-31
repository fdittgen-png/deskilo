// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 — since the instance bundle goes through an asset transformer, the
// instance assets are listed one by one in pubspec.yaml instead of as a
// directory. A new file in assets/instance/ must be listed too, or the
// build silently leaves it out.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every file in assets/instance/ is an asset of the app', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final listed = {
      for (final m in RegExp(
        r'(?:- |path: )(assets/instance/[^\s#]+)',
      ).allMatches(pubspec))
        m.group(1)!,
    };
    final files = [
      for (final f in Directory('assets/instance').listSync())
        if (f is File) f.path.replaceAll(r'\', '/'),
    ]..sort();
    expect(files, isNotEmpty);
    expect(
      [
        for (final f in files)
          if (!listed.contains(f)) f,
      ],
      isEmpty,
      reason: 'list each in pubspec.yaml under flutter: assets:',
    );
  });
}
