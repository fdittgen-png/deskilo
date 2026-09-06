// SPDX-License-Identifier: 0BSD
import 'dart:math';

import 'instance_bundle.dart';
import 'management_api.dart';

/// The regions a project can live in, with the label a person reads.
/// The nearest one is pre-selected from the workspace's country.
const List<({String code, String label})> supabaseRegions = [
  (code: 'eu-west-3', label: 'Paris (eu-west-3)'),
  (code: 'eu-central-1', label: 'Frankfurt (eu-central-1)'),
  (code: 'eu-central-2', label: 'Zurich (eu-central-2)'),
  (code: 'eu-west-1', label: 'Ireland (eu-west-1)'),
  (code: 'eu-west-2', label: 'London (eu-west-2)'),
  (code: 'eu-north-1', label: 'Stockholm (eu-north-1)'),
  (code: 'us-east-1', label: 'Virginia (us-east-1)'),
  (code: 'us-west-1', label: 'California (us-west-1)'),
  (code: 'ca-central-1', label: 'Canada (ca-central-1)'),
  (code: 'ap-southeast-1', label: 'Singapore (ap-southeast-1)'),
  (code: 'ap-northeast-1', label: 'Tokyo (ap-northeast-1)'),
  (code: 'ap-southeast-2', label: 'Sydney (ap-southeast-2)'),
  (code: 'sa-east-1', label: 'São Paulo (sa-east-1)'),
];

String defaultRegionFor(String countryCode) => switch (countryCode.toUpperCase()) {
      'FR' || 'BE' || 'LU' || 'ES' || 'PT' => 'eu-west-3',
      'DE' || 'AT' || 'NL' || 'PL' || 'CZ' || 'DK' || 'IT' => 'eu-central-1',
      'CH' => 'eu-central-2',
      'GB' || 'IE' => 'eu-west-2',
      'SE' || 'NO' || 'FI' => 'eu-north-1',
      'US' => 'us-east-1',
      'CA' => 'ca-central-1',
      'AU' || 'NZ' => 'ap-southeast-2',
      'JP' => 'ap-northeast-1',
      'BR' => 'sa-east-1',
      _ => 'eu-west-1',
    };

/// A database password the person never has to invent: letters and
/// digits only, so nothing needs quoting anywhere.
String generateDatabasePassword([Random? random]) {
  const alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  final r = random ?? Random.secure();
  return String.fromCharCodes(
      List.generate(24, (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length))));
}

/// Where the app lives on the web and what its sign-in links look like:
/// what the new instance's auth must allow.
abstract final class InstanceAuthConfig {
  static const String siteUrl = 'https://fdittgen-png.github.io/deskilo/';
  static const String redirectAllowList =
      'deskilo://**,https://fdittgen-png.github.io/deskilo/**';

  static Map<String, Object?> get patch => {
        'mailer_autoconfirm': false,
        'site_url': siteUrl,
        'uri_allow_list': redirectAllowList,
      };
}

/// A step's progress: how many of [total] are done and the name of the
/// current item.
typedef InstanceProgress = ({int done, int total, String current});

/// Where the schema install stopped, for the screen: the migration and
/// the database's own words.
class InstanceStepFailure implements Exception {
  const InstanceStepFailure(this.item, this.message);
  final String item;
  final String message;
  @override
  String toString() => 'InstanceStepFailure($item): $message';
}

/// The steps that build a new instance (#977), each one retryable on
/// its own. Pure orchestration over [SupabaseManagement]; the screen and
/// the CLI both drive it.
class InstanceBuilder {
  const InstanceBuilder(this.api);

  final SupabaseManagement api;

  /// Creates the project and waits until it answers. [poll] is the wait
  /// between two status reads; tests pass zero.
  Future<SupabaseProject> createProject({
    required String organizationId,
    required String name,
    required String region,
    required String databasePassword,
    Duration poll = const Duration(seconds: 5),
    int maxPolls = 120,
    void Function(String status)? onStatus,
  }) async {
    final created = await api.createProject(
      organizationId: organizationId,
      name: name,
      region: region,
      databasePassword: databasePassword,
    );
    return waitUntilReady(created.ref,
        poll: poll, maxPolls: maxPolls, onStatus: onStatus);
  }

  Future<SupabaseProject> waitUntilReady(
    String ref, {
    Duration poll = const Duration(seconds: 5),
    int maxPolls = 120,
    void Function(String status)? onStatus,
  }) async {
    for (var i = 0; i < maxPolls; i++) {
      final p = await api.project(ref);
      onStatus?.call(p.status);
      if (p.status == 'ACTIVE_HEALTHY') return p;
      if (p.status.contains('FAIL') || p.status == 'INACTIVE') {
        throw InstanceStepFailure(ref, p.status);
      }
      if (poll > Duration.zero) await Future<void>.delayed(poll);
    }
    throw InstanceStepFailure(ref, 'still not ready');
  }

  /// Runs every migration in order, stopping at the first failure with
  /// the migration named. [skip] migrations already applied (a resume).
  Future<void> installSchema(
    String ref,
    InstanceBundle bundle, {
    int skip = 0,
    void Function(InstanceProgress progress)? onProgress,
  }) async {
    final total = bundle.schema.length;
    for (var i = skip; i < total; i++) {
      final migration = bundle.schema[i];
      onProgress?.call((done: i, total: total, current: migration.name));
      try {
        await api.runSql(ref, migration.sql);
      } on ManagementApiException catch (e, st) {
        // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
        Error.throwWithStackTrace(InstanceStepFailure(migration.name, e.message), st);
      }
    }
    onProgress?.call((done: total, total: total, current: ''));
  }

  Future<void> deployFunctions(
    String ref,
    InstanceBundle bundle, {
    void Function(InstanceProgress progress)? onProgress,
  }) async {
    final total = bundle.functions.length;
    for (var i = 0; i < total; i++) {
      final f = bundle.functions[i];
      onProgress?.call((done: i, total: total, current: f.slug));
      try {
        await api.deployFunction(ref,
            slug: f.slug, verifyJwt: f.verifyJwt, files: f.files);
      } on ManagementApiException catch (e, st) {
        // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
        Error.throwWithStackTrace(InstanceStepFailure(f.slug, e.message), st);
      }
    }
    onProgress?.call((done: total, total: total, current: ''));
  }

  Future<void> configureAuth(String ref) async {
    try {
      await api.patchAuthConfig(ref, InstanceAuthConfig.patch);
    } on ManagementApiException catch (e, st) {
      // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
      Error.throwWithStackTrace(InstanceStepFailure('auth', e.message), st);
    }
  }

  /// The endpoint the devices will use.
  Future<({String url, String key})> endpointOf(String ref) async =>
      (url: 'https://$ref.supabase.co', key: await api.publishableKey(ref));
}
