// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3751 -- the database preview says what `quality · database` will say only
// while it runs the SAME replay and the SAME three checks. A check edited in
// one workflow and not in the other would turn the preview into a second
// opinion; this keeps the two step for step.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

YamlMap _yaml(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

List<YamlMap> _steps(String workflow, String job) =>
    (((_yaml('.github/workflows/$workflow.yml')['jobs'] as YamlMap)[job]
                as YamlMap)['steps']
            as YamlList)
        .cast<YamlMap>();

YamlMap _named(List<YamlMap> steps, String name) =>
    steps.singleWhere((s) => s['name'] == name);

String _run(YamlMap step) => '${step['run'] ?? ''}';

const _toolchain = [
  './.github/actions/supabase-cli',
  './.github/actions/deno',
  './.github/actions/local-stack',
];

void main() {
  final preview = _steps('db-preview', 'preview');
  final gate = _steps('quality', 'database');

  test('the same toolchain and the same replay, in the same order', () {
    List<String> uses(List<YamlMap> steps) => [
      for (final s in steps)
        if (_toolchain.contains(s['uses']) &&
            (s['with'] as YamlMap?)?['workdir'] == null)
          '${s['uses']}',
    ];
    expect(uses(preview), _toolchain);
    expect(uses(gate), _toolchain);
  });

  test('the policy check is the one of the Quality run, word for word', () {
    const name = 'Policies equal the migrations';
    expect(_run(_named(preview, name)), _run(_named(gate, name)));
  });

  test('the contract is read by the same script', () {
    const call = r'bash scripts/contract_check.sh "$DB_URL"';
    expect(_run(_named(preview, 'Effective contract')), call);
    expect(_run(_named(gate, 'Effective contract')), contains(call));
  });

  test('the database tests are the same two commands', () {
    for (final steps in [preview, gate]) {
      final run = _run(_named(steps, 'Database disciplines'));
      expect(run, contains('set -o pipefail'));
      expect(run, contains('supabase test db 2>&1'));
      expect(
        run,
        contains(r'python3 -B scripts/workspace_alignment_check.py "$DB_URL"'),
      );
    }
  });

  test('every check runs on the replayed stack and reports to the verdict',
      () {
    for (final name in const [
      'Policies equal the migrations',
      'Effective contract',
      'Database disciplines',
    ]) {
      final step = _named(preview, name);
      expect(step['if'], "steps.migrations.outcome == 'success'", reason: name);
      expect(step['continue-on-error'], isTrue, reason: name);
      expect(
        (step['env'] as YamlMap)['DB_URL'],
        r'${{ steps.migrations.outputs.db-url }}',
        reason: name,
      );
    }
    final verdict = _named(preview, 'Verdict');
    expect(verdict['if'], 'always()');
    expect(_run(verdict), 'bash scripts/db_preview_verdict.sh');
    expect((verdict['env'] as YamlMap).keys, [
      'REPLAY',
      'POLICIES',
      'CONTRACT',
      'PGTAP',
    ]);
  });

  test('it is started on purpose and gates nothing', () {
    final w = _yaml('.github/workflows/db-preview.yml');
    // `on` parses as the boolean true in YAML 1.1 readers; accept both keys.
    final on = (w['on'] ?? w[true]) as YamlMap;
    expect(on.keys, ['workflow_dispatch']);
    expect((w['concurrency'] as YamlMap)['cancel-in-progress'], isFalse);
    expect((w['permissions'] as YamlMap).keys, ['contents']);
    expect((w['permissions'] as YamlMap)['contents'], 'read');
  });
}
