// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The reference deployment's endpoint is pinned. #2343 — the store builds
// default to it; the libre flavour (after tool/fdroid_foss_swap.sh) has no
// default at all, and the swap finds the one line it edits.
import 'dart:io';

import 'package:deskilo/core/backend/backend_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reference deployment endpoint is pinned', () {
    expect(BackendConfig.referenceUrl, startsWith('https://'));
    expect(BackendConfig.referenceUrl, isNot(endsWith('/')));
    expect(BackendConfig.referenceKey, startsWith('sb_publishable_'));
  });

  test('the default is the reference, or nothing in a build without one', () {
    if (BackendConfig.noDefaultServer) {
      expect(BackendConfig.supabaseUrl, isEmpty);
      expect(BackendConfig.hasDefault, isFalse);
    } else {
      expect(BackendConfig.supabaseUrl, startsWith('https://'));
      expect(BackendConfig.supabaseKey, startsWith('sb_publishable_'));
    }
  });

  test('#2343 — the libre swap finds the line it flips', () {
    final source = File('lib/core/backend/backend_config.dart')
        .readAsStringSync();
    final swap = File('tool/fdroid_foss_swap.sh').readAsStringSync();
    final flipped = source.contains(
      "bool.fromEnvironment('DESKILO_NO_DEFAULT_SERVER', defaultValue: true);",
    );
    expect(
      flipped ||
          source.contains("bool.fromEnvironment('DESKILO_NO_DEFAULT_SERVER');"),
      isTrue,
      reason: 'tool/fdroid_foss_swap.sh seds exactly this line',
    );
    expect(
      swap,
      contains("s|bool.fromEnvironment('DESKILO_NO_DEFAULT_SERVER');|"),
    );
  });
}
