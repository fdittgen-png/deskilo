// SPDX-License-Identifier: 0BSD
//
// #807 — every parameter an owner can set must be reachable in the UI.
//
// A setting that exists only in a jsonb column is a setting only whoever
// wrote the migration knows about. The server reads it, the domain model
// carries it, the owner cannot change it — and the first they hear of it
// is when the app behaves in a way no screen explains.
//
// So: every FIELD of a configuration model has to be named by something
// under a `presentation/` directory. That is a coarse check on purpose —
// it cannot prove a control is usable — but it does catch the failure
// that actually happens, which is a parameter shipped with no screen at
// all.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The models whose fields ARE the owner's settings.
const _configModels = <String>[
  'lib/core/time/work_hours.dart',
  'lib/features/money/domain/dunning.dart',
  'lib/features/money/domain/billing_rules.dart',
  'lib/features/workspace/domain/booking_policies.dart',
];

/// Fields that legitimately have no control, each with its reason. A new
/// entry here is a claim someone has to defend in review — which is the
/// point of writing it down rather than loosening the rule.
const _exempt = <String, String>{
  // #634 — retired switch kept only so a stored `true` still resolves;
  // nothing writes it and no screen offers it, by design.
  'gridWithinHours': 'retired legacy key, read-only (#634)',
};

/// `final int startMinutes;` → startMinutes. Skips getters, statics and
/// constructor parameters; only real stored fields count.
final _fieldPattern = RegExp(
  r'^\s{2}final\s+[\w<>?, ]+\s+(\w+);',
  multiLine: true,
);

List<File> _presentationFiles() {
  final files = <File>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart') ||
        entity.path.endsWith('.freezed.dart')) {
      continue;
    }
    if (entity.path.contains('/presentation/')) files.add(entity);
  }
  return files;
}

void main() {
  test('every configuration parameter is reachable from a screen', () {
    final presentation =
        _presentationFiles().map((f) => f.readAsStringSync()).join('\n');

    final missing = <String>[];
    for (final path in _configModels) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path moved or was renamed');
      final source = file.readAsStringSync();
      for (final match in _fieldPattern.allMatches(source)) {
        final field = match.group(1)!;
        if (_exempt.containsKey(field)) continue;
        // A word-boundary match: `usageAuto` must not be satisfied by
        // `usageAutoSomethingElse`.
        final used = RegExp('\\b$field\\b').hasMatch(presentation);
        if (!used) missing.add('$path: $field');
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'These parameters have no UI anywhere under presentation/:\n'
          '${missing.join('\n')}\n\n'
          'Give each one a control the owner can reach, or — if it is '
          'genuinely settable only by the server — add it to _exempt with '
          'the reason.',
    );
  });

  test('the exemption list stays honest', () {
    // An exemption for a field that no longer exists is a comment
    // pretending to be a rule.
    final all = <String>{};
    for (final path in _configModels) {
      final source = File(path).readAsStringSync();
      for (final match in _fieldPattern.allMatches(source)) {
        all.add(match.group(1)!);
      }
    }
    for (final field in _exempt.keys) {
      // gridWithinHours is a KEY constant rather than a field — it has no
      // field precisely because it is retired. Accept either.
      final stillMentioned = all.contains(field) ||
          _configModels.any((p) =>
              File(p).readAsStringSync().contains(field));
      expect(stillMentioned, isTrue,
          reason: '$field is exempt but no longer exists — drop the entry');
    }
  });
}
