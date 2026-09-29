// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — measures ONE target for MCP readiness, read-only. SQL reads go
// through the Management API as the operator; HTTP reads are the target's
// public discovery documents, its protected-resource metadata, one anonymous
// POST the endpoint must refuse, the Edge secrets' NAMES and DIGESTS, and —
// only when the operator provides the Auth admin key — Auth's OAuth clients
// and federation provider. Nothing here writes, sends mail, or prints a
// secret; a read that fails leaves its field null, and null is `unknown`.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/management_api.dart';
import 'package:deskilo/core/instance/mcp_readiness_checks.dart';
import 'package:dio/dio.dart';

import '../build_instance.dart';
import '../mcp_contract/render.dart';

typedef HttpAnswer = ({int status, Object? json});

/// The HTTP reads readiness needs; a fake in the tests.
abstract class McpTargetHttp {
  /// null when the host could not be reached at all.
  Future<HttpAnswer?> get(Uri url, {Map<String, String> headers = const {}});
  Future<HttpAnswer?> post(
    Uri url,
    Object body, {
    Map<String, String> headers = const {},
  });
}

class DioMcpTargetHttp implements McpTargetHttp {
  DioMcpTargetHttp([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              followRedirects: false,
              validateStatus: (_) => true,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );
  final Dio _dio;

  Future<HttpAnswer?> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      final r = await request();
      final data = r.data;
      return (
        status: r.statusCode ?? 0,
        json: data is String ? _decode(data) : data,
      );
    } on DioException {
      // trace-exempt: an unreachable host is a null answer (unknown); the
      // exception can carry headers with operator credentials.
      return null;
    }
  }

  static Object? _decode(String s) {
    try {
      return jsonDecode(s);
    } on FormatException {
      // trace-exempt: a non-JSON body is simply not a document.
      return null;
    }
  }

  @override
  Future<HttpAnswer?> get(Uri url, {Map<String, String> headers = const {}}) =>
      _send(
        () => _dio.getUri<Object?>(url, options: Options(headers: headers)),
      );

  @override
  Future<HttpAnswer?> post(
    Uri url,
    Object body, {
    Map<String, String> headers = const {},
  }) => _send(
    () => _dio.postUri<Object?>(
      url,
      data: jsonEncode(body),
      options: Options(
        headers: {'Content-Type': 'application/json', ...headers},
      ),
    ),
  );

  void close() => _dio.close();
}

/// Where the target's services are. Hosted defaults are CANDIDATES: the Auth
/// URL is only used once its own discovery document confirms it.
class McpTargetLocation {
  McpTargetLocation({
    required this.ref,
    Uri? authUrl,
    Uri? endpoint,
    this.canonicalRef,
  }) : authUrl = authUrl ?? Uri.parse('https://$ref.supabase.co/auth/v1'),
       endpoint =
           endpoint ??
           Uri.parse('https://$ref.supabase.co/functions/v1/$mcpEndpointSlug');
  final String ref;
  final Uri authUrl;
  final Uri endpoint;
  final String? canonicalRef;
}

/// The release this checkout is: bundle version, catalogue, contract, Edge
/// classification.
McpReleaseExpectation loadMcpRelease(String root, {Uri? expectedResource}) {
  final bundle = parseInstanceBundle(
    encodeInstanceBundle(buildInstanceBundle(root)),
  );
  final contract = jsonDecode(
    File('$root/contracts/mcp/operations.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final exposure = jsonDecode(
    File('$root/supabase/functions/exposure.json').readAsStringSync(),
  ) as Map;
  return McpReleaseExpectation(
    requiredSchemaVersion: int.parse(bundle.schemaVersion),
    catalogue: mcpCatalogueJson(contract),
    contractLines: {
      for (final l in File(
        '$root/assets/instance/contract.txt',
      ).readAsLinesSync())
        if (l.isNotEmpty && !l.startsWith('#')) l,
    },
    classifiedFunctions: {
      for (final k in (exposure['functions'] as Map).keys) '$k',
    },
    expectedResource: expectedResource,
  );
}

/// The contract line of every MCP routine, as contract_check.sh writes it.
const mcpContractSql = r'''
select 'routine ' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ') -> ' || pg_get_function_result(p.oid)
  || ' | ' || case p.prokind when 'f' then 'function' when 'p' then 'procedure' when 'a' then 'aggregate' else p.prokind::text end
  || ' | ' || case when p.prosecdef then 'definer' else 'invoker' end
  || ' | ' || case p.provolatile when 'i' then 'immutable' when 's' then 'stable' else 'volatile' end
  || ' | exec:' || coalesce(concat_ws(',',
       case when has_function_privilege('anon', p.oid, 'execute') then 'anon' end,
       case when has_function_privilege('authenticated', p.oid, 'execute') then 'authenticated' end,
       case when has_function_privilege('service_role', p.oid, 'execute') then 'service_role' end), '-')
  || ' | body:' || left(md5(pg_get_functiondef(p.oid)), 12) as line
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname ~ '^(mcp_|operator_|identity_|decide_mcp|finalize_identity|database_admin)'
''';

const mcpReadinessSql = 'select public.operator_mcp_readiness() as r';
const mcpCatalogueSql = 'select public.mcp_operation_catalogue() as c';

Map<String, Object?>? _json(Object? v) {
  final decoded = v is String ? DioMcpTargetHttp._decode(v) : v;
  return decoded is Map ? decoded.cast<String, Object?>() : null;
}

Future<T?> _read<T>(Future<T> Function() ask) async {
  try {
    return await ask();
  } on ManagementApiException catch (e, st) {
    // trace-exempt: an unauthorized token fails every read the same way —
    // rethrown; any other failure leaves the fact unknown.
    if (e.unauthorized) Error.throwWithStackTrace(e, st);
    return null;
  }
}

/// Reads everything [evaluateMcpReadiness] judges. [managementToken] reads
/// the secrets' digests; [authAdminKey] (optional) reads Auth's clients and
/// provider. Neither is ever printed or stored.
Future<McpTargetEvidence> collectMcpEvidence(
  SupabaseManagement api,
  McpTargetHttp http,
  McpTargetLocation at, {
  required String managementToken,
  String? authAdminKey,
}) async {
  final ref = at.ref;
  final schema = await _read(
    () => api.query(ref, InstanceDoctor.schemaHealthSql),
  );
  final marker = int.tryParse('${schema?.firstOrNull?['marker'] ?? ''}');
  final db = _json(
    (await _read(() => api.query(ref, mcpReadinessSql)))?.firstOrNull?['r'],
  );
  final catalogue = _json(
    (await _read(() => api.query(ref, mcpCatalogueSql)))?.firstOrNull?['c'],
  );
  final lines = await _read(() => api.query(ref, mcpContractSql));
  final auth = await _read(() => api.authConfig(ref));
  final functions = await _read(() => api.listFunctions(ref));

  Map<String, Object?>? doc(HttpAnswer? a) =>
      a != null && a.status == 200 ? _json(a.json) : null;
  final discovery = doc(
    await http.get(Uri.parse('${at.authUrl}/.well-known/openid-configuration')),
  );
  final jwksUri = discovery?['jwks_uri'];
  final jwks = jwksUri is String
      ? doc(await http.get(Uri.parse(jwksUri)))
      : null;

  final secrets = await http.get(
    Uri.parse('https://api.supabase.com/v1/projects/$ref/secrets'),
    headers: {'Authorization': 'Bearer $managementToken'},
  );
  final digests =
      secrets != null && secrets.status == 200 && secrets.json is List
      ? {
          for (final s
              in (secrets.json as List).whereType<Map<dynamic, dynamic>>())
            '${s['name']}': '${s['value'] ?? ''}',
        }
      : null;

  final metadata = doc(
    await http.get(
      Uri.parse('${at.endpoint}/.well-known/oauth-protected-resource'),
    ),
  );
  final anonymous = await http.post(
    at.endpoint,
    {'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'},
    headers: {'Accept': 'application/json, text/event-stream'},
  );

  final fed = (db?['areas'] as Map?)?['canonical_federation'] as Map?;
  final kind = fed?['authority_kind'];
  List<String>? clientIds;
  Map<String, Object?>? provider;
  Map<String, Object?>? canonicalDiscovery;
  if (authAdminKey != null && authAdminKey.isNotEmpty) {
    final admin = {
      'apikey': authAdminKey,
      'Authorization': 'Bearer $authAdminKey',
    };
    final clients = await http.get(
      Uri.parse('${at.authUrl}/admin/oauth/clients'),
      headers: admin,
    );
    final body = clients?.status == 200 ? clients!.json : null;
    final list = body is Map ? body['clients'] : body;
    if (list is List) {
      clientIds = [
        for (final c in list.whereType<Map<dynamic, dynamic>>())
          '${c['client_id']}',
      ];
    }
    if (kind == 'oidc') {
      provider = doc(
        await http.get(
          Uri.parse('${at.authUrl}/admin/custom-providers/custom:deskilo'),
          headers: admin,
        ),
      );
    }
  }
  final issuer = fed?['issuer'];
  if (kind == 'oidc' && issuer is String) {
    canonicalDiscovery = doc(
      await http.get(Uri.parse('$issuer/.well-known/openid-configuration')),
    );
  }

  Map<String, Object?>? canonicalClient;
  final installation = db?['installation_id'];
  final canonicalRef = at.canonicalRef;
  if (canonicalRef != null &&
      installation is String &&
      RegExp(r'^[0-9a-f-]{36}$').hasMatch(installation)) {
    final rows = await _read(
      () => api.query(canonicalRef, '''
select target_installation_id::text as target_installation_id, target_auth_url, enabled
  from public.identity_federation_clients
 where target_installation_id = '$installation'::uuid'''),
    );
    canonicalClient = rows != null && rows.length == 1 ? rows.single : null;
  }

  return McpTargetEvidence(
    ref: ref,
    schemaMarker: marker,
    database: db,
    authUrl: at.authUrl,
    authConfig: auth,
    authDiscovery: discovery,
    jwks: jwks,
    canonicalDiscovery: canonicalDiscovery,
    federationProvider: provider,
    canonicalClient: canonicalClient,
    oauthClientIds: clientIds,
    secretDigests: digests,
    deployedFunctions: functions,
    anonymousEndpointStatus: anonymous?.status,
    resourceMetadata: metadata,
    catalogue: catalogue,
    contractLines: lines == null
        ? null
        : {for (final r in lines) '${r['line']}'},
  );
}
