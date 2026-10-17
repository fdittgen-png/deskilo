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
  (
    since: 'security_settings',
    row: (
      key: 'security.badge_lockout_failures',
      type: 'int',
      defaultValue: 5,
      min: 1,
      max: 5,
      unit: 'attempts',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'badge_auth_verify (0123, 0124)',
      note: 'Failed badge PIN attempts within the lockout window before a badge is locked. May be tightened (fewer attempts), never loosened.',
    ),
  ),
  (
    since: 'security_settings',
    row: (
      key: 'security.badge_lockout_minutes',
      type: 'duration',
      defaultValue: 15,
      min: 15,
      max: 1440,
      unit: 'minutes',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'badge_auth_verify (0123, 0124)',
      note: 'Minutes over which failed badge PIN attempts are counted, and for which a locked badge stays locked. May be lengthened, never shortened.',
    ),
  ),
  (
    since: 'security_settings',
    row: (
      key: 'security.invitation_expiry_days',
      type: 'duration',
      defaultValue: 14,
      min: 1,
      max: 14,
      unit: 'days',
      group: 'security',
      scopes: ['platform', 'workspace'],
      editPermission: 'manageMembers',
      floor: null,
      editable: true,
      choices: null,
      source: 'create_invitation (0051, 0361)',
      note: 'Days a personal invitation stays redeemable. An invitation keeps the expiry it was created with. May be shortened, never lengthened.',
    ),
  ),
  (
    since: 'security_settings',
    row: (
      key: 'mcp.confirmation_expiry_minutes',
      type: 'duration',
      defaultValue: 5,
      min: 1,
      max: 5,
      unit: 'minutes',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'mcp_action_confirmations (0272)',
      note: 'Minutes an assistant-requested action waits for the person to confirm it. A confirmation keeps the expiry it was created with. May be shortened, never lengthened.',
    ),
  ),
  (
    since: 'security_settings',
    row: (
      key: 'mcp.probe_freshness_minutes',
      type: 'duration',
      defaultValue: 15,
      min: 1,
      max: 15,
      unit: 'minutes',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'instance_mcp_overview, instance_set_mcp_runtime (0343, 0360)',
      note: 'Minutes a successful check of the MCP endpoint stays fresh enough to turn the interface on. May be shortened, never lengthened.',
    ),
  ),
  (
    since: 'security_settings',
    row: (
      key: 'messaging.group_creation_per_hour',
      type: 'int',
      defaultValue: 10,
      min: 1,
      max: 10,
      unit: 'per hour',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'create_account_group (0384)',
      note: 'Groups one person may create per hour. May be lowered, never raised.',
    ),
  ),
  (
    since: 'security_settings',
    row: (
      key: 'messaging.message_requests_per_day',
      type: 'int',
      defaultValue: 10,
      min: 1,
      max: 10,
      unit: 'per day',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'send_account_message (0388)',
      note: 'Message requests one person may send per day to people who did not allow them. May be lowered, never raised.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'booking.check_in_leeway_minutes',
      type: 'duration',
      defaultValue: 15,
      min: 0,
      max: 240,
      unit: 'minutes',
      group: 'booking',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'check_in_reservation, kiosk_act (0113, 0119, 0122); Reservation.checkInLeeway',
      note: 'How many minutes before its start a booking can be checked in. A minute grid wider than this widens it to one grid step.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'booking.check_in_reminder_lead_minutes',
      type: 'duration',
      defaultValue: 15,
      min: 1,
      max: 120,
      unit: 'minutes',
      group: 'booking',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'calendar_items (0133, 0428); upcomingCheckInReminders',
      note: 'Minutes before a booking starts at which the check-in reminder is shown.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'booking.check_in_reminder_lookahead_days',
      type: 'int',
      defaultValue: 7,
      min: 1,
      max: 30,
      unit: 'days',
      group: 'booking',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: false,
      choices: null,
      source: 'upcomingCheckInReminders',
      note: 'Guardrail: how many days ahead a device schedules check-in reminders. A device scheduling horizon, not a booking rule.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'booking.walk_up_window_minutes',
      type: 'duration',
      defaultValue: 240,
      min: 15,
      max: 1440,
      unit: 'minutes',
      group: 'booking',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'walkUpWindow',
      note: 'Length of the stay booked on the spot (badge or space code) when the workspace books by the minute.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'booking.walk_up_floor_minutes',
      type: 'duration',
      defaultValue: 15,
      min: 1,
      max: 60,
      unit: 'minutes',
      group: 'booking',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'walkUpWindow',
      note: 'Shortest stay booked on the spot, used when the usual window would cross the end of the day.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'booking.intent_ledger_cap',
      type: 'int',
      defaultValue: 20,
      min: 5,
      max: 100,
      unit: 'entries',
      group: 'booking',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: false,
      choices: null,
      source: 'BookingIntentLedger',
      note: 'Guardrail: how many unanswered booking questions one device keeps. A local recovery list, not an owner choice.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'billing.max_advance_days',
      type: 'int',
      defaultValue: 28,
      min: 0,
      max: 28,
      unit: 'days',
      group: 'billing',
      scopes: ['platform'],
      editPermission: 'manageBilling',
      floor: null,
      editable: false,
      choices: null,
      source: 'BillingRules; subscription run clamp (server)',
      note: 'Guardrail: the longest lead, in days, of a subscription invoice before the month starts. The server clamps to the same value.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'directory.upcoming_window_days',
      type: 'int',
      defaultValue: 14,
      min: 1,
      max: 90,
      unit: 'days',
      group: 'directory',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'DirectoryReservationRules',
      note: 'How many days ahead the member directory shows the next booking of a member.',
    ),
  ),
  (
    since: 'booking_windows',
    row: (
      key: 'presence.online_window_minutes',
      type: 'duration',
      defaultValue: 5,
      min: 3,
      max: 60,
      unit: 'minutes',
      group: 'presence',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'PresenceRules',
      note: 'Minutes after its last heartbeat a person still counts as online. Keep it above the 2-minute heartbeat.',
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
