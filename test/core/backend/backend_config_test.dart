// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The reference deployment's backend defaults are pinned.
import 'package:deskilo/core/backend/backend_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reference deployment defaults are pinned', () {
    expect(BackendConfig.supabaseUrl, startsWith('https://'));
    expect(BackendConfig.supabaseUrl, isNot(endsWith('/')));
    expect(BackendConfig.supabaseKey, startsWith('sb_publishable_'));
  });
}
