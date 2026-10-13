// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- the registry's rows are declared once (tool/settings/seed.dart)
// and land in four places: the migration's seed block, the app's bundled
// registry, the compile-time defaults and the editor's labels. Pinned
// against the declaration, and the bundled registry is read back through
// the app's own parser so a row the app cannot read fails here.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/workspace/presentation/settings_labels.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/settings/seed.dart';

void main() {
  test('the bundled registry is what the declaration writes, and the app parses it', () {
    final text = File('assets/instance/settings_registry.json').readAsStringSync();
    expect(text, settingRegistryJson(), reason: 'dart run tool/build_settings_seed.dart');
    final defs = [for (final r in jsonDecode(text) as List) SettingDefinition.fromJson(r)];
    expect(defs.map((d) => d.key), [for (final s in settingSeeds) s.row.key]..sort());
  });

  test('every migration that creates rows carries exactly its block', () {
    for (final since in {for (final s in settingSeeds) s.since}) {
      final file = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('_$since.sql'));
      expect(settingSeedBlockOf(file.readAsStringSync()), settingSeedSql(since),
          reason: 'dart run tool/build_settings_seed.dart --migration ${file.path} --since $since');
    }
  });

  test('the compile-time defaults are the declaration\'s', () {
    expect(File('lib/core/settings/setting_defaults.g.dart').readAsStringSync(),
        settingDefaultsDart());
    expect(SettingDefaults.dunningFirstAfterDays, 14);
  });

  test('every registered setting has a label, a group name and a unit name in English', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final s in settingSeeds) {
      final r = s.row;
      expect(settingLabel(l10n, r.key), isNot(r.key), reason: '${r.key} needs an ARB label');
      expect(settingHint(l10n, r.key), isNotNull, reason: '${r.key} needs an ARB hint');
      expect(settingGroupLabel(l10n, r.group), isNot(r.group), reason: 'group ${r.group}');
      if (r.unit.isNotEmpty) {
        expect(settingUnitLabel(lookupAppLocalizations(const Locale('de')), r.unit), isNot(r.unit),
            reason: 'unit ${r.unit} needs a name');
      }
    }
  });
}
