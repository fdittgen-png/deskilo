// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/json_reader.dart';
import '../settings/settings.dart';

part 'settings_bundle_asset.g.dart';

const _settingsAssetPath = 'assets/instance/settings_registry.json';

List<SettingDefinition> _parseSettingsBundle(String json) {
  final raw = jsonDecode(json);
  if (raw is! List) {
    throw JsonShapeException('settings_registry', '', 'list', '${raw.runtimeType}');
  }
  return [for (final row in raw) SettingDefinition.fromJson(row)];
}

/// The registry as the app ships it (#2484): keys, types, bounds and
/// defaults, no stored values. What a build with no reachable server
/// stands on. A canned list in tests.
@Riverpod(keepAlive: true)
Future<List<SettingDefinition>> Function() settingsBundleLoader(Ref ref) =>
    () async => _parseSettingsBundle(await rootBundle.loadString(_settingsAssetPath));
