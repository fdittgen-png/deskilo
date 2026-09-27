// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The real doctor CLI and its support boundary return truthful outcomes without echoing provider errors or argument/environment secrets.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/support_doctor.dart';

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
    expect(value['checks']['schema'], 'attention');
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
          await runSupportDoctor(() async => throw failure, out: out, err: err),
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
        expect(result.exitCode, 2);
        expect(result.stderr, contains('doctor needs --ref'));
        expect('${result.stdout}${result.stderr}', isNot(contains('PRIVATE')));
      }
    },
  );

  test('empty findings never report a successful doctor run', () async {
    expect(await runSupportDoctor(() async => [], out: _Output()), 1);
  });
}
