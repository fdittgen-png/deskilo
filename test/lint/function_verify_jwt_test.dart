// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3094 E11 — the invariant: the functions that must not demand a JWT at the
// gateway are declared the same way in the instance builder and in
// supabase/config.toml. Without the config.toml entry a CI deploy turns
// verification on and the payment webhooks, the MCP endpoint, the accounting
// redirect and the federation inbox stop answering.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_instance.dart' show functionVerifyJwt;
import 'lint_sources.dart';

void main() {
  test('config.toml and the instance builder agree on verify_jwt', () {
    final toml = File('supabase/config.toml').readAsStringSync();
    final declared = <String, bool>{
      for (final m in RegExp(
        r'^\[functions\.([a-z0-9-]+)\]\s*\n\s*verify_jwt\s*=\s*(true|false)',
        multiLine: true,
      ).allMatches(toml))
        m.group(1)!: m.group(2) == 'true',
    };
    final off = {
      for (final e in functionVerifyJwt.entries)
        if (!e.value) e.key,
    };
    expect(
      {
        for (final e in declared.entries)
          if (!e.value) e.key,
      },
      off,
      reason: 'every function the builder deploys without a JWT check needs '
          'its [functions.<slug>] verify_jwt = false in supabase/config.toml, '
          'and nothing else may be listed false there',
    );
    for (final slug in functionVerifyJwt.keys) {
      expect(
        directoryAt('supabase/functions/$slug').existsSync(),
        isTrue,
        reason: '$slug is not a function directory',
      );
    }
  });
}
