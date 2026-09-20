// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1380 — the retired Demo privacy mechanism does not come back.
//
// Demo used to blur live personal data: a layer above the navigator
// scanned the render tree every frame, matched rendered paragraphs
// against a registry of personal strings that a dozen providers had to
// remember to feed, and blurred the matching rectangles.
//
// It was retired because Demo now shows invented people and has nothing
// to anonymise, and because the mechanism failed OPEN: a provider that
// forgot to register a string left a name in the clear, silently, in the
// recording nobody re-watches.
//
// The recording problem is real and is #1514's. What this test forbids
// is the old ANSWER, not the question — so it names the three things
// that made it what it was, and says where each one went.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every hand-written Dart file under `lib/`.
Iterable<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.endsWith('.g.dart'))
    .where((f) => !f.path.endsWith('.freezed.dart'));

/// What the old mechanism was made of, and why each is refused.
const Map<String, String> _retired = {
  'DemoBlurLayer': 'the layer mounted above the navigator',
  'DemoSensitiveRegistry': 'the registry of personal strings',
  'demoSensitive': 'the global registry instance every provider fed',
  'registerSensitiveNames': 'the provider-side registration',
  'demoLabelBlur': 'the mask filter the plan painted names with',
};

void main() {
  test('no file brings back the render-tree scan Demo used to blur live '
      'data (#1380)', () {
    final found = <String>[];
    for (final file in _sources()) {
      final text = file.readAsStringSync();
      for (final entry in _retired.entries) {
        if (text.contains(entry.key)) {
          found.add('${file.path}: ${entry.key} — ${entry.value}');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'these belong to the Demo blur retired in #1380. Demo shows '
          'invented people and needs no anonymisation; anonymising a LIVE '
          'workspace for a recording is #1514, and needs a mechanism that '
          'fails closed rather than one that depends on every provider '
          'remembering to register every string:\n${found.join('\n')}',
    );
  });

  test('the rule is capable of failing', () {
    // The check applied to a file that DOES carry one of the names.
    const sample = 'final registry = DemoSensitiveRegistry();';
    final hits = [
      for (final key in _retired.keys)
        if (sample.contains(key)) key,
    ];
    expect(hits, isNotEmpty,
        reason: 'a rule that cannot fire is a gate nothing can trip');
  });

  test('Demo itself is still there — this removed a mechanism, not the '
      'feature', () {
    expect(File('lib/core/demo/demo_session.dart').existsSync(), isTrue);
    expect(File('lib/core/demo/demo_scope.dart').existsSync(), isTrue);
    expect(
      File('lib/core/demo/presentation/demo_workspace.dart').existsSync(),
      isTrue,
    );
  });
}
