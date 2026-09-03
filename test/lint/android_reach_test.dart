// SPDX-License-Identifier: 0BSD
//
// Play turns a PERMISSION into a hardware REQUIREMENT unless the
// manifest says otherwise, and a required feature is not an error
// anywhere — it is a silent filter. The app simply stops existing for
// every device without that hardware, in the store, with no message on
// either side. This app's own closed track targets Chrome OS, where a
// rear camera is the exception rather than the rule.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Permissions whose mere presence implies `required="true"` hardware.
const _implied = {
  'android.permission.CAMERA': [
    'android.hardware.camera',
    'android.hardware.camera.autofocus',
  ],
  'android.permission.NFC': ['android.hardware.nfc'],
};

void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('every permission that implies hardware declares that hardware '
      'optional', () {
    for (final entry in _implied.entries) {
      if (!manifest.contains('android:name="${entry.key}"')) continue;
      for (final feature in entry.value) {
        expect(
          manifest,
          contains('<uses-feature android:name="$feature" '
              'android:required="false" />'),
          reason: '${entry.key} makes Play require $feature. Declare it '
              'optional or the app disappears for devices without it.',
        );
      }
    }
  });

  test('no feature is ever declared required', () {
    expect(manifest, isNot(contains('android:required="true"')),
        reason: 'a required feature is a store-wide filter, never a '
            'runtime check — hide the affordance instead');
  });
}
