// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3916 -- the app's address for the functions that link back to the app: the
// builder sets `DESKILO_APP_URL` from the instance's own web base, the doctor
// says when a deployed function that needs it has none or another address,
// and no value is ever printed.
import 'dart:io';

import 'package:deskilo/core/instance/app_url_setting.dart';
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/instance.dart' as cli;
import '../../helpers/fake_supabase_management.dart';

const _ref = 'ref1xxxxxxxxxxxxxxxx';
const _site = 'https://www.deskilo.org/app/';
const _bundle = InstanceBundle(
  schema: [(name: '0001_initial.sql', sql: 'select 1;')],
  functions: [],
);

class _Refusing extends FakeSupabaseManagement {
  @override
  Future<void> setFunctionSecrets(
    String ref,
    Map<String, String> values,
  ) async => throw const ManagementApiException(403, 'not allowed');
}

List<DoctorFinding> _appUrl(List<DoctorFinding> all) => all
    .where(
      (f) =>
          f.words == DoctorWords.appUrlMissing ||
          f.words == DoctorWords.appUrlForeign,
    )
    .toList();

void main() {
  group('the builder sets the app address from the instance\'s own web base', () {
    test('the value sent is the web base the sign-in settings name', () async {
      final api = FakeSupabaseManagement();
      final patch = InstanceAuthConfig.patchForWebBase(
        Uri.parse('$_site?temporary=x#route'),
      );
      await InstanceBuilder(api).configureAppUrl(_ref, authPatch: patch);
      expect(api.functionSecrets[_ref], {
        appUrlSetting: 'https://www.deskilo.org/app',
      });
    });

    test('without an explicit web base the default one is sent', () async {
      final api = FakeSupabaseManagement();
      await InstanceBuilder(api).configureAppUrl(_ref);
      expect(api.functionSecrets[_ref], {
        appUrlSetting: InstanceAuthConfig.siteUrl.replaceAll(
          RegExp(r'/+$'),
          '',
        ),
      });
    });

    test('the install and the auth command set it, from the web base they were given', () async {
      for (final command in ['install', 'auth']) {
        final api = FakeSupabaseManagement();
        final out = <String>[];
        await IOOverrides.runZoned(() async {
          expect(
            await cli.run(
              [command, '--token', 'dummy', '--ref', _ref, '--site-url', _site],
              apiOverride: api,
              bundleLoader: () => _bundle,
            ),
            0,
          );
        }, stdout: () => _Capture(out));
        expect(
          api.functionSecrets[_ref]![appUrlSetting],
          'https://www.deskilo.org/app',
          reason: command,
        );
        // The line about the setting names it and never carries its value.
        final about = out
            .join()
            .split('\n')
            .where((l) => l.contains(appUrlSetting))
            .toList();
        expect(about, isNotEmpty, reason: command);
        expect(
          about.any((l) => l.contains('deskilo.org')),
          isFalse,
          reason: command,
        );
      }
    });

    test('a refusal names the setting and never the value', () async {
      final failure = await InstanceBuilder(_Refusing())
          .configureAppUrl(
            _ref,
            authPatch: InstanceAuthConfig.patchForWebBase(Uri.parse(_site)),
          )
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(failure, isA<InstanceStepFailure>());
      final text =
          '${(failure! as InstanceStepFailure).item} ${(failure as InstanceStepFailure).message}';
      expect(text, contains(appUrlSetting));
      expect(text.contains('deskilo.org'), isFalse);
    });
  });

  group('the doctor reports the app address of the functions that need it', () {
    final own = InstanceAuthConfig.patchForWebBase(Uri.parse(_site));

    Future<List<DoctorFinding>> examine(
      FakeSupabaseManagement api, {
      List<String> functions = const ['deskilo-mcp', 'accounting-connect'],
    }) async {
      api.existingFunctions[_ref] = functions;
      return _appUrl(
        await InstanceDoctor(api, expectedAuth: own).examine(_ref),
      );
    }

    test('none set: a finding naming the functions', () async {
      final findings = await examine(FakeSupabaseManagement());
      expect(findings.single.words, DoctorWords.appUrlMissing);
      expect(findings.single.level, DoctorLevel.warn);
      expect(
        findings.single.detail,
        contains('accounting-connect, deskilo-mcp'),
      );
      expect(findings.single.detail, contains('--site-url'));
    });

    test('another address: an alarm that carries no value', () async {
      final api = FakeSupabaseManagement()
        ..functionSecrets[_ref] = {
          appUrlSetting: 'https://elsewhere.example/app',
        };
      final findings = await examine(api);
      expect(findings.single.words, DoctorWords.appUrlForeign);
      expect(findings.single.level, DoctorLevel.alarm);
      expect('${findings.single}'.contains('elsewhere'), isFalse);
    });

    test(
      'the instance\'s own address, with or without its slash: no finding',
      () async {
        for (final value in ['https://www.deskilo.org/app', _site]) {
          final api = FakeSupabaseManagement()
            ..functionSecrets[_ref] = {appUrlSetting: value};
          expect(await examine(api), isEmpty, reason: value);
        }
      },
    );

    test('no function that needs it is deployed: no finding', () async {
      expect(
        await examine(
          FakeSupabaseManagement(),
          functions: const ['push-notify'],
        ),
        isEmpty,
      );
      expect(
        await examine(FakeSupabaseManagement(), functions: const []),
        isEmpty,
      );
    });

    test('one needing function is enough, and only it is named', () async {
      final findings = await examine(
        FakeSupabaseManagement(),
        functions: const ['accounting-connect'],
      );
      expect(findings.single.detail, contains('accounting-connect'));
      expect(findings.single.detail.contains('deskilo-mcp'), isFalse);
    });

    test('an API that lists the value itself is compared by digest', () {
      final findings = checkAppUrl(
        deployed: const ['deskilo-mcp'],
        digests: {appUrlSetting: 'https://www.deskilo.org/app'},
        webBase: _site,
      );
      expect(findings, isEmpty);
    });
  });

  test(
    'the functions named are exactly the ones whose source reads the setting',
    () {
      final reading = <String>[
        for (final dir in Directory(
          'supabase/functions',
        ).listSync().whereType<Directory>())
          if (dir
              .listSync(recursive: true)
              .whereType<File>()
              .any(
                (f) =>
                    f.path.endsWith('.ts') &&
                    !f.path.endsWith('_test.ts') &&
                    f.readAsStringSync().contains(appUrlSetting),
              ))
            dir.path.split('/').last,
      ]..sort();
      expect(reading, appUrlFunctions);
    },
  );
}

class _Capture implements Stdout {
  _Capture(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = '']) => lines.add('$object\n');

  @override
  void write(Object? object) => lines.add('$object');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
