// SPDX-License-Identifier: 0BSD
//
// Manifest pins (#436): POST_NOTIFICATIONS was silently missing and
// Android 13+ suppressed every notification the app ever posted — no
// reminder, no badge mirror, no permission dialog. A manifest line is
// invisible to the whole Dart test suite, so it gets its own pin.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keep.xml protects the notification glyph from the release '
      'shrinker (#442)', () {
    final keep =
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    expect(
      keep.contains('@drawable/ic_stat_deskilo'),
      isTrue,
      reason: 'the shrinker strips Dart-only-referenced resources; '
          'without this keep, plugin.initialize threw invalid_icon on '
          'every release boot and ALL notifications silently died',
    );
  });

  test('the Android manifest declares POST_NOTIFICATIONS (#436)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest.contains('android.permission.POST_NOTIFICATIONS'),
      isTrue,
      reason: 'without it Android 13+ suppresses every notification '
          'silently — reminders, the badge mirror, push banners',
    );
  });
}
