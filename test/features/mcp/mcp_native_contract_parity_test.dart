// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — contract parity for the native path. The #1609 contract
// (`contracts/mcp/operations.json`, `native_rpcs`) is the shared fixture:
// every call the app's native adapters make — the same bundle a connected
// installation's registry client builds — goes through the pinned
// Supabase SDK to a recording wire, and each request must be an RPC the
// contract declares, with only declared parameters, each of its declared
// SQL type; a declared parameter the adapter leaves out must have a
// default in the migration that defines it. Every native-session and
// administrator RPC the contract declares is reached by some adapter.
// (mcp_contract_test already proves each declaration against the replayed
// schema, so adapter ⇄ contract ⇄ database close the loop.)
//
// Then the fail-safe half: an answer from a newer server (a status or
// state this build does not know, a field of the wrong type, an empty
// HTTP 200) and an older one (the function is missing) never becomes an
// active, approved, decided, saved or accepted state.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/mcp/data/connected_target_client.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = '6b1d3f0e-0000-4000-8000-000000000002';
const _subject = '6b1d3f0e-0000-4000-8000-000000000003';
const _id = '6b1d3f0e-0000-4000-8000-000000000004';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

Map<String, Map<String, dynamic>> _declared() {
  final contract = jsonDecode(
    File('contracts/mcp/operations.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final r in contract['native_rpcs'] as List)
      (r as Map)['rpc'] as String: Map<String, dynamic>.from(r),
  };
}

/// The parameter list of the LAST migration that defines [rpc].
String _signature(String rpc) {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final head = RegExp(
    'function\\s+public\\.$rpc\\s*\\(([^;]*?)\\)\\s*returns',
    dotAll: true,
    caseSensitive: false,
  );
  String? last;
  for (final f in files) {
    for (final m in head.allMatches(f.readAsStringSync())) {
      last = m.group(1);
    }
  }
  if (last == null) fail('no migration defines public.$rpc');
  return last;
}

bool _ofType(String sqlType, Object? v) => switch (sqlType) {
  'uuid' => v is String && _uuid.hasMatch(v),
  'text' => v is String,
  'boolean' => v is bool,
  'integer' => v is int,
  'text[]' => v is List && v.every((x) => x is String),
  'jsonb' => v is Map || v is List,
  _ => false,
};

/// A SupabaseClient whose wire records each RPC and answers [answer].
({SupabaseClient client, List<(String, Map<String, dynamic>)> calls}) _wire(
  Object? Function(String rpc) answer, {
  int status = 200,
}) {
  final calls = <(String, Map<String, dynamic>)>[];
  final client = SupabaseClient(
    'https://target.example',
    'sb_publishable_target_key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (!path.startsWith('/rest/v1/rpc/')) {
        // Auth's own OAuth endpoints (revokeGrant): not an RPC.
        return http.Response('{}', 200, request: request);
      }
      final rpc = path.substring('/rest/v1/rpc/'.length);
      // A parameterless RPC posts `null` (or nothing).
      final sent = request.body.isEmpty ? null : jsonDecode(request.body);
      final body = sent is Map<String, dynamic> ? sent : <String, dynamic>{};
      calls.add((rpc, body));
      final a = answer(rpc);
      return http.Response(
        a is String ? a : jsonEncode(a),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (client: client, calls: calls);
}

const _request = EligibilityRequest(
  requestId: 'r-1',
  userId: _subject,
  email: 'ada@deskilo.test',
  revision: 2,
);

/// Every adapter call that reaches an RPC, through the registry bundle.
final _adapterCalls = <String, Future<Object?> Function(McpRepositories)>{
  'admin.policy': (r) => r.admin.policy(_ws),
  'admin.savePolicy': (r) => r.admin.savePolicy(
    workspaceId: _ws,
    expectedRevision: 3,
    mutationId: _id,
    enabled: true,
    operations: {'get_capabilities'},
    targetCeiling: 'own',
    optionalFields: {'name'},
  ),
  'admin.disclosureMaximum': (r) => r.admin.disclosureMaximum(),
  'admin.setDisclosureMaximum': (r) => r.admin.setDisclosureMaximum({'name'}),
  'admin.eligibilityRequests': (r) => r.admin.eligibilityRequests(),
  'admin.decide': (r) =>
      r.admin.decide(request: _request, decisionId: _id, approve: true),
  'admin.revokeEligibility': (r) => r.admin.revokeEligibility(_subject),
  'admin.workspaceUsage': (r) => r.admin.workspaceUsage(_ws),
  'connections.options': (r) => r.connections.options(),
  'connections.prepare': (r) => r.connections.prepare('client-1', 'auth-1', {
    _ws: ['get_capabilities'],
  }),
  'connections.finalize': (r) => r.connections.finalize('auth-1'),
  'connections.connections': (r) => r.connections.connections(),
  'connections.revokeScope': (r) => r.connections.revokeScope('client-1', _ws),
  'connections.disconnect': (r) => r.connections.disconnect('client-1'),
  'connections.myUsage': (r) => r.connections.myUsage(),
  'confirmations.get': (r) => r.confirmations.get(_id),
  'confirmations.respond': (r) => r.confirmations.respond(_id, accept: true),
  'identity.status': (r) => r.identity.status(),
  'identity.finalize': (r) => r.identity.finalize(),
  'identity.revoke': (r) => r.identity.revoke(),
  'identity.databaseCapabilities': (r) => r.identity.databaseCapabilities(),
  'identity.requestMcpEligibility': (r) => r.identity.requestMcpEligibility(),
  'identity.withdrawMcpEligibility': (r) => r.identity.withdrawMcpEligibility(),
};

void main() {
  test('every native adapter call is a declared RPC with declared, typed '
      'parameters; omitted ones have a server default', () async {
    final declared = _declared();
    final w = _wire((_) => <String, Object?>{});
    final bundle = supabaseMcpRepositories(w.client);
    for (final entry in _adapterCalls.entries) {
      final before = w.calls.length;
      await entry.value(bundle);
      expect(w.calls.length, before + 1, reason: '${entry.key}: one RPC');
      final (rpc, body) = w.calls.last;
      final spec = declared[rpc];
      expect(spec, isNotNull, reason: '${entry.key} calls undeclared $rpc');
      final params = Map<String, dynamic>.from(spec!['params'] as Map);
      for (final p in body.entries) {
        expect(params, contains(p.key), reason: '$rpc: undeclared ${p.key}');
        expect(
          _ofType(params[p.key] as String, p.value),
          isTrue,
          reason: '$rpc.${p.key} is not a ${params[p.key]}: ${p.value}',
        );
      }
      final omitted = params.keys.where((k) => !body.containsKey(k));
      if (omitted.isNotEmpty) {
        final signature = _signature(rpc);
        for (final p in omitted) {
          expect(
            RegExp('\\b$p\\s+[a-z\\[\\]]+\\s+default\\b').hasMatch(signature),
            isTrue,
            reason: '$rpc: ${entry.key} omits $p, which has no default',
          );
        }
      }
    }
    final reached = {for (final c in w.calls) c.$1};
    final nativeDeclared = {
      for (final e in declared.entries)
        if (e.value['security'] != 'mcpOAuth') e.key,
    };
    expect(
      nativeDeclared.difference(reached),
      isEmpty,
      reason: 'declared for the app, reached by no adapter',
    );
  });

  group('answers from another server version never turn permissive', () {
    Future<McpRepositories> bundleAnswering(Object? answer) async =>
        supabaseMcpRepositories(_wire((_) => answer).client);

    for (final (label, answer) in <(String, Object?)>[
      (
        'an unknown status',
        {
          'status': 'granted_v2',
          'state': 'bound_v2',
          'eligibility': 'eligible_v2',
          'version': 99,
        },
      ),
      ('an empty HTTP 200', ''),
      (
        'a field of the wrong type',
        {
          'status': 1,
          'state': true,
          'eligibility': ['eligible'],
          'enabled': 'true',
          'eligible': 'true',
        },
      ),
    ]) {
      test(label, () async {
        final r = await bundleAnswering(answer);
        expect(
          await r.admin.decide(
            request: _request,
            decisionId: _id,
            approve: true,
          ),
          EligibilityDecisionStatus.refused,
        );
        expect((await r.admin.policy(_ws)).enabled, isFalse);
        expect(await r.admin.setDisclosureMaximum({'name'}), isNull);
        expect(await r.admin.revokeEligibility(_subject), isFalse);
        expect(
          await r.confirmations.respond(_id, accept: true),
          ConfirmationStatus.unavailable,
        );
        expect((await r.confirmations.get(_id)).status.answerable, isFalse);
        expect(
          (await r.identity.status()).state,
          IdentityBindingState.unavailable,
        );
        expect(
          (await r.identity.databaseCapabilities()).eligibility,
          McpEligibility.unavailable,
        );
        expect((await r.connections.options()).eligible, isFalse);
        expect(await r.connections.connections(), isEmpty);
        expect(await r.admin.eligibilityRequests(), isEmpty);
      });
    }

    test('an older server without the function answers unavailable', () async {
      final missing = supabaseMcpRepositories(
        _wire(
          (_) => {
            'code': 'PGRST202',
            'message': 'Could not find the function',
            'details': null,
            'hint': null,
          },
          status: 404,
        ).client,
      );
      expect(
        (await missing.identity.status()).state,
        IdentityBindingState.unavailable,
      );
      expect(
        (await missing.identity.databaseCapabilities()).eligibility,
        McpEligibility.unavailable,
      );
      expect(
        (await missing.confirmations.get(_id)).status,
        ConfirmationStatus.unavailable,
      );
      await expectLater(
        missing.admin.decide(request: _request, decisionId: _id, approve: true),
        throwsA(isA<PostgrestException>()),
        reason: 'a decision on an older server fails loudly, never "decided"',
      );
    });
  });
}
