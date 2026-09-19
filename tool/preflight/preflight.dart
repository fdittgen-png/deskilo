// SPDX-License-Identifier: 0BSD
//
// #1447 — which generators a change implicates, decided from the paths.
//
// Every generated tree in this repository has a drift gate, and the gate
// runs in CI. A generator forgotten locally therefore costs a full CI
// round trip to learn something the working tree already knew: that
// `docs/testing/TEST_INVENTORY.md` no longer lists the test just added,
// or that `assets/instance/bundle.json` is a migration behind. This maps
// an authoritative input to the generator that owns its output, so the
// round trip happens on the laptop instead.
//
// It is deliberately the same shape as `tool/ci_classify` and obeys the
// same rule: a path nobody recognises selects nothing here, because a
// preflight that ran every generator on every change would be ignored
// within a week. The drift gates remain the authority; this is the
// reminder.
//
// Bump [preflightVersion] whenever a rule changes.

const String preflightVersion = '1';

/// One generator, and why this change reached it.
class Step {
  const Step(this.command, this.owns, this.because);

  /// The command as a person would type it.
  final String command;

  /// What the command writes, for the message when it changes something.
  final String owns;

  /// The input that selected this step.
  final String because;

  @override
  bool operator ==(Object other) => other is Step && other.command == command;

  @override
  int get hashCode => command.hashCode;
}

/// Ordered so a generator that reads another's output runs after it:
/// the ARB aggregate is built before `flutter gen-l10n` reads it, and
/// the feature registry is built before the setup catalogue quotes it.
const List<({String command, String owns})> _order = [
  (command: 'dart run tool/build_arb.dart', owns: 'lib/l10n/app_*.arb'),
  (command: 'flutter gen-l10n', owns: 'lib/l10n/app_localizations*.dart'),
  (
    command: 'dart run tool/build_feature_registry_sql.dart',
    owns: 'the feature_registry() statement in the latest migration',
  ),
  (
    command: 'dart run tool/build_process_catalogue.dart',
    owns: 'docs/design/process-catalogue.md',
  ),
  (
    command: 'dart run tool/build_process_labels.dart',
    owns: 'lib/features/workspace/presentation/process_names.dart',
  ),
  (
    command: 'dart run tool/build_builtin_templates.dart',
    owns: 'supabase/templates/*.json',
  ),
  (command: 'dart run tool/build_setup_l10n.dart', owns: 'web/setup_*.js'),
  (command: 'dart run tool/build_help.dart', owns: 'assets/help/*.md'),
  (
    command: 'dart run tool/record_applied_migrations.dart',
    owns: 'supabase/APPLIED.sha256',
  ),
  (
    command: 'dart run tool/build_instance.dart',
    owns: 'assets/instance/bundle.json',
  ),
  (command: 'dart run tool/l10n_audit.dart', owns: 'docs/testing/L10N_AUDIT.md'),
  (
    command: 'dart run tool/test_inventory.dart',
    owns: 'docs/testing/TEST_INVENTORY.md',
  ),
  (
    command: 'dart run tool/dependency_map.dart',
    owns: 'docs/design/APPLICATION_BOUNDARIES.md',
  ),
];

bool _isFeatureRegistry(String p) =>
    p == 'lib/features/workspace/domain/workspace_feature.dart';

bool _isProcessRegistry(String p) =>
    p == 'lib/features/workspace/domain/workspace_process.dart';

/// The generators [paths] implicate, in the order they must run.
///
/// A generated file appearing in [paths] selects nothing by itself: it is
/// the output, and the input that produced it is what decides. That keeps
/// `git add -A` after a generator run from selecting the same generator
/// again.
List<Step> preflightSteps(Iterable<String> paths) {
  final because = <String, String>{};
  void select(String command, String path) =>
      because.putIfAbsent(command, () => path);

  for (final p in paths) {
    if (p.startsWith('lib/l10n/_fragments/')) {
      select('dart run tool/build_arb.dart', p);
      select('flutter gen-l10n', p);
    }
    if (_isFeatureRegistry(p)) {
      select('dart run tool/build_feature_registry_sql.dart', p);
      select('dart run tool/build_builtin_templates.dart', p);
      select('dart run tool/build_setup_l10n.dart', p);
    }
    if (_isProcessRegistry(p)) {
      select('dart run tool/build_process_catalogue.dart', p);
      select('dart run tool/build_process_labels.dart', p);
    }
    // The setup page quotes the feature and process copy, so its own
    // sources select the catalogue that feeds it.
    if (p == 'web/setup.html' || p.startsWith('lib/features/workspace/presentation/feature_')) {
      select('dart run tool/build_setup_l10n.dart', p);
    }
    if (p.startsWith('docs/wiki/')) {
      select('dart run tool/build_help.dart', p);
    }
    if (p.startsWith('supabase/migrations/')) {
      select('dart run tool/record_applied_migrations.dart', p);
      select('dart run tool/build_instance.dart', p);
    }
    // The instance bundle carries the edge functions and the seed too.
    if (p.startsWith('supabase/functions/') || p.startsWith('supabase/restore/')) {
      select('dart run tool/build_instance.dart', p);
    }
    // Any hand-written lib/ file can add a user-facing literal.
    if (p.startsWith('lib/') &&
        p.endsWith('.dart') &&
        !p.startsWith('lib/l10n/') &&
        !p.endsWith('.g.dart') &&
        !p.endsWith('.freezed.dart')) {
      select('dart run tool/l10n_audit.dart', p);
    }
    if (p.startsWith('test/') && p.endsWith('.dart')) {
      select('dart run tool/test_inventory.dart', p);
    }
    // #1449 — the map counts imports and repository reads across
    // features, so any feature source can move it.
    if (p.startsWith('lib/features/') &&
        p.endsWith('.dart') &&
        !p.endsWith('.g.dart') &&
        !p.endsWith('.freezed.dart')) {
      select('dart run tool/dependency_map.dart', p);
    }
  }

  return [
    for (final step in _order)
      if (because.containsKey(step.command))
        Step(step.command, step.owns, because[step.command]!),
  ];
}
