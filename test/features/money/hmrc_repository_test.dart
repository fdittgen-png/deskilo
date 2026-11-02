// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the live HMRC port against a played function: a submission NEVER
// throws and never says "you may not file" for a failure that may have come
// after the post. A dropped connection and a bare server fault are
// UNCONFIRMED; only the function's own words are refusals.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/data/supabase_hmrc_repository.dart';
import 'package:deskilo/features/money/domain/hmrc_submission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _client = HmrcClientValues(
  browserJsUserAgent: 'ua',
  deviceId: 'd',
  timezone: 'UTC+00:00',
  screens: 's',
  windowSize: 'w',
  doNotTrack: false,
);

SupabaseHmrcRepository _repository(Future<http.Response> Function(http.Request) answer) =>
    SupabaseHmrcRepository(
      SupabaseClient(
        'https://host.example.test',
        'sb_publishable_test',
        httpClient: MockClient(answer),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

Future<HmrcOutcome> _submit(SupabaseHmrcRepository r) => r.submit(
  declarationId: 'd1',
  connectionId: 'c1',
  boxes: const {'vatDueSales': 1},
  client: _client,
);

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('a dropped connection is unconfirmed, never "not allowed"', () async {
    final outcome = await _submit(_repository((_) async => throw const SocketException('gone')));
    expect(outcome, isA<HmrcUnconfirmed>());
    expect((outcome as HmrcUnconfirmed).code, 'CLIENT');
  });

  test('a bare server fault is unconfirmed; a known function error is a refusal', () async {
    for (final status in [500, 502, 546]) {
      expect(await _submit(_repository((_) async => _json(status, {}))), isA<HmrcUnconfirmed>(), reason: '$status');
    }
    HmrcRefusal? refusal(HmrcOutcome o) => o is HmrcRefused ? o.refusal : null;
    expect(refusal(await _submit(_repository((_) async => _json(409, {'error': 'already_submitted'})))), HmrcRefusal.alreadySubmitted);
    expect(refusal(await _submit(_repository((_) async => _json(401, {'error': 'token'})))), HmrcRefusal.signInAgain);
    expect(refusal(await _submit(_repository((_) async => _json(503, {'error': 'submission_unavailable'})))), HmrcRefusal.unreachable);
    expect(refusal(await _submit(_repository((_) async => _json(403, {'error': 'x'})))), HmrcRefusal.notAllowed);
  });

  test('a success needs HMRC\'s receipt; without one it is unconfirmed', () async {
    final filed = await _submit(_repository((_) async => _json(200, {
      'status': 'filed',
      'receipt': {'formBundleNumber': '256660290587', 'processingDate': 'd'},
    })));
    expect((filed as HmrcFiled).receipt.formBundleNumber, '256660290587');
    expect(await _submit(_repository((_) async => _json(200, {'status': 'filed'}))), isA<HmrcUnconfirmed>());
  });
}
