// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — a target the mcp-* commands can be run against: the Management
// API answers like a 0312 database in the given state, and the HTTP side
// like a deployed, configured endpoint (or not). Fictional throughout.
import 'dart:convert';

import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/management_api.dart';

import '../../tool/instance/mcp_collect.dart';
import 'fake_supabase_management.dart';
import 'mcp_target_fixture.dart';

class FakeHttp implements McpTargetHttp {
  FakeHttp({this.anonymousStatus = 401, this.pilotAnswer});
  int anonymousStatus;
  Object? pilotAnswer;
  final gets = <Uri>[];
  final posts = <(Uri, Object, Map<String, String>)>[];

  @override
  Future<HttpAnswer?> get(
    Uri url, {
    Map<String, String> headers = const {},
  }) async {
    gets.add(url);
    final u = '$url';
    if (u == '$fixtureAuthUrl/.well-known/openid-configuration') {
      return (
        status: 200,
        json: {
          'issuer': fixtureAuthUrl,
          'jwks_uri': '$fixtureAuthUrl/.well-known/jwks.json',
        },
      );
    }
    if (u.endsWith('/jwks.json')) {
      return (
        status: 200,
        json: {
          'keys': [
            {'kty': 'EC'},
          ],
        },
      );
    }
    if (u.endsWith('/secrets')) {
      return (
        status: 200,
        json: [
          for (final e in readySecrets().entries)
            {'name': e.key, 'value': e.value},
        ],
      );
    }
    if (u.endsWith('/oauth-protected-resource')) {
      return (
        status: 200,
        json: {
          'resource': fixtureEndpoint,
          'authorization_servers': [fixtureAuthUrl],
        },
      );
    }
    if (u.endsWith('/admin/oauth/clients')) {
      return (
        status: 200,
        json: {
          'clients': [
            {'client_id': 'pilot-assistant'},
          ],
        },
      );
    }
    return (status: 404, json: null);
  }

  @override
  Future<HttpAnswer?> post(
    Uri url,
    Object body, {
    Map<String, String> headers = const {},
  }) async {
    posts.add((url, body, headers));
    if (!headers.containsKey('Authorization')) {
      return (status: anonymousStatus, json: {'error': 'unauthorized'});
    }
    final method = (body as Map)['method'];
    if (method == 'tools/list') {
      return (
        status: 200,
        json: {
          'result': {
            'tools': [
              {
                'name': 'deskilo_get_capabilities',
                'annotations': {'readOnlyHint': true},
              },
            ],
          },
        },
      );
    }
    return (status: 200, json: pilotAnswer);
  }
}

const ws = '00000000-0000-4000-8000-00000000a001';
const env = {
  'SUPABASE_ACCESS_TOKEN': 'PRIVATE-MANAGEMENT-TOKEN',
  'DESKILO_TARGET_AUTH_ADMIN_KEY': 'PRIVATE-ADMIN-KEY',
  'DESKILO_PILOT_TOKEN': 'PRIVATE-PILOT-TOKEN',
};

/// A target in the state [database]; the operator functions answer like
/// 0312 (the database's own refusals are covered by pgTAP 98).
FakeSupabaseManagement target({
  Map<String, Object?>? database,
  String? refuse,
}) {
  final api = FakeSupabaseManagement()..authConfigValue = readyAuthConfig();
  api.existingFunctions[fixtureRef] = ['deskilo-mcp', 'send-push'];
  api.onQuery = (ref, sql) {
    if (sql == InstanceDoctor.schemaHealthSql) {
      return [
        {'marker': 312, 'tables': 200, 'migrations_applied': -1},
      ];
    }
    if (sql == mcpReadinessSql) {
      return [
        {'r': jsonEncode(database ?? readyDatabase())},
      ];
    }
    if (sql == mcpCatalogueSql) {
      return [
        {'c': fixtureCatalogue()},
      ];
    }
    if (sql == mcpContractSql) {
      return [
        {'line': fixtureContractLine},
      ];
    }
    if (sql.contains('operator_')) {
      if (refuse != null) throw ManagementApiException(400, refuse);
      return [
        {
          'result': jsonEncode({
            'enabled': !sql.contains('disable'),
            'epoch': sql.contains('reset') ? 2 : 1,
          }),
        },
      ];
    }
    return const [];
  };
  return api;
}

List<String> writes(FakeSupabaseManagement api) => [
  for (final s in api.queriedSql)
    if (RegExp(r'operator_(activate|disable|reset|set)|insert |update |delete ')
        .hasMatch(s))
      s,
];
