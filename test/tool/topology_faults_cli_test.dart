// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L2 -- the argument handling of `scripts/topology_stacks.sh fault`,
// on a dry run (TOPOLOGY_DRY_RUN=1 prints the checks and docker commands
// instead of running them). The physical effect of each mode is proved by
// test/topology/topology_faults_test.dart in the database job only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

ProcessResult _fault(List<String> args) => Process.runSync(
  'bash',
  ['scripts/topology_stacks.sh', 'fault', ...args],
  environment: {'TOPOLOGY_DRY_RUN': '1'},
);

List<String> _commands(ProcessResult r) => [
  for (final line in '${r.stdout}'.split('\n'))
    if (line.startsWith('+ ')) line.substring(2),
];

String _waProject() => RegExp(
  r'^project_id = "(.*)"$',
  multiLine: true,
).firstMatch(File('supabase/config.toml').readAsStringSync())!.group(1)!;

void main() {
  test('stall pauses the gateway of the named stack, after checking it is '
      'this job\'s', () {
    final r = _fault(['stall', 'wa']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final kong = 'supabase_kong_${_waProject()}';
    expect(_commands(r), [
      'verify $kong project=${_waProject()} port=54321',
      'docker pause $kong',
    ]);
  });

  test('block stops both workspace gateways for w, P untouched', () {
    final r = _fault(['block', 'w']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final commands = _commands(r);
    expect(commands.where((c) => c.startsWith('docker ')), [
      'docker stop -t 2 supabase_kong_${_waProject()}',
      'docker stop -t 2 supabase_kong_deskilo_topology_wb',
    ]);
    expect(commands.join('\n'), isNot(contains('deskilo_topology_p')));
    // Each action is preceded by the identity check of its own container.
    expect(
      commands.indexOf(
        'verify supabase_kong_deskilo_topology_wb '
        'project=deskilo_topology_wb port=54521',
      ),
      lessThan(
        commands.indexOf('docker stop -t 2 supabase_kong_deskilo_topology_wb'),
      ),
    );
  });

  test('restore brings every gateway back and waits for its port', () {
    final r = _fault(['restore', 'all']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final commands = _commands(r);
    for (final (kong, port) in [
      ('supabase_kong_deskilo_topology_p', 54421),
      ('supabase_kong_${_waProject()}', 54321),
      ('supabase_kong_deskilo_topology_wb', 54521),
    ]) {
      expect(
        commands,
        containsAllInOrder([
          'docker unpause $kong',
          'docker start $kong',
          'wait http://127.0.0.1:$port',
        ]),
      );
    }
  });

  test('the P stack is a target of its own', () {
    final r = _fault(['stall', 'p']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(_commands(r).last, 'docker pause supabase_kong_deskilo_topology_p');
  });

  test('an unknown mode or target, or none, is refused before any command', () {
    for (final args in [
      ['stall', 'wc'],
      ['kill', 'wa'],
      ['stall'],
      <String>[],
      ['stall', 'WA'],
    ]) {
      final r = _fault(args);
      expect(r.exitCode, 2, reason: '$args');
      expect(_commands(r), isEmpty, reason: '$args');
      expect('${r.stderr}', contains('usage:'), reason: '$args');
    }
  });

  test('#2472 C2 facts names a workspace source at P, and refuses anything '
      'else before any command', () {
    ProcessResult facts(List<String> args) => Process.runSync(
      'bash',
      ['scripts/topology_stacks.sh', 'facts', ...args],
      environment: {'TOPOLOGY_DRY_RUN': '1'},
    );
    final both = facts(['lapse', 'w']);
    expect(both.exitCode, 0, reason: '${both.stderr}');
    expect(_commands(both), ['facts lapse wa at P', 'facts lapse wb at P']);
    final one = facts(['fresh', 'wb']);
    expect(_commands(one), ['facts fresh wb at P']);
    for (final args in [
      ['lapse', 'p'],
      ['lapse', 'all'],
      ['expire', 'wa'],
      ['fresh'],
      <String>[],
    ]) {
      final r = facts(args);
      expect(r.exitCode, 2, reason: '$args');
      expect(_commands(r), isEmpty, reason: '$args');
      expect('${r.stderr}', contains('usage:'), reason: '$args');
    }
  });

  test('the ports the fault checks are the ones prepare writes', () {
    final script = File('scripts/topology_stacks.sh').readAsStringSync();
    expect(script, contains(r'for spec in p:$P_BASE wb:$WB_BASE; do'));
    expect(script, contains(r'port = $((base + 1))'));
    expect(script, contains(r'p) echo $((P_BASE + 1)) ;;'));
    expect(script, contains(r'wb) echo $((WB_BASE + 1)) ;;'));
  });
}
