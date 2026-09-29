// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648 — install the supported canonical Auth hook without replacing another
// hook. No OAuth client/provider is enabled by this operator-only command.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';
import 'package:deskilo/core/instance/mcp_auth_checks.dart';
import 'package:dio/dio.dart';

import 'federation.dart';

const identityHookUri = canonicalIdentityHookUri;
const _enabled = 'hook_custom_access_token_enabled';
const _uri = 'hook_custom_access_token_uri';

Future<String> configureIdentityHook(SupabaseManagement api, String ref,
    {bool apply = false}) async {
  if (!RegExp(r'^[a-z0-9]{20}$').hasMatch(ref)) {
    throw const FederationRefused('invalid_canonical_project_ref');
  }
  final config = await api.authConfig(ref);
  if (!config.containsKey(_enabled) || !config.containsKey(_uri) ||
      (config[_enabled] != null && config[_enabled] is! bool) ||
      (config[_uri] != null && config[_uri] is! String)) {
    throw const FederationRefused('hook_config_unavailable');
  }
  final uri = config[_uri];
  if ((uri != null && uri != '' && uri != identityHookUri) ||
      (config[_enabled] == true && uri != identityHookUri)) {
    throw const FederationRefused('existing_hook_requires_composition');
  }
  final rows = await api.query(ref, '''
select case when to_regprocedure(
  'public.identity_federation_token_hook(jsonb)') is null then false
else has_function_privilege('supabase_auth_admin',
  'public.identity_federation_token_hook(jsonb)', 'execute') end as installed
''');
  if (rows.length != 1 || rows.single['installed'] != true) {
    throw const FederationRefused('identity_hook_schema_required');
  }
  if (!apply) return 'dry_run_identity_hook';
  if (config[_enabled] != true) {
    await api.patchAuthConfig(ref, {_enabled: true, _uri: identityHookUri});
  }
  final readback = await api.authConfig(ref);
  if (readback[_enabled] != true || readback[_uri] != identityHookUri) {
    throw const FederationRefused('identity_hook_readback_mismatch');
  }
  return 'identity_hook_configured';
}

Future<int> runFederationHook(List<String> args,
    {Map<String, String>? environment, IOSink? out}) async {
  final output = out ?? stdout;
  final env = environment ?? Platform.environment;
  Dio? dio;
  try {
    final apply = args.length == 3 && args.last == '--apply';
    if (!(args.length == 2 || apply) || args.first != '--ref') {
      throw const FederationRefused('canonical_ref_required');
    }
    final token = env['SUPABASE_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      throw const FederationRefused('missing_management_token');
    }
    dio = Dio(BaseOptions(
      baseUrl: DioSupabaseManagement.baseUrl,
      headers: {'Authorization': 'Bearer $token'},
      followRedirects: false,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ));
    final status = await configureIdentityHook(
        DioSupabaseManagement(token, dio: dio), args[1], apply: apply);
    output.writeln(jsonEncode({
      'status': status, 'canonical_ref': args[1],
      'native_federation_ready': false, 'mcp_ready': false,
    }));
    return 0;
  } on FederationRefused catch (e) {
    // trace-exempt: only fixed codes are emitted; no operator credentials.
    output.writeln(jsonEncode({'status': 'refused', 'reason': e.code}));
    return 1;
  } on ManagementApiException {
    // trace-exempt: API messages can contain secrets; emit a fixed code only.
    output.writeln(jsonEncode({
      'status': 'refused', 'reason': 'identity_hook_operator_request_failed',
    }));
    return 1;
  } finally {
    dio?.close();
  }
}
