// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:dio/dio.dart';

/// A Supabase organisation the token can create projects in.
typedef SupabaseOrganization = ({String id, String name});

/// A Supabase project as the Management API lists it.
typedef SupabaseProject = ({
  String ref,
  String name,
  String organizationId,
  String region,
  String status,
});

/// What the Management API answered that the wizard cannot proceed on:
/// the status and the message, for the screen and the trace.
class ManagementApiException implements Exception {
  const ManagementApiException(this.status, this.message);

  final int status;
  final String message;

  bool get unauthorized => status == 401 || status == 403;

  @override
  String toString() => 'ManagementApiException($status): $message';
}

/// The slice of the Supabase Management API the instance wizard needs
/// (#977). An interface so the wizard and the CLI can be driven by a
/// fake; [DioSupabaseManagement] is the real one.
abstract class SupabaseManagement {
  Future<List<SupabaseOrganization>> listOrganizations();
  Future<List<SupabaseProject>> listProjects();
  Future<SupabaseProject> createProject({
    required String organizationId,
    required String name,
    required String region,
    required String databasePassword,
  });
  Future<SupabaseProject> project(String ref);

  /// Runs [sql] against the project's database as the postgres role.
  Future<void> runSql(String ref, String sql);

  /// Deploys one edge function from its sources.
  Future<void> deployFunction(
    String ref, {
    required String slug,
    required bool verifyJwt,
    required List<({String name, String content})> files,
  });

  /// The project's publishable key (`sb_publishable_…`), else the
  /// legacy anon key.
  Future<String> publishableKey(String ref);

  /// Patches the auth configuration (e-mail confirmation, allowed
  /// redirect URIs).
  Future<void> patchAuthConfig(String ref, Map<String, Object?> config);
}

class DioSupabaseManagement implements SupabaseManagement {
  DioSupabaseManagement(String accessToken, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              headers: {'Authorization': 'Bearer $accessToken'},
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 3),
            ));

  static const baseUrl = 'https://api.supabase.com';

  final Dio _dio;

  Future<T> _call<T>(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (e, st) {
      // trace-exempt: rethrown as ManagementApiException, stack kept; the wizard traces.
      final data = e.response?.data;
      final message = switch (data) {
        Map<dynamic, dynamic> m => '${m['message'] ?? m['error'] ?? data}',
        String s when s.isNotEmpty => s,
        _ => e.message ?? 'network error',
      };
      Error.throwWithStackTrace(
          ManagementApiException(e.response?.statusCode ?? 0, message), st);
    }
  }

  SupabaseProject _project(Map<dynamic, dynamic> m) => (
        ref: '${m['id']}',
        name: '${m['name']}',
        organizationId: '${m['organization_id'] ?? ''}',
        region: '${m['region'] ?? ''}',
        status: '${m['status'] ?? ''}',
      );

  @override
  Future<List<SupabaseOrganization>> listOrganizations() async {
    final list = await _call<List<dynamic>>(() => _dio.get('/v1/organizations'));
    return [
      for (final o in list.cast<Map<dynamic, dynamic>>())
        (id: '${o['id']}', name: '${o['name']}'),
    ];
  }

  @override
  Future<List<SupabaseProject>> listProjects() async {
    final list = await _call<List<dynamic>>(() => _dio.get('/v1/projects'));
    return [for (final p in list.cast<Map<dynamic, dynamic>>()) _project(p)];
  }

  @override
  Future<SupabaseProject> createProject({
    required String organizationId,
    required String name,
    required String region,
    required String databasePassword,
  }) async {
    final m = await _call<Map<dynamic, dynamic>>(() => _dio.post(
          '/v1/projects',
          data: {
            'organization_id': organizationId,
            'name': name,
            'region': region,
            'db_pass': databasePassword,
          },
        ));
    return _project(m);
  }

  @override
  Future<SupabaseProject> project(String ref) async =>
      _project(await _call<Map<dynamic, dynamic>>(
          () => _dio.get('/v1/projects/$ref')));

  @override
  Future<void> runSql(String ref, String sql) => _call<dynamic>(() =>
      _dio.post('/v1/projects/$ref/database/query', data: {'query': sql}));

  @override
  Future<void> deployFunction(
    String ref, {
    required String slug,
    required bool verifyJwt,
    required List<({String name, String content})> files,
  }) =>
      _call<dynamic>(() => _dio.post(
            '/v1/projects/$ref/functions/deploy',
            queryParameters: {'slug': slug},
            data: FormData.fromMap({
              'metadata': jsonEncode({
                'entrypoint_path': 'index.ts',
                'name': slug,
                'verify_jwt': verifyJwt,
              }),
              'file': [
                for (final f in files)
                  MultipartFile.fromString(f.content, filename: f.name),
              ],
            }),
          ));

  @override
  Future<String> publishableKey(String ref) async {
    final list = await _call<List<dynamic>>(() => _dio.get(
        '/v1/projects/$ref/api-keys', queryParameters: {'reveal': 'true'}));
    final keys = list.cast<Map<dynamic, dynamic>>();
    for (final k in keys) {
      final key = '${k['api_key'] ?? ''}';
      if (key.startsWith('sb_publishable_')) return key;
    }
    for (final k in keys) {
      if ('${k['name']}' == 'anon') return '${k['api_key']}';
    }
    throw const ManagementApiException(404, 'no publishable key');
  }

  @override
  Future<void> patchAuthConfig(String ref, Map<String, Object?> config) =>
      _call<dynamic>(
          () => _dio.patch('/v1/projects/$ref/config/auth', data: config));
}
