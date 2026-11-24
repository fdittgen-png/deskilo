// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    () async {
      // `loadString` decodes a string of more than 50 KB in an isolate, which takes real time the app and its tests did not count on
      // once the registry crossed that size (#4431 did): the bytes are decoded here, in the same turn, as they were before.
      final data = await rootBundle.load(_settingsAssetPath);
      return _parseSettingsBundle(utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
    };
