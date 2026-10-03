// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — the 0358 adapters reach exactly the RPCs the migration defines,
// with its parameter names, and read the answers fail-safe: a status,
// decider or source this build does not know is never approved or
// published, and a server before 0358 (missing function) answers unknown
// rather than failing the page.
import 'dart:convert';

import 'package:deskilo/features/mcp/data/supabase_mcp_onboarding_repository.dart';
import 'package:deskilo/features/mcp/domain/mcp_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

({SupabaseClient client, List<(String, Object?)> calls}) _wire(
  Object? Function(String rpc) answer, {
  int status = 200,
}) {
  final calls = <(String, Object?)>[];
  final client = SupabaseClient(
    'https://target.example',
    'sb_publishable_target_key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final rpc = request.url.path.substring('/rest/v1/rpc/'.length);
      calls.add((rpc, request.body.isEmpty ? null : jsonDecode(request.body)));
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

void main() {
  test(
    'the consent status names the client, its host and who decides',
    () async {
      final w = _wire(
        (_) => {
          'eligibility': 'not_requested',
          'workspaces': <Object>[],
          'client': {
            'client_id': 'c-1',
            'name': 'Claude',
            'status': 'waiting',
            'redirect_host': 'claude.ai',
          },
          'decider': {'kind': 'operator', 'display_name': 'Olga', 'me': false},
        },
      );
      final s = await SupabaseMcpOnboardingRepository(w.client)
          .consentStatus('a' * 32);
      expect(w.calls.single.$1, 'mcp_consent_options');
      expect(w.calls.single.$2, {'p_authorization_id': 'a' * 32});
      expect(s.client!.status, McpClientApproval.waiting);
      expect(s.client!.redirectHost, 'claude.ai');
      expect(s.clientApproved, isFalse);
      expect(s.decider!.kind, McpDeciderKind.operator);
      expect(s.decider!.displayName, 'Olga');
      expect(s.eligibility, 'not_requested');
    },
  );

  test('an unknown client status or decider is never approved', () {
    final s = ConsentStatus.fromJson({
      'eligibility': 'eligible',
      'client': {'client_id': 'c-1', 'name': 'X', 'status': 'trusted'},
      'decider': {'kind': 'robot'},
    });
    expect(s.client!.status, McpClientApproval.unknown);
    expect(s.clientApproved, isFalse);
    expect(s.decider, isNull);
    expect(ConsentStatus.fromJson(null).client, isNull);
  });

  test('the endpoint is read as published; no https, no resource', () async {
    final w = _wire(
      (_) => {
        'resource': 'https://mcp.example/deskilo-mcp',
        'metadata_url': 'https://mcp.example/deskilo-mcp/.well-known/oauth-protected-resource',
        'source': 'configured',
      },
    );
    final e = await SupabaseMcpOnboardingRepository(w.client).endpoint();
    expect(w.calls.single.$1, 'mcp_endpoint');
    expect(e.resource, 'https://mcp.example/deskilo-mcp');
    expect(e.source, McpEndpointSource.configured);
    expect(
      McpEndpointInfo.fromJson({'resource': 'http://x', 'source': 'derived'})
          .resource,
      isNull,
    );
  });

  test('a server before 0358 answers unknown, not an error', () async {
    final w = _wire(
      (_) => {'code': 'PGRST202', 'message': 'Could not find the function'},
      status: 404,
    );
    final repo = SupabaseMcpOnboardingRepository(w.client);
    expect((await repo.endpoint()).source, McpEndpointSource.unknown);
    expect((await repo.notices()).unread, 0);
  });

  test('notices are listed and marked read by id or all at once', () async {
    final w = _wire(
      (rpc) => rpc == 'my_instance_notices'
          ? {
              'unread': 1,
              'notices': [
                {
                  'id': 'n-1',
                  'kind': 'mcp_client_waiting',
                  'subject': 'c-1',
                  'payload': {
                    'client_name': 'Claude',
                    'redirect_host': 'claude.ai',
                  },
                  'created_at': '2026-10-03T10:00:00Z',
                  'read_at': null,
                },
                {'kind': 'no id'},
              ],
            }
          : {'status': 'read', 'count': 1},
    );
    final repo = SupabaseMcpOnboardingRepository(w.client);
    final n = await repo.notices();
    expect(n.unread, 1);
    expect(n.notices.single.payload['client_name'], 'Claude');
    expect(n.notices.single.unread, isTrue);
    expect(await repo.markNoticeRead('n-1'), 1);
    expect(await repo.markNoticeRead(), 1);
    expect(w.calls.skip(1).map((c) => c.$2), [
      {'p_id': 'n-1'},
      {'p_id': null},
    ]);
  });

  test('the operator sets the endpoint through the aal2 RPC', () async {
    final w = _wire(
      (_) => {'resource': 'https://mcp.example/x', 'source': 'configured'},
    );
    await SupabaseMcpOnboardingRepository(w.client)
        .setEndpoint('https://mcp.example/x');
    expect(w.calls.single.$1, 'instance_set_mcp_endpoint');
    expect(w.calls.single.$2, {'p_url': 'https://mcp.example/x'});
  });
}
