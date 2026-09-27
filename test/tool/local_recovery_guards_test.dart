// SPDX-License-Identifier: AGPL-3.0-or-later
// The real recovery CLI refuses unsafe targets, corrupt manifests and secret
// reports before invoking any provider; Python subprocess failures stay red.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local recovery guards and report privacy', () async {
    final result = await Process.run('python3', [
      '-B',
      '-m',
      'unittest',
      'discover',
      '-s',
      'scripts/recovery',
      '-p',
      'test_guards.py',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stderr}', contains('OK'));
  });
}
