// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C2 — the classifier selects work conservatively: anything it
// cannot prove independent runs everything, and only a change it can
// name as independent lets the database job stand down. A diff it could
// not read completely is not a shorter diff: it selects everything too.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci_classify/classify.dart';

ChangeSet _pr(List<String> paths, {bool baseKnown = true}) =>
    ChangeSet(paths: paths, baseKnown: baseKnown, event: 'pull_request');

Map<String, Verdict> _by(List<Verdict> v) => {for (final x in v) x.discipline: x};

void main() {
  test('an unknown path selects full validation', () {
    final v = _by(classify(_pr(['somewhere/new/thing.txt'])));
    expect(v['database']!.required, isTrue);
  });

  test('a classifier, workflow, script or generator change selects everything',
      () {
    for (final path in [
      'tool/ci_classify/classify.dart',
      '.github/workflows/quality.yml',
      'scripts/restore_check.sh',
      'tool/build_instance.dart',
      'pubspec.lock',
    ]) {
      final v = _by(classify(_pr([path, 'docs/ux/JOURNEYS.md'])));
      expect(v['database']!.required, isTrue, reason: path);
      expect(v['web']!.required, isTrue, reason: path);
    }
  });

  test('a missing base, an empty diff, or any event that is not a pull '
      'request runs everything', () {
    expect(_by(classify(_pr(['docs/x.md'], baseKnown: false)))['database']!.required,
        isTrue);
    expect(_by(classify(_pr(const [])))['database']!.required, isTrue);
    for (final event in ['push', 'schedule', 'workflow_dispatch']) {
      final v = _by(classify(
          ChangeSet(paths: const ['docs/x.md'], baseKnown: true, event: event)));
      expect(v['database']!.required, isTrue, reason: event);
      expect(v['web']!.required, isTrue, reason: event);
    }
  });

  test('a widget-only change proven independent stands the database job '
      'down, with the reason, and keeps the browser build', () {
    final v = _by(classify(_pr([
      'lib/features/workspace/presentation/widgets/process_card.dart',
      'test/features/workspace/process_overview_test.dart',
      'lib/l10n/_fragments/process_overview_en.arb',
      'lib/l10n/app_en.arb',
    ])));
    expect(v['database']!.required, isFalse);
    expect(v['database']!.reason, contains('independent of the database'));
    expect(v['web']!.required, isTrue);
  });

  test('an RPC adapter, a domain contract, a permission, a template, the '
      'instance bundle or a migration makes the database job required', () {
    for (final path in [
      // The consumers a later feature PR registers here: the sign-in
      // adapter, an Edge function (Deno tests run in the database job),
      // the XLSX bundle reader, a path dependency, the quality manifest.
      'lib/features/auth/data/supabase_auth_repository.dart',
      'supabase/functions/mcp-server/index.ts',
      'lib/features/workspace/domain/workspace_excel.dart',
      'packages/deskilo_push/lib/deskilo_push.dart',
      'assets/instance/contract.txt',
      'lib/features/workspace/data/supabase_workspace_repository.dart',
      'lib/features/workspace/domain/workspace_feature.dart',
      'lib/features/workspace/domain/workspace_permission.dart',
      'supabase/templates/association_fr.json',
      'assets/instance/bundle.json',
      'supabase/migrations/0245_feature_flags_expected.sql',
      'supabase/functions/create-payment-order/index.ts',
      'lib/core/instance/instance_builder.dart',
      'lib/core/backend/backend_settings.dart',
    ]) {
      final v = _by(classify(_pr([path])));
      expect(v['database']!.required, isTrue, reason: path);
      expect(v['database']!.reason, contains(path));
    }
  });

  test('a wiki or help change is not docs-only for the code job, and is '
      'independent of the database', () {
    final v = _by(classify(_pr(['docs/wiki/User-Guide.md', 'assets/help/en.md'])));
    expect(v['database']!.required, isFalse);
    // The code job always runs; the help assets are its concern.
    expect(v['web']!.required, isTrue, reason: 'assets/** reaches the browser build');
  });

  test('a lockfile or a runtime asset selects the browser build', () {
    expect(_by(classify(_pr(['pubspec.lock'])))['web']!.required, isTrue);
    expect(_by(classify(_pr(['assets/images/logo.png'])))['web']!.required, isTrue);
  });

  test('a runtime path dependency selects the browser build — `lib/**` '
      'does not cover it (#1446 R3)', () {
    // `packages/deskilo_push` is a path dependency of pubspec.yaml that
    // lib/core/push/push_providers.dart imports and instantiates. A
    // dart:io import added there breaks `flutter build web` and nothing
    // else; before this rule the verdict was `web not_applicable`.
    final v = _by(classify(_pr(['packages/deskilo_push/lib/deskilo_push.dart'])));
    expect(v['web']!.required, isTrue);
    expect(v['web']!.reason, contains('packages/deskilo_push'));
  });

  test('the web workflow asks the same classifier instead of carrying a '
      'path list of its own', () {
    // One decision, two consumers: web.yml starts on every pull request,
    // calls the composite action quality.yml calls, and the action runs
    // the one script — no second list to drift from the classifier.
    final web = File('.github/workflows/web.yml').readAsStringSync();
    final quality = File('.github/workflows/quality.yml').readAsStringSync();
    final action = File('.github/actions/classify-change/action.yml')
        .readAsStringSync();
    expect(RegExp(r'pull_request:\n\s+paths:').hasMatch(web), isFalse,
        reason: 'a `paths:` filter under pull_request is a second '
            'classifier, and it drifted once (#1446 R3)');
    expect(web, contains('uses: ./.github/actions/classify-change'));
    expect(quality, contains('uses: ./.github/actions/classify-change'));
    expect(action, contains('bash scripts/ci_classify.sh'));
    expect(web, contains(r"needs.classify.outputs.web != 'not_applicable'"),
        reason: 'only an explicit not_applicable stands the build down; '
            'a classifier that died builds');
    expect(quality,
        contains(r"needs.classify.outputs.database != 'not_applicable'"));
  });

  test('prose outside the app selects neither heavy job', () {
    final v = _by(classify(_pr(['docs/decisions/0027-x.md', 'README.md'])));
    expect(v['database']!.required, isFalse);
    expect(v['web']!.required, isFalse);
  });

  test('a rename counts both names, a space in a name is not a separator, '
      'and 300+ files are just a list', () {
    final nul = [
      'R100\u0000lib/features/a/presentation/old.dart\u0000lib/features/a/data/new.dart',
      'M\u0000docs/a file with spaces.md',
      'D\u0000web/old.js',
      for (var i = 0; i < 320; i++) 'M\u0000docs/wiki/page_$i.md',
    ].join('\u0000');
    final parsed = pathsFromNameStatus(nul);
    expect(parsed.problem, isNull);
    final paths = parsed.paths;
    expect(paths, contains('lib/features/a/data/new.dart'));
    expect(paths, contains('lib/features/a/presentation/old.dart'));
    expect(paths, contains('docs/a file with spaces.md'));
    expect(paths.length, 324);
    expect(_by(classify(_pr(paths)))['database']!.required, isTrue,
        reason: 'the rename target is an adapter');
  });

  test('a deleted adapter is still an adapter: deletion selects the '
      'database job', () {
    final paths = pathsFromNameStatus(
            'D\u0000lib/features/money/data/supabase_credit_repository.dart\u0000M\u0000docs/x.md')
        .paths;
    final v = _by(classify(_pr(paths)));
    expect(v['database']!.required, isTrue);
    expect(v['database']!.reason, contains('supabase_credit_repository'));
  });

  test('a change list cut short, or a status git does not emit, selects '
      'everything — the surviving part is not the diff', () {
    // Docs-only up to the cut: complete, this would stand the database
    // job down. Cut, it must not.
    for (final nul in [
      'M\u0000docs/x.md\u0000M',
      'M\u0000docs/x.md\u0000R100\u0000docs/old.md',
      'M\u0000docs/x.md\u0000?\u0000docs/y.md',
      'M\u0000docs/x.md\u0000junk',
    ]) {
      final parsed = pathsFromNameStatus(nul);
      expect(parsed.problem, isNotNull, reason: nul);
      final v = _by(classify(ChangeSet(
        paths: parsed.paths,
        baseKnown: true,
        event: 'pull_request',
        problem: parsed.problem,
      )));
      expect(v['database']!.required, isTrue, reason: nul);
      expect(v['web']!.required, isTrue, reason: nul);
      expect(v['database']!.reason, contains('incomplete'), reason: nul);
    }
    expect(pathsFromNameStatus('').paths, isEmpty);
    expect(pathsFromNameStatus('').problem, isNull);
  });

  test('every verdict carries the classifier version', () {
    for (final v in classify(_pr(['README.md']))) {
      expect(v.psv, endsWith('|v$classifierVersion'));
    }
  });
}
