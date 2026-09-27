// SPDX-License-Identifier: AGPL-3.0-or-later
// Projection prevents sensitive source values from reaching exact export bytes.
import 'dart:convert';

import 'package:deskilo/core/diagnostics/support_bundle.dart';
import 'package:deskilo/core/diagnostics/doctor_support.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 27);
  test('doctor projection excludes unknown fields and arbitrary error details', () {
    const canary =
        'secret@example.org token=SECRET /Users/private/file https://private/?signed=KEY 名字\r\nINJECT';
    final bundle = doctorSupportBundle([
      const DoctorFinding(DoctorLevel.ok, 'Site URL', canary, count: 987654321),
      const DoctorFinding(DoctorLevel.alarm, 'Schema', canary),
      const DoctorFinding(DoctorLevel.ok, canary, canary),
    ], now);
    expect(bundle.preview, isNot(contains(canary)));
    expect(bundle.preview, isNot(contains('987654321')));
    expect(utf8.decode(bundle.bytes), bundle.preview);
    final value = jsonDecode(bundle.preview) as Map<String, dynamic>;
    expect(value.keys.toSet(), {
      'format',
      'version',
      'mode',
      'platform',
      'appVersion',
      'requiredSchemaVersion',
      'schemaVersion',
      'window',
      'clientAlias',
      'checks',
      'localEventCounts',
      'excludes',
    });
    expect(value['localEventCounts'], isNull);
    expect(value['checks'], {
      'schema': 'attention',
      'siteUrl': 'ok',
      'redirects': 'unavailable',
      'emailConfirmation': 'unavailable',
      'doctor': 'unavailable',
    });
    expect(bundle.bytes.length, lessThanOrEqualTo(SupportBundle.maxBytes));
  });
  test(
    'unknown versions are absent and caller mutation cannot change a preview',
    () {
      final counts = {SupportSeverity.error: 999999};
      final bundle = SupportBundle(
        from: now,
        until: now,
        mode: SupportMode.local,
        platform: SupportPlatform.linux,
        appVersion: '1.2.3+secret',
        schemaVersion: -1,
        eventCounts: counts,
      );
      counts[SupportSeverity.error] = 1;
      final value = jsonDecode(bundle.preview) as Map<String, dynamic>;
      expect(value['appVersion'], isNull);
      expect(value['schemaVersion'], isNull);
      expect(value['localEventCounts'], {
        'debug': 0,
        'info': 0,
        'warn': 0,
        'error': 500,
      });
      final bytes = bundle.bytes;
      bytes[0] = 0;
      expect(utf8.decode(bundle.bytes), bundle.preview);
    },
  );
  test(
    'table-driven private fields and long injection payloads stay absent',
    () {
      final canaries = [
        'Authorization: Bearer PRIVATE-TOKEN',
        '{"nested":{"password":"PRIVATE-PASSWORD","mfa":"PRIVATE-FACTOR"}}',
        'member=PRIVATE-NAME email=private@example.org invoice=987654.32',
        'https://private.example/file?signature=PRIVATE-SIGNED',
        'invite=PRIVATE-INVITE /Users/private/desktop/file',
        '秘密 имя PRIVATE-ID\r\nforged: healthy',
        List.filled(20000, 'PRIVATE-LONG').join(),
      ];
      for (final canary in canaries) {
        final bundle = doctorSupportBundle([
          DoctorFinding(DoctorLevel.ok, canary, canary),
          DoctorFinding(DoctorLevel.warn, 'Schema is behind', canary),
        ], now);
        expect(bundle.preview, isNot(contains(canary)));
        expect(bundle.preview, isNot(contains('PRIVATE')));
        expect(bundle.bytes.length, lessThanOrEqualTo(SupportBundle.maxBytes));
        expect(utf8.decode(bundle.bytes), bundle.preview);
      }
    },
  );
  test('window bounds and contradictory findings fail conservatively', () {
    expect(
      () => SupportBundle(
        from: now,
        until: now.add(const Duration(hours: 25)),
        mode: SupportMode.local,
        platform: SupportPlatform.unknown,
      ),
      throwsArgumentError,
    );
    expect(
      () => SupportBundle(
        from: now,
        until: now.subtract(const Duration(seconds: 1)),
        mode: SupportMode.local,
        platform: SupportPlatform.unknown,
      ),
      throwsArgumentError,
    );
    final bundle = doctorSupportBundle([
      const DoctorFinding(DoctorLevel.alarm, 'Site URL', 'private'),
      const DoctorFinding(DoctorLevel.ok, 'Site URL', 'private'),
    ], now);
    expect(bundle.preview, contains('"siteUrl": "attention"'));
  });
}
