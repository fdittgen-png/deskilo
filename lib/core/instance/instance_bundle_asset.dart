// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:archive/archive.dart' show GZipDecoder;
import 'package:flutter/foundation.dart' show Uint8List, compute, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'instance_bundle.dart';
import 'instance_doctor.dart';
import 'instance_policies.dart';
import 'management_api.dart';
import 'schema_compatibility.dart';

part 'instance_bundle_asset.g.dart';

/// The bundled schema and functions, read from the app's assets (#977).
/// #3102 — the build gzips the asset; a run without the transformer (a test
/// reading the plain file) gets the JSON as it is. Decoded and parsed off
/// the UI isolate.
Future<InstanceBundle> _loadInstanceBundleAsset() async {
  final data = await rootBundle.load(InstanceBundle.assetPath);
  return compute(
    decodeInstanceBundleAsset,
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

/// The bundle from the asset's bytes, gzipped (a build) or plain.
@visibleForTesting
InstanceBundle decodeInstanceBundleAsset(Uint8List bytes) {
  final gzipped = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  return parseInstanceBundle(
    utf8.decode(gzipped ? const GZipDecoder().decodeBytes(bytes) : bytes),
  );
}

/// How the wizard gets its bundle — the asset, or a small one in tests.
@Riverpod(keepAlive: true)
Future<InstanceBundle> Function() instanceBundleLoader(Ref ref) =>
    _loadInstanceBundleAsset;

/// How the wizard talks to Supabase for a given access token — the real
/// API, or a fake in tests. The token lives in the wizard's state only.
@Riverpod(keepAlive: true)
SupabaseManagement Function(String accessToken) supabaseManagementFactory(
        Ref ref) =>
    DioSupabaseManagement.new;

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
