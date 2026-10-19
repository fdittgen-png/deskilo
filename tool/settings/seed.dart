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
  (
    since: 'messaging_windows',
    row: (
      key: 'messaging.edit_window_minutes',
      type: 'duration',
      defaultValue: 15,
      min: 1,
      max: 1440,
      unit: 'minutes',
      group: 'messaging',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'edit_message (0382, 0384); MessagingWindows',
      note: 'Minutes after sending in which the author may still correct a message. A workspace message reads its own workspace, a personal or group message the platform value.',
    ),
  ),
  (
    since: 'messaging_windows',
    row: (
      key: 'messaging.thread_poll_seconds',
      type: 'duration',
      defaultValue: 15,
      min: 5,
      max: 300,
      unit: 'seconds',
      group: 'messaging',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'ContextThreadScreen',
      note: 'Seconds between two refreshes of an open conversation. Lower values load the server more.',
    ),
  ),
  (
    since: 'messaging_windows',
    row: (
      key: 'messaging.inbox_poll_seconds',
      type: 'duration',
      defaultValue: 30,
      min: 10,
      max: 600,
      unit: 'seconds',
      group: 'messaging',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'UnifiedInboxView; MeShell badge',
      note: 'Seconds between two refreshes of the inbox and its unread badge. Lower values load the server more.',
    ),
  ),
  (
    since: 'readiness_range_settings',
    row: (
      key: 'readiness.recent_export_days',
      type: 'duration',
      defaultValue: 90,
      min: 7,
      max: 365,
      unit: 'days',
      group: 'readiness',
      scopes: ['platform', 'workspace'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'workspace_readiness (0301, 0399)',
      note: 'Days an export the app recorded still counts as recent evidence that recovery works. Older than this, recovery reads as unverified.',
    ),
  ),
  (
    since: 'readiness_range_settings',
    row: (
      key: 'mcp.read_range_days',
      type: 'int',
      defaultValue: 31,
      min: 1,
      max: 93,
      unit: 'days',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: false,
      choices: null,
      source: 'mcp_read_v1 (0275, 0411)',
      note: 'Guardrail: the longest window one assistant read may ask for. A platform-owned bound on the query, not a permission to scan more.',
    ),
  ),
  (
    since: 'readiness_range_settings',
    row: (
      key: 'calendar.range_days',
      type: 'int',
      defaultValue: 400,
      min: 1,
      max: 800,
      unit: 'days',
      group: 'booking',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: false,
      choices: null,
      source: 'calendar_items (0133, 0428, 0452)',
      note: 'Guardrail: the longest range one calendar request may ask for. A platform-owned bound on the query.',
    ),
  ),
  (
    since: 'readiness_range_settings',
    row: (
      key: 'kpi.capacity_range_days',
      type: 'int',
      defaultValue: 400,
      min: 1,
      max: 800,
      unit: 'days',
      group: 'kpi',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: false,
      choices: null,
      source: 'kpi_seat_capacity (0333, 0336)',
      note: 'Guardrail: the longest period one capacity figure may cover. A platform-owned bound on the query.',
    ),
  ),
  (
    since: 'readiness_range_settings',
    row: (
      key: 'kpi.finance_range_months',
      type: 'int',
      defaultValue: 23,
      min: 1,
      max: 59,
      unit: 'months',
      group: 'kpi',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: false,
      choices: null,
      source: 'kpi_finance_summary (0351, 0398)',
      note: 'Guardrail: months beyond the first that one finance figure may span (23 means 24 months in all). A platform-owned bound on the query.',
    ),
  ),
  (
    since: 'retention_settings',
    row: (
      key: 'mcp.notice_read_retention_days',
      type: 'int',
      defaultValue: 90,
      min: 7,
      max: 3650,
      unit: 'days',
      group: 'security',
      scopes: ['platform'],
      editPermission: 'workspaceSettings',
      floor: null,
      editable: true,
      choices: null,
      source: 'instance_notify_operators, mark_instance_notice_read (0357)',
      note: 'Days an operator notice that has been read is kept before it is purged. Only read notices are purged: an unread notice, a grant, a consent and the audit trail are never touched by this value.',
    ),
  ),
  (
    since: 'retention_settings',
    row: (
      key: 'vat.vies_evidence_days',
      type: 'duration',
      defaultValue: 90,
      min: 1,
      max: 90,
      unit: 'days',
      group: 'vat',
      scopes: ['platform', 'workspace'],
      editPermission: 'manageBilling',
      floor: null,
      editable: true,
      choices: null,
      source: 'member_vies_verified (0404)',
      note: 'Days a valid VAT-number check stays recent enough to stand as evidence on a new invoice. A shorter value asks for a fresh check sooner; it is not proof that a transaction is valid.',
    ),
  ),
  (
    since: 'retention_us_override',
    row: (
      key: 'retention.us_years',
      type: 'int',
      defaultValue: 0,
      min: 0,
      max: 30,
      unit: 'years',
      group: 'vat',
      scopes: ['workspace'],
      editPermission: 'manageBilling',
      floor: null,
      editable: true,
      choices: null,
      source: 'retention_rule_for (0481)',
      note: 'Years a US space keeps its records when its state asks for more or less than the federal default of the retention rule. 0 means the rule applies. Never legal advice: confirm the period of your state.',
    ),
  ),
  (
    since: 'purchase_maker_checker',
    row: (
      key: 'purchase.single_approval_below_units',
      type: 'int',
      defaultValue: 0,
      min: 0,
      max: 100000,
      unit: 'currency units',
      group: 'billing',
      scopes: ['workspace'],
      editPermission: 'manageBilling',
      floor: null,
      editable: true,
      choices: null,
      source: 'decide_purchase_v1 (0468)',
      note: 'A supplier bill below this amount, in whole currency units, may be approved by the person who drafted or sent it, if that person may approve expenses. 0 keeps the rule that another person approves every bill. Rejecting always takes another person.',
    ),
  ),
  (
    since: 'purchase_maker_checker',
    row: (
      key: 'purchase.payment_checker_from_units',
      type: 'int',
      defaultValue: 0,
      min: 0,
      max: 100000000,
      unit: 'currency units',
      group: 'billing',
      scopes: ['workspace'],
      editPermission: 'manageBilling',
      floor: null,
      editable: true,
      choices: null,
      source: 'record_supplier_payment_v1 (0468)',
      note: 'A payable of at least this amount, in whole currency units, is paid by someone other than the person who approved its bill; splitting it into small payments does not get round the limit. 0 switches the rule off.',
    ),
  ),
  (
    since: 'valuation_row_limit',
    row: (
      key: 'assets.valuation_max_rows',
      type: 'int',
      defaultValue: 2000,
      min: 100,
      max: 5000,
      unit: 'rows',
      group: 'billing',
      scopes: ['workspace'],
      editPermission: 'manageBilling',
      floor: null,
      editable: true,
      choices: null,
      source: 'stage_asset_valuations_v1 (0507)',
      note: 'The most rows one batch of the accountant\'s valuations may carry, one row per asset. A larger file is split by the person who imports it; the file is refused as a whole, never cut.',
    ),
  ),
  (
    since: 'bi_batch_limit',
    row: (
      key: 'bi.batch_max_requests',
      type: 'int',
      defaultValue: 60,
      min: 10,
      max: 200,
      unit: 'requests',
      group: 'kpi',
      scopes: ['workspace'],
      editPermission: 'manageBilling',
      floor: null,
      editable: true,
      choices: null,
      source: 'bi_query_batch_v1 (0508)',
      note: 'The most figures one report page may ask for in a single read. A page that needs more is split into several reads; the batch is refused whole, never cut.',
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
