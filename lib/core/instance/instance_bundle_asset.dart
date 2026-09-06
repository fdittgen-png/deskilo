// SPDX-License-Identifier: 0BSD
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'instance_bundle.dart';
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
