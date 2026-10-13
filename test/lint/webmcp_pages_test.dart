// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The welcome and product pages' WebMCP tools (W3 of #2500): every tool in
// every language against a fake modelContext, `go_to` refusing anything but
// the page's own allow-listed targets, answers made only of catalogue
// content, unsupported browsers untouched, the pages' CSP unchanged.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the product and welcome tools answer from the page and the catalogue', () {
    final r = Process.runSync('node', ['tool/web/webmcp_pages_test.mjs']);
    final out = '${r.stdout}${r.stderr}';
    expect(r.exitCode, 0, reason: out);
    expect(out, contains('webmcp pages:'));
  });
}
