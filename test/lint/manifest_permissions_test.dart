// SPDX-License-Identifier: MIT
//
// Pinning test for #99: Flutter injects INTERNET only into the debug/profile
// manifest overlays — a release build without it in the MAIN manifest cannot
// open any socket, and every backend call dies client-side. This regression
// reached production once; never again.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main AndroidManifest declares the permissions the app depends on',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final permission in [
      'android.permission.INTERNET', // Supabase — everything is remote (#99)
      'android.permission.CAMERA', // QR scan-to-join (#88)
    ]) {
      expect(
        manifest,
        contains(permission),
        reason: '$permission missing from the MAIN manifest — release '
            'builds do not inherit debug-overlay permissions.',
      );
    }
  });
}
