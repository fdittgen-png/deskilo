// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The real doctor CLI and its support boundary return truthful outcomes without echoing provider errors or argument/environment secrets.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/support_doctor.dart';

/// The secrets the CLI test hands the child, by argument and by environment.
const _childSecrets = ['PRIVATE-ARG-TOKEN', 'PRIVATE-ENV-TOKEN'];

/// Token-shaped values a child could print besides the known ones: a JWT, a
/// Supabase personal or service key, a bearer value, a long opaque run.
final _tokenShaped = RegExp(
  r'eyJ[\w-]+\.[\w-]+\.[\w-]+'
  r'|\bsb[ps]_[\w-]+'
  r'|(?<=Bearer )\S+'
  r'|\b[A-Za-z0-9_-]{40,}\b',
);

/// #3467 — the child's output, safe to print in a failure reason: every known
/// secret and every token-shaped value is replaced before anything is
/// formatted. The `PRIVATE` assertion below is a check, not this.
String sanitizeChildOutput(
  String text, {
  List<String> secrets = _childSecrets,
}) {
  var out = text;
  for (final s in secrets) {
    out = out.replaceAll(s, '<redacted>');
  }
  return out.replaceAll(_tokenShaped, '<redacted>');
}

/// What a wrong exit code is explained by: the child's sanitized streams.
String childReport(ProcessResult r) =>
    'child exited ${r.exitCode}\n'
    'stdout: ${sanitizeChildOutput('${r.stdout}')}\n'
    'stderr: ${sanitizeChildOutput('${r.stderr}')}';

class _Output implements IOSink {
  final text = StringBuffer();
  @override
  void writeln([Object? value = '']) => text.writeln(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('doctor findings produce JSON without their private details', () async {
    final out = _Output();
    final err = _Output();
    expect(
      await runSupportDoctor(
        () async => const [
          DoctorFinding(
            DoctorLevel.warn,
            'Schema is behind',
            'private project',
          ),
        ],
        out: out,
        err: err,
      ),
      1,
    );
    final value = jsonDecode(out.text.toString()) as Map<String, dynamic>;
    expect((value['checks'] as Map)['schema'], 'attention');
    expect(out.text.toString(), isNot(contains('private')));
    expect(err.text.isEmpty, isTrue);
  });

  test(
    'auth, malformed and unexpected failures cannot leak to either stream',
    () async {
      for (final failure in [
        const ManagementApiException(401, 'secret@example.com TOKEN'),
        const FormatException('secret@example.com TOKEN'),
        StateError('secret@example.com TOKEN'),
      ]) {
        final out = _Output();
        final err = _Output();
        expect(
          await runSupportDoctor(
            () async =>
                failure is Error ? throw failure : throw failure as Exception,
            out: out,
            err: err,
          ),
          1,
        );
        expect(err.text.toString(), 'support_unavailable\n');
        expect(out.text.toString(), isNot(contains('secret')));
        final value = jsonDecode(out.text.toString()) as Map<String, dynamic>;
        expect((value['checks'] as Map).values.toSet(), {'unavailable'});
      }
    },
  );

  test(
    'real CLI rejects missing and empty targets without echoing argv or env',
    () async {
      for (final args in [
        <String>[],
        ['--ref', ''],
      ]) {
        final result = await Process.run(
          'dart',
          [
            'run',
            'tool/instance.dart',
            'doctor',
            '--support-json',
            '--token',
            'PRIVATE-ARG-TOKEN',
            ...args,
          ],
          environment: {'SUPABASE_ACCESS_TOKEN': 'PRIVATE-ENV-TOKEN'},
        );
        final report = childReport(result);
        expect(result.exitCode, 2, reason: report);
        expect(
          sanitizeChildOutput('${result.stderr}'),
          contains('doctor needs --ref'),
          reason: report,
        );
        expect(
          '${result.stdout}${result.stderr}'.contains('PRIVATE'),
          isFalse,
          reason: report,
        );
      }
    },
  );

  test('a failing exit check prints the child output with its secrets '
      'redacted', () {
    final result = ProcessResult(
      0,
      254,
      'PRIVATE-ARG-TOKEN sbp_0123456789abcdef',
      'Bearer PRIVATE-ENV-TOKEN eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl '
          'snapshot failed',
    );
    final report = childReport(result);
    final failure = _failureOf(
      () => expect(result.exitCode, 2, reason: report),
    );
    expect(failure, contains('child exited 254'));
    expect(failure, contains('snapshot failed'));
    expect(failure, contains('<redacted>'));
    for (final secret in ['PRIVATE', 'sbp_0123456789abcdef', 'eyJhbGciOi']) {
      expect(failure, isNot(contains(secret)));
    }
  });

  test('a forced dart run failure shows its error text', () async {
    final result = await Process.run(
      'dart',
      ['run', 'tool/does_not_exist.dart'],
      environment: {'SUPABASE_ACCESS_TOKEN': 'PRIVATE-ENV-TOKEN'},
    );
    final failure = _failureOf(
      () => expect(result.exitCode, 2, reason: childReport(result)),
    );
    expect(failure, contains('does_not_exist.dart'));
    expect(failure, isNot(contains('PRIVATE')));
  });

  test('empty findings never report a successful doctor run', () async {
    expect(await runSupportDoctor(() async => [], out: _Output()), 1);
  });
}

/// The message of the TestFailure [check] throws; fails if it passes.
String _failureOf(void Function() check) {
  try {
    check();
  } on TestFailure catch (e) {
    return e.message ?? '';
  }
  fail('the exit-code check was expected to fail');
}
