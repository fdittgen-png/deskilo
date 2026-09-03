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
  // `.any` is the one the camera plugin injects, and the one that was
  // actually shipping as required=true. The plain and autofocus variants
  // are declared beside it because a plugin bump can start injecting
  // either at any time.
  'android.permission.CAMERA': [
    'android.hardware.camera.any',
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
        final declared = RegExp(
          '<uses-feature\\s+android:name="${RegExp.escape(feature)}"'
          '\\s+android:required="false"',
        );
        expect(declared.hasMatch(manifest), isTrue,
            reason: '${entry.key} makes Play require $feature. Declare it '
                'optional or the app disappears for devices without it.');
        // The merger ORs android:required, so a library declaring it true
        // beats an app declaring it false. Only tools:replace wins.
        final block = manifest.substring(
            manifest.indexOf('android:name="$feature"'));
        expect(block.substring(0, block.indexOf('/>')),
            contains('tools:replace="android:required"'),
            reason: 'without tools:replace the plugin\'s required="true" '
                'survives the merge and $feature still filters devices');
      }
    }
  });

  test('no feature is ever declared required', () {
    expect(manifest, isNot(contains('android:required="true"')),
        reason: 'a required feature is a store-wide filter, never a '
            'runtime check — hide the affordance instead');
  });
}
