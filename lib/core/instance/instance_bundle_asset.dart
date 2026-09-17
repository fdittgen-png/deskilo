// SPDX-License-Identifier: 0BSD
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'instance_bundle.dart';
import 'instance_doctor.dart';
import 'instance_policies.dart';
import 'schema_compatibility.dart';
import 'management_api.dart';

part 'instance_bundle_asset.g.dart';

/// The bundled schema and functions, read from the app's assets (#977).
Future<InstanceBundle> loadInstanceBundleAsset() async =>
    parseInstanceBundle(await rootBundle.loadString(InstanceBundle.assetPath));

/// How the wizard gets its bundle — the asset, or a small one in tests.
@Riverpod(keepAlive: true)
Future<InstanceBundle> Function() instanceBundleLoader(Ref ref) =>
    loadInstanceBundleAsset;

/// How the wizard talks to Supabase for a given access token — the real
/// API, or a fake in tests. The token lives in the wizard's state only.
@Riverpod(keepAlive: true)
SupabaseManagement Function(String accessToken) supabaseManagementFactory(
        Ref ref) =>
    (token) => DioSupabaseManagement(token);

/// #1308 S3 — the in-app doctor: the same `InstanceDoctor.examine` the CLI
/// runs, judged against the bundle and the policy list this app carries.
/// One runner for the wizard's finish and the Server screen's full check
/// (#1309); tests replace it with canned findings.
@Riverpod(keepAlive: true)
Future<List<DoctorFinding>> Function(SupabaseManagement api, String projectRef)
    instanceDoctorRunner(Ref ref) => (api, projectRef) async {
          final bundle = await ref.read(instanceBundleLoaderProvider)();
          final policies = await loadInstancePoliciesAsset();
          return InstanceDoctor(api).examine(
            projectRef,
            required: int.tryParse(bundle.schemaVersion) ?? requiredSchemaVersion,
            bundleMigrations: [for (final m in bundle.schema) m.name],
            expectedPolicies: policies,
          );
        };
