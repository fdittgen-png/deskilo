// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — the 0358 adapters reach exactly the RPCs the migration defines,
// with its parameter names, and read the answers fail-safe: a status,
// decider or source this build does not know is never approved or
// published, and a server before 0358 (missing function) answers unknown
// rather than failing the page.
import 'dart:convert';

import 'package:deskilo/features/mcp/data/supabase_mcp_onboarding_repository.dart';
import 'package:deskilo/features/mcp/domain/instance_operator.dart';
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

  test('the loopback switch answers what was saved', () async {
    final w = _wire(
      (_) => {'allow_loopback_clients': true, 'unchanged': false},
    );
    expect(
      await SupabaseMcpOnboardingRepository(w.client)
          .setLoopbackClients(allowed: true),
      isTrue,
    );
    expect(w.calls.single.$1, 'instance_set_mcp_loopback_clients');
    expect(w.calls.single.$2, {'p_enabled': true});
  });

  test('the console overview reads families, the switch and the endpoint', () {
    final o = InstanceMcpOverview.fromJson({
      'enabled': false,
      'blockers': <Object>[],
      'second_factor': true,
      'allow_loopback_clients': true,
      'endpoint': {
        'resource': 'https://x.example/functions/v1/deskilo-mcp',
        'source': 'derived',
      },
      'administrators': <Object>[],
      'candidates': <Object>[],
      'clients': [
        {
          'client_id': 'c-1',
          'name': 'Claude Code',
          'status': 'waiting',
          'family': 'loopback',
          'redirect_hosts': ['localhost:53126'],
        },
      ],
    });
    expect(o.allowLoopbackClients, isTrue);
    expect(o.endpoint.source, McpEndpointSource.derived);
    expect(o.clients.single.family, 'loopback');
    expect(o.clients.single.redirectHosts, ['localhost:53126']);
    final older = InstanceMcpOverview.fromJson({'enabled': true});
    expect(older.allowLoopbackClients, isFalse);
    expect(older.endpoint.resource, isNull);
  });

  test(
    'probe, check, grant and the workspace switch reach their RPCs',
    () async {
      final w = _wire(
        (rpc) => switch (rpc) {
          'instance_probe_mcp_endpoint' => {'state': 'pending'},
          'instance_mcp_endpoint_check' => {
            'state': 'endpoint_not_deployed',
            'reason': 'challenge_404',
          },
          'instance_grant_mcp_eligibility' => {
            'status': 'granted',
            'self_grant': true,
            'expires_at': '2026-11-02T10:00:00Z',
          },
          _ => {'workspace_id': 'w-1', 'mcp_access': true, 'unchanged': false},
        },
      );
      final repo = SupabaseMcpOnboardingRepository(w.client);
      expect((await repo.probeEndpoint()).state, EndpointProbeState.pending);
      final check = await repo.checkEndpoint();
      expect(check.state, EndpointProbeState.endpointNotDeployed);
      expect(check.reason, 'challenge_404');
      expect(
        await repo.grantEligibility(subjectId: 'u-1', reason: 'solo', days: 30),
        DateTime.utc(2026, 11, 2, 10),
      );
      expect(
        await repo.setWorkspaceMcpAccess('w-1', enabled: true, expected: false),
        isTrue,
      );
      expect(w.calls[2].$2, {
        'p_subject': 'u-1',
        'p_reason': 'solo',
        'p_days': 30,
      });
      expect(w.calls[3].$2, {
        'p_workspace_id': 'w-1',
        'p_enabled': true,
        'p_expected': false,
      });
    },
  );

  test('the overview reads grants, the probe and the grant availability', () {
    final o = InstanceMcpOverview.fromJson({
      'enabled': false,
      'google_session': true,
      'operator_grant_available': true,
      'endpoint_probe': {
        'state': 'deployed',
        'fresh': true,
        'published_resource': 'https://x.example/deskilo-mcp',
      },
      'eligible_users': [
        {
          'user_id': 'u-1',
          'name': 'Olga',
          'expires_at': '2026-11-02T10:00:00Z',
          'granted_by': 'operator',
          'self_grant': true,
          'me': true,
        },
      ],
    });
    expect(o.googleSession, isTrue);
    expect(o.operatorGrantAvailable, isTrue);
    expect(o.endpointProbe.state, EndpointProbeState.deployed);
    expect(o.endpointProbe.fresh, isTrue);
    expect(o.eligibleUsers.single.selfGrant, isTrue);
    expect(o.eligibleUsers.single.grantedByOperator, isTrue);
    expect(
      EndpointProbe.fromJson({'state': 'teapot'}).state,
      EndpointProbeState.unknown,
    );
    expect(
      InstanceMcpOverview.fromJson({}).endpointProbe.state,
      EndpointProbeState.missing,
    );
  });
}
