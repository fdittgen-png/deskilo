// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The FOSS audit follows its dependency, flavour and Android build inputs
// on both entry points, while unrelated packages and guides do not start it.
// Its flavour-specific generation and tests remain beside the APK scans.
// test-inventory: structure is the invariant — these workflow paths decide whether the APK audit runs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

bool _matches(String path, String pattern) => pattern.endsWith('/**')
    ? path.startsWith(pattern.substring(0, pattern.length - 2))
    : path == pattern;

void main() {
  final workflow = loadYaml(
    File('.github/workflows/fdroid-foss.yml').readAsStringSync(),
  ) as YamlMap;

  for (final event in ['pull_request', 'push']) {
    test('$event audits changed FOSS inputs without unrelated packages', () {
      final events = workflow['on'] as YamlMap;
      final trigger = events[event] as YamlMap;
      final paths = (trigger['paths'] as YamlList).cast<String>();
      bool starts(String path) =>
          paths.any((pattern) => _matches(path, pattern));
      for (final path in [
        'pubspec.yaml',
        'pubspec.lock',
        '.flutter-version',
        'tool/fdroid_foss_swap.sh',
        'android/app/build.gradle.kts',
        'fdroid/de.deskilo.app.yml',
        '.github/workflows/fdroid-foss.yml',
        '.github/actions/gradle-cache/action.yml',
        'scripts/install_gradle.sh',
        'scripts/generated_drift.sh',
        'lib/core/backend/backend_config.dart',
        'lib/core/push/push_service.dart',
        'packages/deskilo_push/lib/push.dart',
        'packages/deskilo_push_foss/lib/push.dart',
      ]) {
        expect(starts(path), isTrue, reason: path);
      }
      for (final path in [
        'docs/guide/en/index.md',
        'packages/deskilo_jurisdiction_de/lib/tax.dart',
        'packages/deskilo_document_model/lib/document.dart',
      ]) {
        expect(starts(path), isFalse, reason: path);
      }
    });
  }

  test('only the two libre-specific tests run after generation', () {
    final jobs = workflow['jobs'] as YamlMap;
    final audit = jobs['foss-apk'] as YamlMap;
    final steps = (audit['steps'] as YamlList).cast<YamlMap>();
    final script = steps.map((step) => step['run'] ?? '').join('\n');
    final tests = RegExp(
      r'^\s*flutter test (.+)$',
      multiLine: true,
    ).allMatches(script).map((match) => match.group(1)!.trim()).toList();
    expect(tests, [
      'test/app/server_choice_test.dart test/core/backend/backend_config_test.dart',
    ]);
    expect(script, contains('flutter gen-l10n'));
    expect(script, isNot(contains('flutter analyze')));
    expect(
      script,
      isNot(matches(RegExp(r'^\s*flutter test\s*$', multiLine: true))),
    );
  });
}
