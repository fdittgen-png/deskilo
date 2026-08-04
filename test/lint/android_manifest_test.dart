// SPDX-License-Identifier: 0BSD
//
// Manifest pins (#436): POST_NOTIFICATIONS was silently missing and
// Android 13+ suppressed every notification the app ever posted — no
// reminder, no badge mirror, no permission dialog. A manifest line is
// invisible to the whole Dart test suite, so it gets its own pin.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
