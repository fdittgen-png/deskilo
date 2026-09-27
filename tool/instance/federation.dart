// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648 — operator-only staging through the supported Auth admin API.
// Staging deliberately cannot enable sign-in: account-linking isolation and
// canonical business-token containment must be proved before activation.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

const federationProvider = 'custom:deskilo';

class FederationRefused implements Exception {
  const FederationRefused(this.code);
  final String code;
  @override
  String toString() => code;
}

/// Exact Auth endpoint, not a project URL to which /auth/v1 is appended.
Uri federationEndpoint(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
      uri.hasQuery || uri.hasFragment ||
      (uri.scheme != 'https' &&
          !(uri.scheme == 'http' &&
              {'127.0.0.1', '::1', 'localhost'}.contains(uri.host))) ||
      uri.path.endsWith('/') || uri.path.contains('//')) {
    throw const FederationRefused('invalid_auth_endpoint');
  }
  return uri;
}

/// Never prints response bodies, request headers, secrets, or Dio exceptions.
class FederationStager {
  FederationStager({
    required this.authUrl,
    required String adminKey,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    federationEndpoint(authUrl.toString());
    if (adminKey.isEmpty) throw const FederationRefused('missing_admin_key');
    _dio.options = BaseOptions(
      baseUrl: authUrl.toString(),
      headers: {'apikey': adminKey, 'Authorization': 'Bearer $adminKey'},
      followRedirects: false,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    );
  }

  final Uri authUrl;
  final Dio _dio;

  Future<Object?> _request(String method, String path, {Object? body}) async {
    try {
      return (await _dio.request<Object?>(
        '$authUrl$path',
        data: body,
        options: Options(method: method),
      )).data;
    } on DioException catch (e, st) {
      // trace-exempt: rethrow only a fixed code, retaining the stack; Dio
      // contains transient operator credentials and must not be logged.
      final code = switch (e.response?.statusCode) {
        401 || 403 => 'operator_not_authorized',
        404 || 501 => 'custom_provider_api_unavailable',
        _ => 'provider_request_failed',
      };
      Error.throwWithStackTrace(FederationRefused(code), st);
    }
  }

  Future<String> stage({
    required Uri issuer,
    required String clientId,
    String? clientSecret,
    bool apply = false,
  }) async {
    federationEndpoint(issuer.toString());
    if (clientId.trim().isEmpty || clientId != clientId.trim()) {
      throw const FederationRefused('invalid_client_id');
    }
    if (issuer == authUrl) {
      throw const FederationRefused('canonical_native_session_required');
    }
    final expected = <String, Object?>{
      'identifier': federationProvider,
      'provider_type': 'oidc',
      'name': 'Deskilo identity federation',
      'issuer': issuer.toString(),
      'client_id': clientId,
      'scopes': ['openid', 'profile'],
      'pkce_enabled': true,
      'skip_nonce_check': false,
      'email_optional': true,
      'enabled': false,
    };
    final listed = await _request('GET', '/admin/custom-providers');
    if (listed is! Map<String, dynamic> || listed['providers'] is! List) {
      throw const FederationRefused('malformed_provider_list');
    }
    final providers = listed['providers'] as List<dynamic>;
    if (providers.any((p) => p is! Map<String, dynamic> ||
        p['identifier'] is! String)) {
      throw const FederationRefused('malformed_provider_list');
    }
    final existing = providers.where((p) =>
        (p as Map<String, dynamic>)['identifier'] == federationProvider);
    if (existing.isNotEmpty) {
      // Never update, disable, or rotate an existing deployment implicitly.
      throw const FederationRefused('provider_already_exists');
    }
    if (!apply) return 'dry_run_provider_disabled';
    if (clientSecret == null || clientSecret.isEmpty) {
      throw const FederationRefused('missing_client_secret');
    }
    await _request('POST', '/admin/custom-providers', body: {
      ...expected, 'client_secret': clientSecret,
    });
    final readback = await _request(
      'GET', '/admin/custom-providers/$federationProvider',
    );
    if (readback is! Map<String, dynamic> || expected.entries.any((entry) =>
        jsonEncode(readback[entry.key]) != jsonEncode(entry.value))) {
      throw const FederationRefused('provider_readback_mismatch');
    }
    return 'provider_staged_disabled';
  }

  void close() => _dio.close();
}

Future<int> runFederationStage(
  List<String> argv, {
  Map<String, String>? environment,
  IOSink? out,
}) async {
  final output = out ?? stdout;
  final env = environment ?? Platform.environment;
  final options = <String, String>{};
  var apply = false;
  try {
    for (var i = 0; i < argv.length; i++) {
      if (argv[i] == '--apply' && !apply) {
        apply = true;
      } else if ({'--auth-url', '--issuer', '--client-id'}.contains(argv[i]) &&
          !options.containsKey(argv[i]) && i + 1 < argv.length &&
          !argv[i + 1].startsWith('--')) {
        final key = argv[i];
        options[key] = argv[++i];
      } else {
        throw const FederationRefused('invalid_arguments');
      }
    }
    if (options.length != 3) {
      throw const FederationRefused('auth_url_issuer_client_id_required');
    }
    final authUrl = federationEndpoint(options['--auth-url']!);
    final issuer = federationEndpoint(options['--issuer']!);
    final stager = FederationStager(
      authUrl: authUrl,
      adminKey: env['DESKILO_TARGET_AUTH_ADMIN_KEY'] ?? '',
    );
    try {
      final result = await stager.stage(
        issuer: issuer,
        clientId: options['--client-id']!,
        clientSecret: env['DESKILO_FEDERATION_CLIENT_SECRET'],
        apply: apply,
      );
      output.writeln(jsonEncode({
        'status': result,
        'auth_url': authUrl.toString(),
        'provider_callback': '$authUrl/callback',
        'issuer': issuer.toString(),
        'client_id': options['--client-id'],
        'purpose': 'identity_federation',
        'native_federation_ready': false,
        'mcp_ready': false,
      }));
      return 0;
    } finally {
      stager.close();
    }
  } on FederationRefused catch (e) {
    // trace-exempt: fixed public error code is the CLI diagnostic; no secrets.
    output.writeln(jsonEncode({'status': 'refused', 'reason': e.code}));
    return 1;
  }
}
