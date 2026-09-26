// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C5 — the timing sample does not count a cancelled job as a
// measurement, and it labels the cache state of every measured code job
// from the job's own log. Driven through the real script against a stub
// `gh` that answers the three Actions endpoints from fixtures.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Answers the three endpoints from fixtures and applies the `--jq`
/// filter (with its `--arg`s) the way `gh api` does — raw output.
const _stubGh = r'''
#!/usr/bin/env bash
shift                       # "api"
case "$1" in
  */workflows/quality.yml/runs*) file="$FIX/runs.json" ;;
  */runs/*/jobs*)  id=${1#*/runs/}; file="$FIX/jobs-${id%%/*}.json" ;;
  */jobs/*/logs)   id=${1#*/jobs/}; file="$FIX/log-${id%%/*}.txt" ;;
  *) echo "stub: unexpected $1" >&2; exit 1 ;;
esac
shift
[ -f "$file" ] || { echo "stub: no $file" >&2; exit 1; }
filter=; args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) filter="$2"; shift 2 ;;
    --arg) args+=(--arg "$2" "$3"); shift 3 ;;
    *) shift ;;
  esac
done
[ -n "$filter" ] && exec jq -r "${args[@]}" "$filter" "$file"
cat "$file"
''';

const _code = 'analyze · l10n gate · test · coverage';

String _runs(List<(int, String)> runs) =>
    '{"workflow_runs": [${runs.map((r) => '{"id": ${r.$1}, "head_sha": "abcdef0123456789", '
        '"conclusion": "${r.$2}", "run_attempt": 1}').join(',')}]}';

/// One code job of [seconds], plus a step of the same length.
String _jobs(int jobId, String conclusion, int seconds) =>
    '{"jobs": [{"id": $jobId, "name": "$_code", "conclusion": "$conclusion", '
    '"created_at": "2026-09-26T10:00:00Z", "started_at": "2026-09-26T10:00:03Z", '
    '"completed_at": "2026-09-26T10:00:${(3 + seconds).toString().padLeft(2, '0')}Z", '
    '"steps": [{"name": "Tests with coverage", "started_at": "2026-09-26T10:00:03Z", '
    '"completed_at": "2026-09-26T10:00:${(3 + seconds).toString().padLeft(2, '0')}Z"}]}]}';

late Directory _dir;

({int code, String out}) _run(Map<String, String> fixtures) {
  fixtures.forEach((n, b) => File('${_dir.path}/$n').writeAsStringSync(b));
  final r = Process.runSync('bash', ['scripts/ci_timings.sh', '3'],
      environment: {'GH': '${_dir.path}/gh', 'FIX': _dir.path, 'REPO': 'o/r'});
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('ci-timings');
    File('${_dir.path}/gh').writeAsStringSync(_stubGh);
    Process.runSync('chmod', ['+x', '${_dir.path}/gh']);
  });
  tearDown(() => _dir.deleteSync(recursive: true));

  test('a cancelled job is listed, counted as such, and measured by nothing; '
      'the cache state comes from each measured job\'s log', () {
    final r = _run({
      'runs.json': _runs([(1, 'success'), (2, 'cancelled'), (3, 'success')]),
      'jobs-1.json': _jobs(11, 'success', 40),
      'jobs-2.json': _jobs(22, 'cancelled', 5),
      'jobs-3.json': _jobs(33, 'success', 50),
      'log-11.txt': 'Cache hit for: flutter-linux-stable\nCache hit for: pub-Linux-3\n',
      'log-33.txt': 'Cache not found for input keys: flutter-linux\n'
          'Cache hit for restore-key: pub-Linux-3\n',
    });
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('sample: 3 completed'));
    expect(r.out, contains('2 abcdef012 cancelled attempt 1'));
    // n = 2 measured, 2 successes, 1 cancelled; p50 over {40, 50} is 50
    // with the rounding rule of the script — never the cancelled 5.
    expect(r.out, contains('| $_code | 2 | 2 | 1 | 3s | 3s | 50s | 50s |'));
    expect(r.out, contains('1 abcdef012 success attempt 1  sdk:hit pub:exact'));
    expect(r.out, contains('3 abcdef012 success attempt 1  sdk:miss pub:partial'));
    expect(r.out, contains('sdk:hit pub:exact: 40s (n=1)'));
    expect(r.out, contains('sdk:miss pub:partial: 50s (n=1)'));
    expect(r.out, contains('Tests with coverage: 50s (n=2)'),
        reason: 'the cancelled job\'s step is not a step measurement either');
  });

  test('a log that cannot be read is an unknown state, not a warm one', () {
    final r = _run({
      'runs.json': _runs([(1, 'success')]),
      'jobs-1.json': _jobs(11, 'success', 40),
    });
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('1 abcdef012 success attempt 1  sdk:? pub:?'));
  });
}
