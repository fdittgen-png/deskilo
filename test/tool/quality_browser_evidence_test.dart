// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3259 — A missing, skipped, failed or VM-only browser run cannot satisfy
// the required browser evidence, even when the VM shard itself succeeds.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/quality_browser_evidence.dart';

String stream({String platform = 'chrome', bool skipped = false, bool done = true, String result = 'success'}) => [
  {'type': 'start'},
  {'type': 'suite', 'suite': {'id': 1, 'platform': platform, 'path': browserSuite}},
  {'type': 'testStart', 'test': {'id': 1, 'suiteID': 1, 'name': 'actual startup'}},
  {'type': 'testDone', 'testID': 1, 'result': result, 'skipped': skipped},
  if (done) {'type': 'done', 'success': result == 'success'},
].map(jsonEncode).join('\n');

void main() {
  test('requires an actual successful completed browser test', () {
    expect(browserEvidenceProblems(stream()), isEmpty);
    for (final bad in [stream(platform: 'vm'), stream(skipped: true), stream(done: false), stream(result: 'failure'), '']) {
      expect(browserEvidenceProblems(bad), isNotEmpty);
    }
  });
}
