// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- writes the settings registry's offline copy and, given a
// migration, its seed block.
//
//   dart run tool/build_settings_seed.dart
//   dart run tool/build_settings_seed.dart --migration supabase/migrations/NNNN_settings_registry.sql --since settings_registry
//
// `test/tool/settings_seed_test.dart` fails when either differs from what
// `tool/settings/seed.dart` declares.
import 'dart:io';

import 'settings/seed.dart';

void main(List<String> args) {
  final out = File('assets/instance/settings_registry.json')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(settingRegistryJson());
  stdout.writeln('wrote ${out.path}: ${settingSeeds.length} setting(s)');
  File('lib/core/settings/setting_defaults.g.dart').writeAsStringSync(settingDefaultsDart());
  final i = args.indexOf('--migration');
  final j = args.indexOf('--since');
  if (i >= 0 && i + 1 < args.length && j >= 0 && j + 1 < args.length) {
    final file = File(args[i + 1]);
    file.writeAsStringSync(withSettingSeed(file.readAsStringSync(), args[j + 1]));
    stdout.writeln('rewrote the seed block of ${file.path}');
  }
}
