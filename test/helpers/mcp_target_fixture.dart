// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — one target that is ready for a controlled MCP activation, as the
// collector would measure it, so each negative case changes ONE fact.
// Fictional throughout: no real project, person, key or token.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:deskilo/core/instance/mcp_auth_checks.dart';
import 'package:deskilo/core/instance/mcp_readiness_checks.dart';

const fixtureRef = 'abcdefghijklmnopqrst';
const fixtureInstallation = '00000000-0000-4000-8000-000000001633';
const fixtureFingerprint = '0123456789abcdef0123456789abcdef';
const fixtureAuthUrl = 'https://$fixtureRef.supabase.co/auth/v1';
const fixtureEndpoint =
    'https://$fixtureRef.supabase.co/functions/v1/deskilo-mcp';
const fixtureContractLine =
    'routine public.mcp_pre_request() -> void | function | invoker | stable | exec:anon,authenticated,service_role | body:020fc410aef9';

String digestOf(String v) => sha256.convert(utf8.encode(v)).toString();

Map<String, Object?> fixtureCatalogue() => {
  'version': 1,
  'operations': {
    'get_capabilities': {
      'dispatch': true,
      'mutation': 'read',
      'output': ['eligible_until', 'operations', 'target_ceiling'],
      'optional': <String>[],
    },
    'create_reservation': {
      'dispatch': true,
      'mutation': 'write',
      'output': ['reservation_id', 'status'],
      'optional': <String>[],
    },
    'list_workspaces': {
      'dispatch': false,
      'mutation': 'read',
      'output': ['name', 'workspace_id'],
      'optional': <String>[],
    },
  },
};

Map<String, Object?> readyDatabase({bool enabled = false, int epoch = 1}) => {
  'installation_id': fixtureInstallation,
  'epoch': epoch,
  'enabled': enabled,
  'schema_version': 312,
  'catalogue_version': '1',
  'guard': {'pre_request_installed': true, 'tables_without_denial': <String>[]},
  'areas': {
    'canonical_federation': {
      'authority_kind': 'native',
      'issuer': fixtureAuthUrl,
      'oidc_provider': null,
      'active_bindings': 2,
      'federation_clients': 0,
      'federation_clients_enabled': 0,
    },
    'database_eligibility': {
      'administrators': 1,
      'administrators_without_identity': 0,
      'eligible_users': 0,
      'pending_requests': 0,
    },
    'workspace_exposure': {
      'workspaces_with_policy': 0,
      'workspaces_exposed': 0,
    },
    'user_consent': {'active_connections': 0},
    'mcp_runtime': {
      'enabled': enabled,
      'epoch': epoch,
      'active_clients': ['pilot-assistant'],
      'limits': {
        'calls_per_minute': 60,
        'mutations_per_minute': 10,
        'workspace_calls_per_day': 10000,
      },
      'disclosure_ceiling_fields': 0,
      'unclassified_operations': <String>[],
      'unknown_ceiling_fields': <String>[],
    },
  },
  'blockers': <String>[],
  'fingerprint': fixtureFingerprint,
};

Map<String, Object?> readyAuthConfig() => {
  'site_url': 'https://app.deskilo.test/',
  'uri_allow_list': 'deskilo://**,https://app.deskilo.test/**',
  'mailer_autoconfirm': false,
  'mailer_templates_confirmation_content': '',
  'mailer_templates_recovery_content': '<p>Your code: {{ .Token }}</p>',
  'mailer_otp_length': 6,
  'mailer_otp_exp': 3600,
  'smtp_host': 'smtp.deskilo.test',
  'smtp_admin_email': 'no-reply@deskilo.test',
  'oauth_server_enabled': true,
  'hook_custom_access_token_enabled': false,
  'hook_custom_access_token_uri': null,
};

Map<String, String> readySecrets({int epoch = 1}) => {
  'DESKILO_INSTALLATION_ID': digestOf(fixtureInstallation),
  'DESKILO_MCP_EPOCH': digestOf('$epoch'),
  'SUPABASE_URL': digestOf('https://$fixtureRef.supabase.co'),
};

McpTargetEvidence readyEvidence({
  Map<String, Object?>? database,
  Map<String, Object?>? authConfig,
  Map<String, Object?>? authDiscovery,
  Map<String, String>? secretDigests,
  int? anonymousEndpointStatus = 401,
  Map<String, Object?>? resourceMetadata,
  Map<String, Object?>? catalogue,
  Set<String>? contractLines,
  List<String>? deployedFunctions,
  List<String>? oauthClientIds,
  Map<String, Object?>? jwks,
  int? schemaMarker = 312,
}) => McpTargetEvidence(
  ref: fixtureRef,
  schemaMarker: schemaMarker,
  database: database ?? readyDatabase(),
  authUrl: Uri.parse(fixtureAuthUrl),
  authConfig: authConfig ?? readyAuthConfig(),
  authDiscovery:
      authDiscovery ??
      {
        'issuer': fixtureAuthUrl,
        'jwks_uri': '$fixtureAuthUrl/.well-known/jwks.json',
      },
  jwks:
      jwks ??
      {
        'keys': [
          {'kty': 'EC', 'alg': 'ES256', 'kid': 'k1'},
        ],
      },
  oauthClientIds: oauthClientIds ?? ['pilot-assistant'],
  secretDigests: secretDigests ?? readySecrets(),
  deployedFunctions: deployedFunctions ?? ['deskilo-mcp', 'send-push'],
  anonymousEndpointStatus: anonymousEndpointStatus,
  resourceMetadata:
      resourceMetadata ??
      {
        'resource': fixtureEndpoint,
        'authorization_servers': [fixtureAuthUrl],
      },
  catalogue: catalogue ?? fixtureCatalogue(),
  contractLines: contractLines ?? {fixtureContractLine},
);

McpReleaseExpectation fixtureRelease({Map<String, Object?>? catalogue}) =>
    McpReleaseExpectation(
      requiredSchemaVersion: 312,
      catalogue: catalogue ?? fixtureCatalogue(),
      contractLines: {
        fixtureContractLine,
        'routine public.accessories_touch() -> trigger | function | invoker | volatile | exec:- | body:aaaaaaaaaaaa',
      },
      classifiedFunctions: {'deskilo-mcp', 'send-push', 'badge-signin'},
    );

/// Kept so a test can name the hook the canonical project must run.
const fixtureHookUri = canonicalIdentityHookUri;
