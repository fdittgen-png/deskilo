// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 -- the Demo's session provider lives above the Demo's own container
// and builds the whole Demo dataset wherever it is first read. A read from
// the app (the shell, a screen, a feature) builds that dataset again inside
// every Demo scope and inside every live session. What the app may know
// about the Demo it reads from `DemoEnvironment`, the widget the Demo wraps
// the app in. So only the Demo's own files name the provider.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The folder whose files own the Demo session.
const _owner = 'lib/core/demo/';

void main() {
  test('only the Demo reads its session provider', () {
    final readers = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.startsWith(_owner)) continue;
      if (file.readAsStringSync().contains('demoSessionControllerProvider')) {
        readers.add(path);
      }
    }
    expect(
      readers,
      isEmpty,
      reason:
          'these files read the Demo session provider and would build the '
          'Demo dataset outside the Demo; read DemoEnvironment.maybeOf '
          '(persona, scopeKey) instead',
    );
  });
}
