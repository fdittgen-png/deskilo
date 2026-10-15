// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2601 — a test file never imports another `*_test.dart`.
//
// A borrower compiled its lender's whole import graph and its `main`, and
// 17+ files lent a pump that way. A pump two files share lives in
// test/helpers/ (screens in test/helpers/screens/); the lender imports it
// like everybody else. The rule covers relative imports and exports;
// `package:` URIs are other packages' business.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _testImport = RegExp(
  r'''^\s*(?:import|export)\s+['"](?!package:|dart:)[^'"]*_test\.dart['"]''',
);

void main() {
  test('no test file imports or exports another test file', () {
    final violations = scanLines(
      handWrittenDartFiles('test'),
      _testImport.hasMatch,
    );
    expect(
      violations,
      isEmpty,
      reason:
          'move the shared pump to test/helpers/ (#2601):\n'
          '${violations.join('\n')}',
    );
  });

  test('the pattern sees a sibling, a parent and an export, not a package', () {
    for (final yes in [
      "import 'reserve_hub_test.dart' show pumpHub;",
      "import '../plan/plan_screen_test.dart' as plan;",
      '''export "./x_test.dart";''',
    ]) {
      expect(_testImport.hasMatch(yes), isTrue, reason: yes);
    }
    for (final no in [
      "import 'package:flutter_test/flutter_test.dart';",
      "import '../../helpers/screens/reserve_hub.dart';",
      "import 'dart:io'; // x_test.dart",
    ]) {
      expect(_testImport.hasMatch(no), isFalse, reason: no);
    }
  });
}
