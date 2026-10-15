// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- the settings registry's rows, declared ONCE here and written to
// the two places that carry them: the migration that creates them
// (`insert into public.setting_definitions`) and the copy the app ships in
// `assets/instance/settings_registry.json` (so a build with no reachable
// server still knows every key, bound and default). A new setting adds one
// entry below, one ARB label, and a migration whose seed block this tool
// writes; the editor needs nothing else.
//
// This file is the only place outside the database where a default lives.
import 'dart:convert';

/// One registry row, as the tool declares it.
typedef SettingSeed = ({
  String key,
  String type,
  Object defaultValue,
  num? min,
  num? max,
  String unit,
  String group,
  List<String> scopes,
  String editPermission,
  num? floor,
  bool editable,
  List<String>? choices,
  String source,
  String note,
});

/// Every registry row, sorted by key. `since` names the migration that
/// created a row, so a later migration's block holds only its own rows.
const List<({SettingSeed row, String since})> settingSeeds = [
  (
    since: 'settings_registry',
    row: (
      key: 'dunning.first_after_days',
      type: 'int',
      defaultValue: 14,
      min: 1,
      max: 365,
      unit: 'days',
      group: 'dunning',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'DunningRules (#472, 0093, 0134, 0144, 0145)',
      note: 'Days after issue before a first reminder is suggested and before '
          'an invoice falls due when the workspace stated no payment term.',
    ),
  ),
];

String _q(String s) => "'${s.replaceAll("'", "''")}'";

String _num(num? n) => n == null ? 'null' : '$n';

/// The migration's seed block: the rows [since] created, as one insert.
String settingSeedSql(String since) {
  final rows = [
    for (final s in settingSeeds)
      if (s.since == since) s.row,
  ];
  final lines = [
    for (final r in rows)
      '(${_q(r.key)}, ${_q(r.type)}, ${_q(jsonEncode(r.defaultValue))}::jsonb, '
          '${_num(r.min)}, ${_num(r.max)}, ${_q(r.unit)}, ${_q(r.group)}, '
          "array[${r.scopes.map(_q).join(', ')}], ${_q(r.editPermission)}, "
          '${_num(r.floor)}, ${r.editable}, '
          "${r.choices == null ? 'null' : '${_q(jsonEncode(r.choices))}::jsonb'}, "
          '${_q(r.source)}, ${_q(r.note)})',
  ];
  return 'insert into public.setting_definitions\n'
      '  (key, type, default_value, min_value, max_value, unit, group_key, scopes,\n'
      '   edit_permission, floor_value, editable, choices, source, note)\n'
      'values\n${lines.join(',\n')}\n'
      'on conflict (key) do nothing;';
}

const seedBegin = '-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)';
const seedEnd = '-- END GENERATED SEED';

/// [migration] with its seed block replaced by the rows [since] created.
String withSettingSeed(String migration, String since) {
  final start = migration.indexOf(seedBegin);
  final end = migration.indexOf(seedEnd);
  if (start < 0 || end < start) {
    throw StateError('the migration has no seed block');
  }
  return '${migration.substring(0, start)}$seedBegin\n'
      '${settingSeedSql(since)}\n${migration.substring(end)}';
}

/// The seed block of [migration], as written.
String? settingSeedBlockOf(String migration) {
  final start = migration.indexOf(seedBegin);
  final end = migration.indexOf(seedEnd);
  if (start < 0 || end < start) return null;
  return migration.substring(start + seedBegin.length + 1, end - 1);
}

/// The app's offline copy: one row per line, sorted by key.
String settingRegistryJson() {
  final rows = [for (final s in settingSeeds) s.row]
    ..sort((a, b) => a.key.compareTo(b.key));
  final lines = [
    for (final r in rows)
      jsonEncode({
        'key': r.key,
        'type': r.type,
        'default_value': r.defaultValue,
        'min': r.min,
        'max': r.max,
        'unit': r.unit,
        'group_key': r.group,
        'scopes': r.scopes,
        'edit_permission': r.editPermission,
        'floor_value': r.floor,
        'editable': r.editable,
        'choices': r.choices,
        'source': r.source,
        'note': r.note,
      }),
  ];
  return '[\n${lines.join(',\n')}\n]\n';
}

/// `dunning.first_after_days` -> `dunningFirstAfterDays`.
String settingConstName(String key) {
  final parts = key.split(RegExp(r'[._]'));
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// The compile-time copy of the registry defaults, for the places a Dart
/// `const` needs one (a value class's default, an offline last resort). It
/// is GENERATED from the rows above so there is no second place to type a
/// default; the live value is always the registry's, through `SettingsSet`.
String settingDefaultsDart() {
  final rows = [for (final s in settingSeeds) s.row]
    ..sort((a, b) => a.key.compareTo(b.key));
  final b = StringBuffer()
    ..writeln('// SPDX-License-Identifier: AGPL-3.0-or-later')
    ..writeln('// GENERATED by `dart run tool/build_settings_seed.dart` -- do not edit.')
    ..writeln('//')
    ..writeln('// The registry defaults as compile-time constants (#2484): for a value')
    ..writeln('// class\'s default and the offline last resort only. The live value is')
    ..writeln('// the registry\'s, read through `SettingsSet`.')
    ..writeln()
    ..writeln('abstract final class SettingDefaults {');
  for (final r in rows) {
    final dartType = switch (r.type) {
      'bool' => 'bool',
      'text' || 'enum' => 'String',
      _ => 'int',
    };
    final literal = r.defaultValue is String ? "'${r.defaultValue}'" : '${r.defaultValue}';
    b
      ..writeln('  /// `${r.key}`')
      ..writeln('  static const $dartType ${settingConstName(r.key)} = $literal;');
  }
  b.writeln('}');
  return b.toString();
}
