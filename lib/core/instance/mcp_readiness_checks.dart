// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — the evaluator: measured target facts in, named checks out. Every
// field of [McpTargetEvidence] is nullable, and null means "could not be
// measured"; a check that needs it answers `unknown`, which blocks.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../mcp/mcp_endpoint.dart';
import 'mcp_auth_checks.dart';
import 'mcp_readiness.dart';

export '../mcp/mcp_endpoint.dart' show mcpEndpointSlug;

/// What the collector measured on ONE target. Built from the target's own
/// answers; there is deliberately no field a caller could set to "passed".
class McpTargetEvidence {
  const McpTargetEvidence({
    required this.ref,
    this.schemaMarker,
    this.database,
    this.authUrl,
    this.authConfig,
    this.authDiscovery,
    this.jwks,
    this.canonicalDiscovery,
    this.federationProvider,
    this.canonicalClient,
    this.oauthClientIds,
    this.secretDigests,
    this.deployedFunctions,
    this.anonymousEndpointStatus,
    this.resourceMetadata,
    this.catalogue,
    this.contractLines,
  });

  final String ref;

  /// `deskilo_schema_version` as the doctor's schema query read it.
  final int? schemaMarker;

  /// `operator_mcp_readiness()` (0312).
  final Map<String, Object?>? database;

  /// The exact Auth URL inspected — given by the operator or derived from
  /// the project and then CONFIRMED by [authDiscovery], never assumed.
  final Uri? authUrl;
  final Map<String, Object?>? authConfig;

  /// `<authUrl>/.well-known/openid-configuration`.
  final Map<String, Object?>? authDiscovery;
  final Map<String, Object?>? jwks;

  /// The canonical issuer's discovery document, for an `oidc` authority.
  final Map<String, Object?>? canonicalDiscovery;

  /// The target's `custom:deskilo` provider as Auth's admin API reads it back.
  final Map<String, Object?>? federationProvider;

  /// The canonical project's `identity_federation_clients` row naming this
  /// target, when the operator inspected the canonical project too.
  final Map<String, Object?>? canonicalClient;

  /// OAuth client ids registered in the target's Auth.
  final List<String>? oauthClientIds;

  /// Edge secret name → sha256 of its value. Values are never read.
  final Map<String, String>? secretDigests;
  final List<String>? deployedFunctions;

  /// What the endpoint answers an anonymous POST: 401 when configured,
  /// 503 when it lacks its installation or epoch.
  final int? anonymousEndpointStatus;
  final Map<String, Object?>? resourceMetadata;

  /// The target's `mcp_operation_catalogue()`.
  final Map<String, Object?>? catalogue;

  /// The target's contract lines for the MCP routines (same shape as
  /// assets/instance/contract.txt).
  final Set<String>? contractLines;
}

/// What THIS release expects of a target. Built from the repository.
class McpReleaseExpectation {
  const McpReleaseExpectation({
    required this.requiredSchemaVersion,
    required this.catalogue,
    required this.contractLines,
    required this.classifiedFunctions,
    this.expectedResource,
  });

  final int requiredSchemaVersion;
  final Map<String, Object?> catalogue;
  final Set<String> contractLines;
  final Set<String> classifiedFunctions;

  /// The canonical MCP resource; defaults to the project's function URL.
  final Uri? expectedResource;
}

/// The routines whose contract lines readiness compares.
bool isMcpContractRoutine(String line) => RegExp(
  r'^routine public\.(mcp_|operator_|identity_|decide_mcp|finalize_identity|database_admin)',
).hasMatch(line);

String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();

/// A digest the Management API lists, or the digest of a raw value if an
/// API version answers the value itself (it is hashed here, never kept).
String secretDigest(String listed) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(listed) ? listed : sha256Hex(listed);

McpReadinessReport evaluateMcpReadiness(
  McpTargetEvidence e,
  McpReleaseExpectation release,
) {
  final db = e.database;
  Map<String, Object?>? areaOf(String name) => db?['areas'] is Map
      ? ((db!['areas'] as Map)[name] as Map?)?.cast<String, Object?>()
      : null;
  final federation = areaOf('canonical_federation');
  final eligibility = areaOf('database_eligibility');
  final exposure = areaOf('workspace_exposure');
  final consent = areaOf('user_consent');
  final runtime = areaOf('mcp_runtime');
  int? asInt(Object? v) => v is int ? v : int.tryParse('${v ?? ''}');

  final checks = <ReadinessCheck>[
    ...nativeAccessChecks(e, release.requiredSchemaVersion),
    ...federationChecks(e, federation),
    ..._eligibility(eligibility, asInt),
    _counted(
      ReadinessArea.workspaceExposure,
      'workspace_exposure_state',
      exposure,
      (m) =>
          '${m['workspaces_exposed']} of ${m['workspaces_with_policy']} workspace policies expose operations',
    ),
    _counted(
      ReadinessArea.userConsent,
      'user_consent_state',
      consent,
      (m) => '${m['active_connections']} active assistant connection(s)',
    ),
    ..._runtime(e, release, db, runtime),
  ];
  return McpReadinessReport(
    McpTargetBinding(
      ref: e.ref,
      installationId: db?['installation_id'] as String?,
      epoch: asInt(db?['epoch']),
      schemaVersion: asInt(db?['schema_version']) ?? e.schemaMarker,
      fingerprint: db?['fingerprint'] as String?,
      enabled: db?['enabled'] as bool?,
    ),
    checks,
  );
}

/// A count the database answered is known; the number itself is not a gate.
ReadinessCheck _counted(
  ReadinessArea area,
  String code,
  Map<String, Object?>? facts,
  String Function(Map<String, Object?>) describe,
) => facts == null
    ? ReadinessCheck(
        area,
        code,
        CheckOutcome.unknown,
        'the database readiness read failed',
      )
    : ReadinessCheck(area, code, CheckOutcome.pass, describe(facts));

List<ReadinessCheck> _eligibility(
  Map<String, Object?>? m,
  int? Function(Object?) asInt,
) {
  const area = ReadinessArea.databaseEligibility;
  if (m == null) {
    return const [
      ReadinessCheck(
        area,
        'database_administrator',
        CheckOutcome.unknown,
        'the database readiness read failed',
      ),
    ];
  }
  final admins = asInt(m['administrators']) ?? 0;
  final unbound = asInt(m['administrators_without_identity']) ?? 0;
  return [
    admins > 0
        ? ReadinessCheck(
            area,
            'database_administrator',
            CheckOutcome.pass,
            '$admins active',
          )
        : const ReadinessCheck(
            area,
            'database_administrator',
            CheckOutcome.fail,
            'no database administrator. The infrastructure operator provisions one: '
                'dart run tool/instance.dart db-admins --ref <ref> grant --email <address> --apply',
          ),
    unbound == 0
        ? const ReadinessCheck(area, 'administrators_bound', CheckOutcome.pass)
        : ReadinessCheck(
            area,
            'administrators_bound',
            CheckOutcome.fail,
            '$unbound administrator(s) without an active identity binding',
          ),
    ReadinessCheck(
      area,
      'eligibility_state',
      CheckOutcome.pass,
      '${m['eligible_users']} eligible, ${m['pending_requests']} pending',
    ),
  ];
}

List<ReadinessCheck> _runtime(
  McpTargetEvidence e,
  McpReleaseExpectation release,
  Map<String, Object?>? db,
  Map<String, Object?>? runtime,
) {
  const area = ReadinessArea.mcpRuntime;
  ReadinessCheck unknown(String code, String why) =>
      ReadinessCheck(area, code, CheckOutcome.unknown, why);
  ReadinessCheck judge(
    String code,
    bool ok,
    String failDetail, [
    String passDetail = '',
  ]) => ReadinessCheck(
    area,
    code,
    ok ? CheckOutcome.pass : CheckOutcome.fail,
    ok ? passDetail : failDetail,
  );
  const noDb = 'the database readiness read failed (schema before 0312?)';
  final checks = <ReadinessCheck>[];

  final guard = db?['guard'];
  checks.add(
    guard is! Map
        ? unknown('facade_guard', noDb)
        : judge(
            'facade_guard',
            guard['pre_request_installed'] == true &&
                (guard['tables_without_denial'] as List?)?.isEmpty == true,
            'the delegated-token guard is incomplete: $guard',
          ),
  );

  if (runtime == null) {
    checks.add(unknown('mcp_client_registered', noDb));
  } else {
    final clients =
        (runtime['active_clients'] as List?)?.cast<Object?>() ?? const [];
    checks.add(
      judge(
        'mcp_client_registered',
        clients.isNotEmpty,
        'no assistant client is approved on this installation',
        '${clients.length} approved',
      ),
    );
    final ids = e.oauthClientIds;
    checks.add(
      ids == null
          ? unknown(
              'oauth_clients_registered',
              'Auth\'s OAuth clients were not read (needs DESKILO_TARGET_AUTH_ADMIN_KEY)',
            )
          : judge(
              'oauth_clients_registered',
              clients.isNotEmpty && clients.every(ids.contains),
              '${clients.where((c) => !ids.contains(c)).length} approved client(s) are not registered in Auth',
            ),
    );
    checks.add(
      judge(
        'output_classified',
        (runtime['unclassified_operations'] as List?)?.isEmpty == true &&
            _localOutputClassified(release.catalogue),
        'an implemented operation has no classified output',
      ),
    );
    checks.add(
      judge(
        'disclosure_ceiling',
        (runtime['unknown_ceiling_fields'] as List?)?.isEmpty == true,
        'the disclosure ceiling names a field the contract does not know',
      ),
    );
    final limits = runtime['limits'];
    checks.add(
      judge(
        'limits_bounded',
        limits is Map && limits.values.every((v) => v is int && v > 0),
        'the MCP limits are missing or not positive',
        '$limits',
      ),
    );
  }

  final auth = e.authConfig;
  checks.add(
    auth == null
        ? unknown(
            'oauth_server_enabled',
            'the Auth configuration could not be read',
          )
        : !auth.containsKey('oauth_server_enabled')
        ? unknown(
            'oauth_server_enabled',
            'this Auth version does not report an OAuth server capability',
          )
        : judge(
            'oauth_server_enabled',
            auth['oauth_server_enabled'] == true,
            'the OAuth 2.1 server is off in Auth',
          ),
  );

  final catalogue = e.catalogue;
  checks.add(
    catalogue == null
        ? unknown(
            'catalogue_matches_release',
            'the operation catalogue could not be read',
          )
        : judge(
            'catalogue_matches_release',
            canonicalJson(catalogue) == canonicalJson(release.catalogue),
            'the target\'s operation catalogue is not this release\'s',
          ),
  );

  final lines = e.contractLines;
  if (lines == null) {
    checks.add(
      unknown('contract_routines', 'the routine contract could not be read'),
    );
  } else {
    final expected = release.contractLines.where(isMcpContractRoutine).toSet();
    final missing = expected.difference(lines).length;
    final extra = lines.difference(expected).length;
    checks.add(
      judge(
        'contract_routines',
        missing == 0 && extra == 0,
        '$missing routine line(s) differ from this release, $extra unexpected',
        '${expected.length} routines match',
      ),
    );
  }

  final functions = e.deployedFunctions;
  if (functions == null) {
    checks.add(
      unknown(
        'endpoint_deployed',
        'the deployed functions could not be listed',
      ),
    );
  } else {
    checks.add(
      judge(
        'endpoint_deployed',
        functions.contains(mcpEndpointSlug),
        '$mcpEndpointSlug is not deployed',
      ),
    );
    final unclassified = functions
        .where((f) => !release.classifiedFunctions.contains(f))
        .toList();
    checks.add(
      judge(
        'edge_functions_classified',
        unclassified.isEmpty,
        'deployed but not classified in supabase/functions/exposure.json: ${unclassified.join(', ')}',
      ),
    );
  }

  final status = e.anonymousEndpointStatus;
  checks.add(switch (status) {
    null => unknown(
      'endpoint_fails_closed',
      'the endpoint could not be reached',
    ),
    401 => const ReadinessCheck(
      area,
      'endpoint_fails_closed',
      CheckOutcome.pass,
      'an anonymous call is refused (401)',
    ),
    503 => const ReadinessCheck(
      area,
      'endpoint_fails_closed',
      CheckOutcome.fail,
      'endpoint_not_configured: it lacks DESKILO_INSTALLATION_ID or DESKILO_MCP_EPOCH (503)',
    ),
    _ => ReadinessCheck(
      area,
      'endpoint_fails_closed',
      CheckOutcome.fail,
      'an anonymous call answered $status, not 401',
    ),
  });

  checks.add(
    _secret(
      e,
      'endpoint_installation',
      'DESKILO_INSTALLATION_ID',
      db?['installation_id'] as String?,
      'installation_mismatch',
    ),
  );
  checks.add(
    _secret(
      e,
      'endpoint_epoch',
      'DESKILO_MCP_EPOCH',
      db?['epoch'] == null ? null : '${db!['epoch']}',
      'epoch_mismatch',
    ),
  );
  checks.add(_resource(e, release));
  checks.add(
    db == null
        ? unknown('runtime_state', noDb)
        : ReadinessCheck(
            area,
            'runtime_state',
            CheckOutcome.pass,
            db['enabled'] == true ? 'MCP is on' : 'MCP is off',
          ),
  );
  return checks;
}

bool _localOutputClassified(Map<String, Object?> catalogue) {
  final ops = catalogue['operations'];
  if (ops is! Map || ops.isEmpty) return false;
  return ops.values.every(
    (o) =>
        o is Map &&
        (o['dispatch'] != true ||
            (o['output'] is List && (o['output'] as List).isNotEmpty)),
  );
}

/// The endpoint's secret against the database's value, by digest only.
ReadinessCheck _secret(
  McpTargetEvidence e,
  String code,
  String name,
  String? expected,
  String mismatch,
) {
  const area = ReadinessArea.mcpRuntime;
  final digests = e.secretDigests;
  if (digests == null) {
    return ReadinessCheck(
      area,
      code,
      CheckOutcome.unknown,
      'the Edge secrets could not be listed',
    );
  }
  final listed = digests[name];
  if (listed == null || listed.isEmpty) {
    return ReadinessCheck(
      area,
      code,
      CheckOutcome.fail,
      '$name is not set: the endpoint serves nothing (503)',
    );
  }
  if (expected == null) {
    return ReadinessCheck(
      area,
      code,
      CheckOutcome.unknown,
      'the database value could not be read',
    );
  }
  return secretDigest(listed) == sha256Hex(expected)
      ? ReadinessCheck(
          area,
          code,
          CheckOutcome.pass,
          '$name matches the database',
        )
      : ReadinessCheck(
          area,
          code,
          CheckOutcome.fail,
          '$mismatch: $name is not this database\'s value; redeploy with the current one',
        );
}

ReadinessCheck _resource(McpTargetEvidence e, McpReleaseExpectation release) {
  const area = ReadinessArea.mcpRuntime;
  const code = 'resource_metadata';
  final meta = e.resourceMetadata;
  final issuer = e.authDiscovery?['issuer'];
  if (meta == null) {
    return const ReadinessCheck(
      area,
      code,
      CheckOutcome.unknown,
      'the protected-resource metadata could not be read',
    );
  }
  final expected =
      release.expectedResource?.toString() ??
      'https://${e.ref}.supabase.co/functions/v1/$mcpEndpointSlug';
  if (meta['resource'] != expected) {
    return ReadinessCheck(
      area,
      code,
      CheckOutcome.fail,
      'resource_mismatch: the endpoint names ${meta['resource']}, expected $expected',
    );
  }
  if (issuer is! String) {
    return const ReadinessCheck(
      area,
      code,
      CheckOutcome.unknown,
      'the Auth issuer was not discovered, so the authorization server cannot be compared',
    );
  }
  final servers = meta['authorization_servers'];
  return servers is List && servers.contains(issuer)
      ? const ReadinessCheck(area, code, CheckOutcome.pass)
      : ReadinessCheck(
          area,
          code,
          CheckOutcome.fail,
          'authorization_server_mismatch: the metadata names $servers, Auth answers as $issuer',
        );
}
