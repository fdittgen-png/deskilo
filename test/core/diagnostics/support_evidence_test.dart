// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Release evidence exports only known bounded counters; malformed or private source fields never become healthy diagnostics.
import 'dart:convert';

import 'package:deskilo/core/diagnostics/support_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/instance/support_doctor.dart';

void main() {
  Map<String, Object?> fixture() => {
    'schema_version': 1,
    'capabilities': [
      {
        'status': 'shipped',
        'prerequisites': 'PRIVATE-SECRET',
        'private': {'token': 'PRIVATE-SECRET'},
        'scopes': {
          for (final scope in SupportEvidence.scopes) scope: 'unverified',
        },
      },
    ],
  };
  test('release evidence projects only bounded scope/standing counts', () {
    final result = SupportEvidence.parse(jsonEncode(fixture()))!;
    final out = jsonEncode(result.toJson());
    expect(out, isNot(contains('PRIVATE')));
    expect(result.toJson()['runtimeVerification'], 'unavailable');
    expect((result.toJson()['scopes'] as Map)['unit'], {
      'gated': 0,
      'recorded': 0,
      'stale': 0,
      'unverified': 1,
    });
  });
  test('unknown contract, status, scopes, malformed and oversized input are unavailable', () {
    final unknown = fixture();
    ((unknown['capabilities'] as List).first as Map)['status'] = 'healthy';
    for (final source in [
      'not JSON PRIVATE',
      '[]',
      '{}',
      jsonEncode(unknown),
      jsonEncode({...fixture(), 'schema_version': 2}),
      jsonEncode({
        'schema_version': 1,
        'capabilities': [
          {
            'status': 'shipped',
            'scopes': {'unknown': 'ok'},
          },
        ],
      }),
      List.filled(SupportEvidence.maxSourceBytes + 1, 'x').join(),
    ]) {
      expect(SupportEvidence.parse(source), isNull);
    }
  });
  test(
    'existing release artifact is consumed through the safe projection',
    () async {
      final evidence = await loadSupportEvidence();
      expect(evidence, isNotNull);
      expect(evidence!.toJson()['contractVersion'], 1);
    },
  );
}
