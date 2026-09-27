// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1642 — the support bundle is an allow-list projection: canaries seeded
// in every excluded category (tokens, keys, passwords, e-mails, names,
// amounts, invite codes, signed URLs, paths, raw payloads, CRLF log
// injection) must not appear anywhere in the bytes, and an unknown
// status never reads healthy.
import 'dart:convert';

import 'package:deskilo/core/support/support_bundle.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 9, 27, 10);

const _canaries = [
  'eyJhbGciOiJIUzI1NiJ9.CANARYJWT',
  'sk_live_CANARYKEY',
  'hunter2-CANARY-password',
  'canary.person@example.org',
  'Élodie Canary-Nom',
  '4242.42',
  'INVITE-CANARY-CODE',
  'https://x.supabase.co/storage/v1/object/sign/a.pdf?token=CANARYSIG',
  '/Users/canary-home/secret.txt',
  '{"raw":"CANARY-PAYLOAD"}',
  'zwzbynivewivvjmripeb',
];

TraceEntry _e(
  String message, {
  String? error,
  String area = 'money',
  TraceLevel level = TraceLevel.error,
  Duration after = const Duration(minutes: 5),
}) => TraceEntry(
  ts: _t0.add(after),
  level: level,
  area: area,
  message: message,
  error: error,
  stack:
      '#0 main (file:///Users/canary-home/app.dart:1)\n${_canaries.join('\n')}',
);

SupportBundle _build({
  List<TraceEntry> traces = const [],
  Map<String, bool> features = const {},
  Map<String, String> checks = const {},
  bool includeBackendHost = false,
  String appVersion = '1.4.0+1612',
  String platform = 'android',
}) => buildSupportBundle(
  SupportBundleInput(
    createdAt: _t0.add(const Duration(hours: 2)),
    from: _t0,
    to: _t0.add(const Duration(hours: 1)),
    appVersion: appVersion,
    platform: platform,
    installedSchema: 285,
    requiredSchema: 285,
    traces: traces,
    features: features,
    checks: checks,
    backendUrl:
        'https://zwzbynivewivvjmripeb.supabase.co/rest/v1?apikey=CANARYKEY',
    includeBackendHost: includeBackendHost,
    workspaceId: '5ffea179-71ed-4f1e-801f-5106b5ac0dc5',
  ),
);

void main() {
  test('no canary survives, whatever the source carried', () {
    final bundle = _build(
      traces: [
        for (final c in _canaries)
          _e('failed for $c\r\n[ERROR] forged', error: c),
        _e(
          'x' * 100000,
          error: 'PostgrestException(message: $_canaries, code: 42501)',
        ),
        _e('ok', area: 'money\r\ninjected', error: _canaries.first),
      ],
      features: {
        'invoicing': true,
        'bad key\r\n${_canaries[3]}': true,
        _canaries[6]: false,
      },
      checks: {'schema': 'ok', 'weird\nid': 'ok', 'storage': _canaries[1]},
      appVersion: _canaries[0],
      platform: _canaries[8],
    );
    for (final c in [
      ..._canaries,
      'CANARY',
      'forged',
      'injected',
      '5ffea179',
    ]) {
      expect(bundle.text, isNot(contains(c)), reason: c);
    }
    expect(bundle.text, isNot(contains('\r')));
    final json = jsonDecode(bundle.text) as Map;
    expect((json['app'] as Map)['version'], 'unknown');
    expect((json['app'] as Map)['platform'], 'unknown');
    expect((json['context'] as Map)['backend'], 'omitted');
    expect((json['context'] as Map)['workspace'], 'workspace-1');
    expect(json['features'], {'invoicing': true});
    expect(json['checks'], {'schema': 'ok', 'storage': 'unknown'});
    final events = (json['events'] as List).cast<Map<String, Object?>>();
    expect(events.map((e) => e['code']), contains('sql_42501'));
    expect(events.map((e) => e['area']), contains('other'));
    for (final e in events) {
      expect(e.keys.toSet(), {'t', 'level', 'area', 'code'});
    }
  });

  test('including the backend adds its scheme and host, nothing else', () {
    final json = jsonDecode(_build(includeBackendHost: true).text) as Map;
    expect(
      (json['context'] as Map)['backend'],
      'https://zwzbynivewivvjmripeb.supabase.co',
    );
    expect(jsonEncode(json), isNot(contains('CANARYKEY')));
    expect(json['app'], {'version': '1.4.0+1612', 'platform': 'android'});
    expect(json['schema'], {'installed': 285, 'required': 285});
  });

  test('only warnings and errors inside the window, newest first', () {
    final json = jsonDecode(
      _build(
        traces: [
          _e('a', after: const Duration(minutes: -1)),
          _e('b', after: const Duration(minutes: 10)),
          _e('c', level: TraceLevel.info),
          _e('d', level: TraceLevel.warn, after: const Duration(minutes: 20)),
          _e('e', after: const Duration(hours: 2)),
        ],
      ).text,
    ) as Map;
    final events = (json['events'] as List).cast<Map<String, Object?>>();
    expect(events.map((e) => e['level']), ['warn', 'error']);
    expect(events.first['code'], 'warning');
    expect(json['events_in_window'], 2);
  });

  test('a transport failure reads as network, not as the app failing', () {
    final json = jsonDecode(
      _build(traces: [_e('x', error: 'ClientException: Connection reset')])
          .text,
    ) as Map;
    expect(((json['events'] as List).single as Map)['code'], 'network');
  });

  test('the bundle stays bounded and says what it dropped', () {
    final many = [
      for (var i = 0; i < 5000; i++)
        _e('m$i', after: Duration(seconds: i % 3600)),
    ];
    final bundle = _build(traces: many);
    expect(bundle.bytes, lessThanOrEqualTo(supportBundleMaxBytes));
    final events = (jsonDecode(bundle.text) as Map)['events'] as List;
    expect(events.length, lessThanOrEqualTo(supportBundleMaxEvents));
    expect(bundle.droppedEvents, 5000 - events.length);
  });

  test('the same input gives the same bytes', () {
    final traces = [_e('a'), _e('b', after: const Duration(minutes: 7))];
    expect(_build(traces: traces).text, _build(traces: traces).text);
  });
}
