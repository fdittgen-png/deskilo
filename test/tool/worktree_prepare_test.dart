// SPDX-License-Identifier: AGPL-3.0-or-later
// The worktree setup and session hook regressions run in the existing tool
// shard, rather than becoming an unexecuted advisory Python test file.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'worktree preparation preserves source and refuses invalid prerequisites',
    () {
      final result = Process.runSync('python3', [
        '-m',
        'unittest',
        'discover',
        '-s',
        'test/tool',
        '-p',
        'worktree_prepare_test.py',
        '-v',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}
