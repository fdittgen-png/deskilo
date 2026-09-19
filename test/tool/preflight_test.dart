// SPDX-License-Identifier: 0BSD
//
// #1447 — the preflight selects the generator that owns the output a
// change invalidates, and selects nothing for a change that invalidates
// nothing.
//
// Each case below is a round trip this session actually paid for: a new
// test file learned about its inventory from CI, a migration learned
// about the instance bundle from a lint, and a new widget literal
// learned about the localization audit from a pull request that had
// already been rebased twice.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/preflight/preflight.dart';

List<String> _commands(List<String> paths) =>
    preflightSteps(paths).map((s) => s.command).toList();

void main() {
  test('a new test file selects the inventory, and only that', () {
    expect(
      _commands(['test/features/money/refund_test.dart']),
      ['dart run tool/test_inventory.dart'],
    );
  });

  test('a migration selects the applied baseline and the instance bundle, '
      'in that order — the bundle reads the baseline', () {
    expect(_commands(['supabase/migrations/0248_example.sql']), [
      'dart run tool/record_applied_migrations.dart',
      'dart run tool/build_instance.dart',
    ]);
  });

  test('a feature flag selects the SQL registry, the builtin templates and '
      'the setup catalogue', () {
    final commands =
        _commands(['lib/features/workspace/domain/workspace_feature.dart']);
    expect(commands, contains('dart run tool/build_feature_registry_sql.dart'));
    expect(commands, contains('dart run tool/build_builtin_templates.dart'));
    expect(commands, contains('dart run tool/build_setup_l10n.dart'));
  });

  test('an ARB fragment selects the aggregate before gen-l10n reads it', () {
    final commands = _commands(['lib/l10n/_fragments/custom_roles_fr.arb']);
    expect(
      commands.indexOf('dart run tool/build_arb.dart'),
      lessThan(commands.indexOf('flutter gen-l10n')),
    );
  });

  test('a wiki guide selects the help assets it is compiled into', () {
    expect(
      _commands(['docs/wiki/User-Guide.md']),
      ['dart run tool/build_help.dart'],
    );
  });

  test('a hand-written lib file selects the localization audit', () {
    expect(
      _commands(['lib/features/plan/presentation/widgets/legend.dart']),
      contains('dart run tool/l10n_audit.dart'),
    );
  });

  test('a feature source selects the dependency map, which counts them', () {
    expect(
      _commands(['lib/features/money/presentation/widgets/a_sheet.dart']),
      contains('dart run tool/dependency_map.dart'),
    );
    expect(
      _commands(['lib/core/demo/demo_session.dart']),
      isNot(contains('dart run tool/dependency_map.dart')),
      reason: 'the map counts cross-FEATURE relationships',
    );
  });

  test('a generated output selects nothing by itself — otherwise running a '
      'generator would select it again forever', () {
    expect(_commands(['lib/l10n/app_fr.arb']), isEmpty);
    expect(_commands(['assets/help/en/user-guide.md']), isEmpty);
    expect(_commands(['docs/testing/TEST_INVENTORY.md']), isEmpty);
    expect(_commands(['lib/features/money/domain/invoice.freezed.dart']),
        isEmpty);
  });

  test('a change that owns no generated tree selects nothing', () {
    expect(_commands(['.github/workflows/quality.yml']), isEmpty);
    expect(_commands(['README.md']), isEmpty);
  });

  test('every step says what it owns and which path selected it', () {
    final steps = preflightSteps([
      'lib/features/workspace/domain/workspace_process.dart',
      'test/lint/a_test.dart',
    ]);
    expect(steps, isNotEmpty);
    for (final s in steps) {
      expect(s.owns, isNotEmpty, reason: '${s.command} says nothing it owns');
      expect(s.because, isNotEmpty);
    }
    expect(
      steps.map((s) => s.because),
      contains('lib/features/workspace/domain/workspace_process.dart'),
    );
  });

  test('a step is selected once however many paths reach it', () {
    final commands = _commands([
      'test/a_test.dart',
      'test/b_test.dart',
      'test/c_test.dart',
    ]);
    expect(commands, ['dart run tool/test_inventory.dart']);
  });
}
