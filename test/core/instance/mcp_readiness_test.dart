// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — readiness of ONE target for a controlled MCP activation. The
// fixture is ready; every negative case changes one measured fact and must
// name its own check and leave the target not ready. Unknown never passes,
// MCP being off or undeployed never fails native access, and a report is
// bound to the target it was measured on and cannot be edited into "ready".
import 'package:deskilo/core/instance/mcp_readiness.dart';
import 'package:deskilo/core/instance/mcp_readiness_checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mcp_target_fixture.dart';

Map<String, Object?> _with(
  Map<String, Object?> base,
  String path,
  Object? value,
) {
  final copy = Map<String, Object?>.of(base);
  final parts = path.split('.');
  Map<String, Object?> node = copy;
  for (final p in parts.take(parts.length - 1)) {
    final next = Map<String, Object?>.of(node[p]! as Map<String, Object?>);
    node[p] = next;
    node = next;
  }
  node[parts.last] = value;
  return copy;
}

McpReadinessReport _eval(McpTargetEvidence e, [McpReleaseExpectation? r]) =>
    evaluateMcpReadiness(e, r ?? fixtureRelease());

ReadinessCheck _check(McpReadinessReport r, String code) => r.checks.firstWhere(
  (c) => c.code == code,
  orElse: () => fail('no check $code in ${r.checks.map((c) => c.code)}'),
);

void main() {
  test(
    'positive control: the fixture is ready for a controlled activation',
    () {
      final r = _eval(readyEvidence());
      expect(r.blocking.map((c) => '${c.code}: ${c.detail}'), isEmpty);
      expect(r.status, McpTargetStatus.readyForControlledActivation);
      for (final a in ReadinessArea.values) {
        expect(r.area(a), CheckOutcome.pass, reason: a.name);
      }
      expect(r.binding.installationId, fixtureInstallation);
      expect(r.binding.fingerprint, fixtureFingerprint);
    },
  );

  test('the same facts with MCP on are active and verified, not "ready"', () {
    final r = _eval(readyEvidence(database: readyDatabase(enabled: true)));
    expect(r.status, McpTargetStatus.activeVerified);
  });

  final auth = readyAuthConfig();
  final db = readyDatabase();
  final cases = <(String, McpTargetEvidence, String, CheckOutcome, String?)>[
    (
      'missing pre-request hook',
      readyEvidence(database: _with(db, 'guard.pre_request_installed', false)),
      'facade_guard',
      CheckOutcome.fail,
      null,
    ),
    (
      'a table without the delegated denial',
      readyEvidence(
        database: _with(db, 'guard.tables_without_denial', ['invoices']),
      ),
      'facade_guard',
      CheckOutcome.fail,
      null,
    ),
    (
      'no trusted administrator',
      readyEvidence(
        database: _with(db, 'areas.database_eligibility.administrators', 0),
      ),
      'database_administrator',
      CheckOutcome.fail,
      'db-admins',
    ),
    (
      'an administrator without an identity',
      readyEvidence(
        database: _with(
          db,
          'areas.database_eligibility.administrators_without_identity',
          1,
        ),
      ),
      'administrators_bound',
      CheckOutcome.fail,
      null,
    ),
    (
      'no identity authority',
      readyEvidence(
        database: _with(db, 'areas.canonical_federation.authority_kind', null),
      ),
      'identity_authority',
      CheckOutcome.fail,
      null,
    ),
    (
      'Auth answers as another issuer (a guessed /auth/v1 path)',
      readyEvidence(authDiscovery: {'issuer': 'https://auth.customer.test'}),
      'auth_url_confirmed',
      CheckOutcome.fail,
      'auth_url_mismatch',
    ),
    (
      'the stated native issuer is not this Auth',
      readyEvidence(
        database: _with(
          db,
          'areas.canonical_federation.issuer',
          'https://other.test/auth/v1',
        ),
      ),
      'canonical_issuer',
      CheckOutcome.fail,
      null,
    ),
    (
      'only a symmetric signing key',
      readyEvidence(
        jwks: {
          'keys': [
            {'kty': 'oct'},
          ],
        },
      ),
      'jwks_asymmetric',
      CheckOutcome.fail,
      'jwks_no_asymmetric_key',
    ),
    (
      'the Site URL is the Auth URL',
      readyEvidence(
        authConfig: {
          ...auth,
          'site_url': fixtureAuthUrl,
          'uri_allow_list': 'deskilo://**,$fixtureAuthUrl/**',
        },
      ),
      'site_url_distinct',
      CheckOutcome.fail,
      null,
    ),
    (
      'the canonical project lacks its identity hook',
      readyEvidence(
        database: _with(db, 'areas.canonical_federation.federation_clients', 1),
      ),
      'identity_hook',
      CheckOutcome.fail,
      'federation-hook',
    ),
    (
      'no approved assistant client',
      readyEvidence(
        database: _with(db, 'areas.mcp_runtime.active_clients', <String>[]),
      ),
      'mcp_client_registered',
      CheckOutcome.fail,
      null,
    ),
    (
      'the approved client is not registered in Auth',
      readyEvidence(oauthClientIds: ['someone-else']),
      'oauth_clients_registered',
      CheckOutcome.fail,
      null,
    ),
    (
      'Auth\'s OAuth clients were not read',
      McpTargetEvidence(
        ref: fixtureRef,
        schemaMarker: 312,
        database: db,
        authUrl: Uri.parse(fixtureAuthUrl),
        authConfig: auth,
        authDiscovery: const {'issuer': fixtureAuthUrl},
        jwks: const {
          'keys': [
            {'kty': 'EC'},
          ],
        },
        secretDigests: readySecrets(),
        deployedFunctions: const ['deskilo-mcp'],
        anonymousEndpointStatus: 401,
        resourceMetadata: const {
          'resource': fixtureEndpoint,
          'authorization_servers': [fixtureAuthUrl],
        },
        catalogue: fixtureCatalogue(),
        contractLines: const {fixtureContractLine},
      ),
      'oauth_clients_registered',
      CheckOutcome.unknown,
      'DESKILO_TARGET_AUTH_ADMIN_KEY',
    ),
    (
      'an Auth version without an OAuth server capability',
      readyEvidence(authConfig: Map.of(auth)..remove('oauth_server_enabled')),
      'oauth_server_enabled',
      CheckOutcome.unknown,
      null,
    ),
    (
      'the OAuth server is off',
      readyEvidence(authConfig: {...auth, 'oauth_server_enabled': false}),
      'oauth_server_enabled',
      CheckOutcome.fail,
      null,
    ),
    (
      'a stale operation catalogue',
      readyEvidence(catalogue: {...fixtureCatalogue(), 'version': 0}),
      'catalogue_matches_release',
      CheckOutcome.fail,
      null,
    ),
    (
      'an implemented operation with no classified output',
      readyEvidence(
        database: _with(db, 'areas.mcp_runtime.unclassified_operations', [
          'get_capabilities',
        ]),
      ),
      'output_classified',
      CheckOutcome.fail,
      null,
    ),
    (
      'a disclosure ceiling field the contract does not know',
      readyEvidence(
        database: _with(db, 'areas.mcp_runtime.unknown_ceiling_fields', [
          'email',
        ]),
      ),
      'disclosure_ceiling',
      CheckOutcome.fail,
      null,
    ),
    (
      'a routine whose body differs from the release (contract mismatch)',
      readyEvidence(
        contractLines: {
          fixtureContractLine.replaceFirst('020fc410aef9', 'ffffffffffff'),
        },
      ),
      'contract_routines',
      CheckOutcome.fail,
      null,
    ),
    (
      'the endpoint is not deployed',
      readyEvidence(deployedFunctions: ['send-push']),
      'endpoint_deployed',
      CheckOutcome.fail,
      null,
    ),
    (
      'a deployed function nobody classified',
      readyEvidence(deployedFunctions: ['deskilo-mcp', 'debug-dump']),
      'edge_functions_classified',
      CheckOutcome.fail,
      'debug-dump',
    ),
    (
      'the endpoint lacks its epoch (503)',
      readyEvidence(anonymousEndpointStatus: 503),
      'endpoint_fails_closed',
      CheckOutcome.fail,
      'endpoint_not_configured',
    ),
    (
      'the endpoint answers an anonymous call',
      readyEvidence(anonymousEndpointStatus: 200),
      'endpoint_fails_closed',
      CheckOutcome.fail,
      null,
    ),
    (
      'DESKILO_MCP_EPOCH is not set',
      readyEvidence(
        secretDigests: Map.of(readySecrets())..remove('DESKILO_MCP_EPOCH'),
      ),
      'endpoint_epoch',
      CheckOutcome.fail,
      'DESKILO_MCP_EPOCH is not set',
    ),
    (
      'the endpoint carries another epoch',
      readyEvidence(secretDigests: readySecrets(epoch: 2)),
      'endpoint_epoch',
      CheckOutcome.fail,
      'epoch_mismatch',
    ),
    (
      'the endpoint serves another installation',
      readyEvidence(
        secretDigests: {
          ...readySecrets(),
          'DESKILO_INSTALLATION_ID': digestOf(
            '00000000-0000-4000-8000-00000000000b',
          ),
        },
      ),
      'endpoint_installation',
      CheckOutcome.fail,
      'installation_mismatch',
    ),
    (
      'the Edge secrets could not be listed',
      McpTargetEvidence(
        ref: fixtureRef,
        schemaMarker: 312,
        database: db,
        authUrl: Uri.parse(fixtureAuthUrl),
        authConfig: auth,
        authDiscovery: const {'issuer': fixtureAuthUrl},
      ),
      'endpoint_epoch',
      CheckOutcome.unknown,
      null,
    ),
    (
      'the endpoint names another resource',
      readyEvidence(
        resourceMetadata: {
          'resource': 'https://evil.test/mcp',
          'authorization_servers': [fixtureAuthUrl],
        },
      ),
      'resource_metadata',
      CheckOutcome.fail,
      'resource_mismatch',
    ),
    (
      'the metadata names an authorization server Auth is not',
      readyEvidence(
        resourceMetadata: {
          'resource': fixtureEndpoint,
          'authorization_servers': ['https://$fixtureRef.supabase.co/auth/v2'],
        },
      ),
      'resource_metadata',
      CheckOutcome.fail,
      'authorization_server_mismatch',
    ),
    (
      'the schema is behind the release',
      readyEvidence(schemaMarker: 310),
      'native_schema_compatible',
      CheckOutcome.fail,
      null,
    ),
    (
      'the Site URL is localhost',
      readyEvidence(authConfig: {...auth, 'site_url': 'http://localhost:3000'}),
      'native_site_url',
      CheckOutcome.fail,
      null,
    ),
    (
      'the native callback is not allowed',
      readyEvidence(
        authConfig: {...auth, 'uri_allow_list': 'https://app.deskilo.test/**'},
      ),
      'native_redirect_allow_list',
      CheckOutcome.fail,
      'deskilo://**',
    ),
    (
      'the recovery template has no code (the default is link-only)',
      readyEvidence(
        authConfig: {...auth, 'mailer_templates_recovery_content': ''},
      ),
      'email_recovery_code',
      CheckOutcome.fail,
      'recovery_template_without_code',
    ),
    (
      'a custom confirmation template without its link',
      readyEvidence(
        authConfig: {
          ...auth,
          'mailer_templates_confirmation_content': 'Welcome!',
        },
      ),
      'email_confirmation_link',
      CheckOutcome.fail,
      null,
    ),
    (
      'no custom SMTP',
      readyEvidence(authConfig: {...auth, 'smtp_host': ''}),
      'email_custom_smtp',
      CheckOutcome.fail,
      'smtp_not_configured',
    ),
    (
      'an Auth version that does not report its mail server',
      readyEvidence(authConfig: Map.of(auth)..remove('smtp_host')),
      'email_custom_smtp',
      CheckOutcome.unknown,
      null,
    ),
    (
      'a one-week OTP',
      readyEvidence(authConfig: {...auth, 'mailer_otp_exp': 604800}),
      'email_otp_settings',
      CheckOutcome.fail,
      null,
    ),
  ];

  for (final (name, evidence, code, outcome, detail) in cases) {
    test('$name → $code is ${outcome.name} and the target is not ready', () {
      final r = _eval(evidence);
      final c = _check(r, code);
      expect(c.outcome, outcome);
      if (detail != null) expect(c.detail, contains(detail));
      expect(r.status, McpTargetStatus.notReady);
    });
  }

  test('an oidc authority needs its provider, its issuer and the canonical client for THIS target', () {
    const canonical = 'https://id.deskilo.test/auth/v1';
    final oidc = _with(
      _with(db, 'areas.canonical_federation.authority_kind', 'oidc'),
      'areas.canonical_federation.issuer',
      canonical,
    );
    McpTargetEvidence with_({
      Map<String, Object?>? provider,
      Map<String, Object?>? client,
    }) => McpTargetEvidence(
      ref: fixtureRef,
      schemaMarker: 312,
      database: oidc,
      authUrl: Uri.parse(fixtureAuthUrl),
      authConfig: auth,
      authDiscovery: const {'issuer': fixtureAuthUrl},
      canonicalDiscovery: const {'issuer': canonical},
      federationProvider: provider,
      canonicalClient: client,
    );
    final unread = _eval(with_());
    expect(_check(unread, 'federation_provider').outcome, CheckOutcome.unknown);
    expect(_check(unread, 'federation_callback').outcome, CheckOutcome.unknown);
    final good = _eval(
      with_(
        provider: {'enabled': true, 'issuer': canonical},
        client: {
          'target_installation_id': fixtureInstallation,
          'target_auth_url': fixtureAuthUrl,
          'enabled': true,
        },
      ),
    );
    expect(_check(good, 'federation_provider').outcome, CheckOutcome.pass);
    expect(_check(good, 'federation_callback').outcome, CheckOutcome.pass);
    expect(_check(good, 'canonical_issuer').outcome, CheckOutcome.pass);
    final crossed = _eval(
      with_(
        provider: {'enabled': false, 'issuer': canonical},
        client: {
          'target_installation_id': '00000000-0000-4000-8000-00000000000b',
          'target_auth_url': fixtureAuthUrl,
          'enabled': true,
        },
      ),
    );
    expect(_check(crossed, 'federation_provider').outcome, CheckOutcome.fail);
    expect(
      _check(crossed, 'federation_callback').detail,
      contains('federation_callback_mismatch'),
    );
  });

  test('a nested app base path and a customer backend are judged by their own URLs', () {
    final r = _eval(
      readyEvidence(
        authConfig: {
          ...auth,
          'site_url': 'https://customer.example.org/coworking/',
          'uri_allow_list':
              'deskilo://**,https://customer.example.org/coworking/**',
        },
      ),
    );
    expect(_check(r, 'native_site_url').outcome, CheckOutcome.pass);
    expect(_check(r, 'native_redirect_allow_list').outcome, CheckOutcome.pass);
  });

  test('MCP off or undeployed never fails native access', () {
    final r = _eval(
      readyEvidence(
        database: readyDatabase(),
        deployedFunctions: ['send-push'],
        anonymousEndpointStatus: 404,
        secretDigests: const {},
      ),
    );
    expect(r.area(ReadinessArea.nativeAccess), CheckOutcome.pass);
    expect(r.area(ReadinessArea.mcpRuntime), CheckOutcome.fail);
    expect(r.status, McpTargetStatus.notReady);
  });

  test(
    'a target whose readiness function cannot be read is unknown, never ready',
    () {
      final r = _eval(
        McpTargetEvidence(ref: fixtureRef, schemaMarker: 311, authConfig: auth),
      );
      expect(r.status, McpTargetStatus.notReady);
      for (final a in [
        ReadinessArea.databaseEligibility,
        ReadinessArea.workspaceExposure,
        ReadinessArea.userConsent,
      ]) {
        expect(r.area(a), CheckOutcome.unknown, reason: a.name);
      }
      expect(r.binding.installationId, isNull);
    },
  );

  test('an area with nothing measured is unknown, and unknown blocks like a failure', () {
    final r = McpReadinessReport(
      const McpTargetBinding(
        ref: fixtureRef,
        installationId: fixtureInstallation,
        epoch: 1,
        schemaVersion: 312,
        fingerprint: fixtureFingerprint,
        enabled: false,
      ),
      const [
        ReadinessCheck(ReadinessArea.nativeAccess, 'x', CheckOutcome.pass),
      ],
    );
    expect(r.area(ReadinessArea.mcpRuntime), CheckOutcome.unknown);
    expect(r.status, McpTargetStatus.notReady);
  });

  test('MCP on with a failing check is flagged for disabling', () {
    final r = _eval(
      readyEvidence(
        database: readyDatabase(enabled: true),
        anonymousEndpointStatus: 503,
      ),
    );
    expect(r.status, McpTargetStatus.activeNotReady);
  });

  group('a report certifies only the target it was measured on', () {
    final json = _eval(readyEvidence()).toJson();

    test('verifies for its own ref, installation and epoch', () {
      expect(
        verifyMcpReadinessReport(
          json,
          ref: fixtureRef,
          installationId: fixtureInstallation,
          epoch: 1,
        ),
        isNull,
      );
    });

    test('another project, installation or epoch is refused', () {
      expect(
        verifyMcpReadinessReport(
          json,
          ref: 'zzzzzzzzzzzzzzzzzzzz',
          installationId: fixtureInstallation,
          epoch: 1,
        ),
        'report_for_other_target',
      );
      expect(
        verifyMcpReadinessReport(
          json,
          ref: fixtureRef,
          installationId: '00000000-0000-4000-8000-00000000000b',
          epoch: 1,
        ),
        'report_for_other_target',
      );
      expect(
        verifyMcpReadinessReport(
          json,
          ref: fixtureRef,
          installationId: fixtureInstallation,
          epoch: 2,
        ),
        'report_for_other_target',
      );
    });

    test(
      'a caller-supplied checksPassed or an edited outcome does not verify',
      () {
        expect(
          verifyMcpReadinessReport(
            {...json, 'checksPassed': true},
            ref: fixtureRef,
            installationId: fixtureInstallation,
            epoch: 1,
          ),
          'report_tampered',
        );
        final notReady = _eval(readyEvidence(anonymousEndpointStatus: 503))
            .toJson();
        final forged = {
          ...notReady,
          'status': McpTargetStatus.readyForControlledActivation.name,
        };
        expect(
          verifyMcpReadinessReport(
            forged,
            ref: fixtureRef,
            installationId: fixtureInstallation,
            epoch: 1,
          ),
          'report_tampered',
        );
        expect(
          verifyMcpReadinessReport(
            notReady,
            ref: fixtureRef,
            installationId: fixtureInstallation,
            epoch: 1,
          ),
          'report_not_ready',
        );
      },
    );

    test('the report carries no secret digest and no token', () {
      final text = '$json';
      expect(text, isNot(contains(digestOf(fixtureInstallation))));
      expect(text, isNot(contains('Bearer')));
    });
  });

  test('the disabled dev project as measured on 2026-09-29 is not ready, and says why', () {
    // Live read-only answers from the coworking-staging project, with its
    // ref and installation id replaced: operator_mcp_readiness(), Auth
    // discovery (issuer at /auth/v1, one EC key), deskilo-mcp not deployed.
    final measured = {
      ...readyDatabase(),
      'schema_version': 312,
      'areas': {
        ...(readyDatabase()['areas']! as Map<String, Object?>),
        'canonical_federation': {
          'authority_kind': null,
          'issuer': null,
          'oidc_provider': null,
          'active_bindings': 0,
          'federation_clients': 0,
          'federation_clients_enabled': 0,
        },
        'database_eligibility': {
          'administrators': 0,
          'administrators_without_identity': 0,
          'eligible_users': 0,
          'pending_requests': 0,
        },
        'mcp_runtime': {
          ...((readyDatabase()['areas']! as Map)['mcp_runtime']
              as Map<String, Object?>),
          'active_clients': <String>[],
        },
      },
      'blockers': [
        'no_identity_authority',
        'no_database_administrator',
        'no_active_mcp_client',
      ],
    };
    final r = _eval(
      McpTargetEvidence(
        ref: fixtureRef,
        schemaMarker: 312,
        database: measured,
        authUrl: Uri.parse(fixtureAuthUrl),
        authDiscovery: const {'issuer': fixtureAuthUrl},
        jwks: const {
          'keys': [
            {'kty': 'EC', 'alg': 'ES256'},
          ],
        },
        anonymousEndpointStatus: 404,
      ),
    );
    expect(r.status, McpTargetStatus.notReady);
    final failing = {for (final c in r.blocking) c.code};
    expect(
      failing,
      containsAll([
        'identity_authority',
        'database_administrator',
        'mcp_client_registered',
        'endpoint_fails_closed',
        'endpoint_epoch',
        'resource_metadata',
      ]),
    );
    expect(_check(r, 'auth_url_confirmed').outcome, CheckOutcome.pass);
    expect(_check(r, 'jwks_asymmetric').outcome, CheckOutcome.pass);
  });
}
