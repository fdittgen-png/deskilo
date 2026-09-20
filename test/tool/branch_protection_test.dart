// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 R1a — the protection checker's own red controls.
//
// `scripts/branch_protection.sh` could only say two things: it printed
// "(none — the branch is unprotected)" for any answer it failed to
// parse, and `verify` warned and exited 0 when the token could not read
// protection at all — so a green advisory step was citable as proof the
// settings were right while nothing had been looked at, which is how
// four pull requests merged with `quality · database` red. Three facts,
// three results: verified-match (0), verified-drift (1),
// unverified-access (2). These drive the REAL script against a stub API
// answering 200, 404, 403 and no-answer; nothing here touches a setting,
// the stub only records the body that would have been sent.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The stub `gh`: answers `api <path>` from [_dir], and records an
/// `api -X PATCH|PUT` body instead of sending it.
const _stubGh = r'''
#!/usr/bin/env bash
shift                       # "api"
if [ "$1" = "-X" ]; then cat > "$FIX/$2.body"; echo '{}'; exit 0; fi
case "$1" in
  */required_status_checks) key=checks ;;
  */protection)             key=protection ;;
  */check-runs)             key=checkruns ;;
  *)                        echo "stub: unexpected $1" >&2; exit 1 ;;
esac
[ ! -f "$FIX/$key.json" ] || { cat "$FIX/$key.json"; exit 0; }
[ ! -f "$FIX/$key.err" ] || { cat "$FIX/$key.err" >&2; exit 1; }
echo "gh: Not Found (HTTP 404)" >&2; exit 1
''';

const _code = 'analyze · l10n gate · test · coverage';
const _db = 'quality · database';
const _report = 'quality · report';
const _denied = 'gh: Resource not accessible by integration (HTTP 403)';

/// A protection object requiring [contexts], as GitHub returns one.
String _protection(List<String> contexts, {bool strict = false}) =>
    '{"required_status_checks": {"strict": $strict, "checks": ['
    '${contexts.map((c) => '{"context": "$c", "app_id": null}').join(',')}], '
    '"contexts": [${contexts.map((c) => '"$c"').join(',')}]}, '
    '"required_pull_request_reviews": {"required_approving_review_count": 1}, '
    '"enforce_admins": {"enabled": false}}';

late Directory _dir;

/// Writes fixture [files] (name → content) and runs the real script.
({int code, String out}) run(
  List<String> args, {
  Map<String, String> files = const {},
}) {
  files.forEach(
      (name, body) => File('${_dir.path}/$name').writeAsStringSync(body));
  final r = Process.runSync('bash', ['scripts/branch_protection.sh', ...args],
      environment: {'GH': '${_dir.path}/gh', 'FIX': _dir.path});
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('branch-protection');
    File('${_dir.path}/gh').writeAsStringSync(_stubGh);
    Process.runSync('chmod', ['+x', '${_dir.path}/gh']);
  });
  tearDown(() => _dir.deleteSync(recursive: true));

  test('settings that match are verified-match, and a context this file does '
      'not name is not drift', () {
    final r = run(['verify'],
        files: {'protection.json': _protection([_code, _db, _report])});
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('result=verified-match'));

    // An extra live context is kept by apply-checks, never called drift.
    final extra = run(['verify'], files: {
      'protection.json': _protection([_code, _db, _report, 'legal · licence']),
    });
    expect(extra.code, 0, reason: extra.out);
  });

  test('a required check missing from the live object is verified-drift', () {
    // The 2026-09-20 baseline exactly: one context required, two merged red.
    final r = run(['verify'], files: {'protection.json': _protection([_code])});
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('result=verified-drift'));
    expect(r.out, contains('MISSING from live protection: $_db'));
    expect(r.out, contains('MISSING from live protection: $_report'));
  });

  test('an unprotected branch is verified-drift — it was READ', () {
    // No protection.json and no protection.err: the stub answers HTTP 404.
    final r = run(['verify']);
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('result=verified-drift'));
    expect(r.out, contains('has NO branch protection'));
  });

  test('a 403 and a transport failure are unverified-access, exit 2, and '
      'neither reads as unprotected', () {
    final denied = run(['verify'], files: {'protection.err': _denied});
    expect(denied.code, 2, reason: 'a token that cannot look is not a verdict');
    expect(denied.out, contains('result=unverified-access'));
    expect(denied.out, contains('HTTP 403'));
    expect(denied.out, isNot(contains('NO branch protection')));

    final down = run(['verify'], files: {
      'protection.err': 'error connecting to api.github.com: dial tcp: no host'
    });
    expect(down.code, 2, reason: down.out);
    expect(down.out, contains('result=unverified-access'));
    expect(down.out, isNot(contains('NO branch protection')));
  });

  test('advisory exits 0 but still publishes the unverified result', () {
    final r = run(['verify', '--advisory'], files: {'protection.err': _denied});
    expect(r.code, 0, reason: 'the CI step must not block');
    expect(r.out, contains('result=unverified-access'),
        reason: 'a zero exit with no result line is citable as settings proof');
    expect(r.out, contains("only 'verified-match' is settings proof"));
  });

  test('show calls an unreadable response unreadable, not unprotected', () {
    final r = run(['show'], files: {'protection.err': _denied});
    expect(r.code, 2, reason: r.out);
    expect(r.out, contains('UNREADABLE'));
    expect(r.out, contains("NOT 'unprotected'"));
    expect(r.out, isNot(contains('(none')));

    // The other half: a READ 404 still says unprotected, and names the
    // contexts actually reported, which is how a context name is confirmed.
    File('${_dir.path}/protection.err').deleteSync();
    final none = run(['show'],
        files: {'checkruns.json': '{"check_runs": [{"name": "$_code"}]}'});
    expect(none.code, 0, reason: none.out);
    expect(none.out, contains('I READ the branch and it is unprotected'));
    expect(none.out, contains(_code));
  });

  test('apply-checks ADDS to the live list: extras, app bindings, strictness',
      () {
    final r = run(['apply-checks'], files: {
      'checks.json': '{"strict": true, "contexts": ["legal · licence"], '
          '"checks": [{"context": "legal · licence", "app_id": 15368}, '
          '{"context": "$_code", "app_id": 15368}]}',
      'protection.json':
          _protection([_code, _db, _report, 'legal · licence'], strict: true),
    });
    final body = File('${_dir.path}/PATCH.body').readAsStringSync();
    expect(body, contains('"context":"legal · licence","app_id":15368'),
        reason: 'a context nobody here owns must survive, binding and all');
    expect(body, contains('"context":"$_code","app_id":15368'),
        reason: 'the app binding of an existing context must not be dropped');
    expect(body, contains('"context":"$_db"'));
    expect(body, contains('"context":"$_report"'));
    expect(body, contains('"strict":true'), reason: 'live strict is kept');
    expect(r.out, contains('kept live strict=true'));
  });

  test('apply-checks writes nothing when it could not read the live list', () {
    final r = run(['apply-checks'], files: {'checks.err': _denied});
    expect(r.code, 2, reason: r.out);
    expect(r.out, contains('result=unverified-access'));
    expect(File('${_dir.path}/PATCH.body').existsSync(), isFalse,
        reason: 'a list built from an unread response must not be sent');
  });

  test('apply refuses to PUT over protection somebody expanded', () {
    final r = run(['apply'],
        files: {'protection.json': _protection([_code, 'legal · licence'])});
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('already protected'));
    expect(r.out, contains('apply-checks'));
    expect(File('${_dir.path}/PUT.body').existsSync(), isFalse,
        reason: 'the review rule and the extra context would have been reset');
  });

  test('apply refuses to PUT over a configuration it could not read', () {
    final r = run(['apply'], files: {'protection.err': _denied});
    expect(r.code, 2, reason: r.out);
    expect(r.out, contains('result=unverified-access'));
    expect(File('${_dir.path}/PUT.body').existsSync(), isFalse);
  });
}
