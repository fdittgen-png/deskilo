// SPDX-License-Identifier: 0BSD
//
// #1238 — every table that holds a member's data is either exported or
// exempt on the record.
//
// `export_my_data` returns eight tables. The schema has twenty that
// carry a `member_id` or a `user_id`. Nothing said which of the other
// twelve were a deliberate omission and which were simply forgotten,
// and no test would have noticed a thirteenth arriving.
//
// The subject-access right is not "most of your data", so the list of
// what is left out has to be an argument rather than an accident. Each
// exemption below carries its reason; a new table with a member column
// and no decision fails this test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The LATEST definition of `export_my_data` across every migration —
/// an anchored patch may redefine it, and reading the first definition
/// would test a function the database no longer has.
///
/// Two idioms add a table to the export, and both count here. A later
/// migration may restate the whole function, and it may instead patch
/// it in place (`pg_get_functiondef` + an anchored replace, the house
/// idiom for a function too long to restate — 0247 adds `custom_roles`
/// that way). Reading only the restatements would report a table as
/// missing that the database has returned for months.
String _latestExportBody() {
  final dir = Directory('supabase/migrations');
  final files = dir.listSync().whereType<File>().toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  var body = '';
  final patches = <String>[];
  for (final f in files) {
    if (!f.path.endsWith('.sql')) continue;
    final sql = f.readAsStringSync();
    final at = sql.indexOf(
        'create or replace function public.export_my_data');
    if (at >= 0) {
      final end = sql.indexOf(r'$$;', at);
      body = end < 0 ? sql.substring(at) : sql.substring(at, end);
      patches.clear();
    }
    // An anchored patch: from the read of the current definition to the
    // assertion that the anchor matched is exactly the new text.
    final patch = sql.indexOf("pg_get_functiondef('public.export_my_data");
    if (patch >= 0) {
      final end = sql.indexOf('if v_patched is null', patch);
      patches.add(end < 0 ? sql.substring(patch) : sql.substring(patch, end));
    }
  }
  return body.isEmpty ? '' : '$body\n${patches.join('\n')}';
}

/// Tables with a member or user column that `export_my_data` does not
/// return, and why each is right to leave out.
const Map<String, String> _notExported = {
  'platform_admins':
      'who administers the platform — not the subject\'s data, and '
          'disclosing it would name other people',
  'platform_access_log':
      'the platform owner\'s audit of their own access; the subject\'s '
          'equivalent is data_access_log, which IS exported',
  'push_endpoints':
      'a device token, rotated by the OS and useless outside a live '
          'install; exporting it would hand over a credential',
  'managed_identities':
      'a managed profile belongs to the workspace until it is claimed; '
          'once claimed, the profile itself is exported',
  'conversation_participants':
      'membership of a thread is implied by the messages, which are '
          'exported; the row itself names the OTHER participants',
  'expense_schedules':
      'a workspace cost, which names a member only as whoever entered it',
  'expense_occurrences':
      'as above — an instance of a workspace cost, not personal data',
  'reservation_requests':
      '#1241 — the dedup key an offline replay is matched on. It holds a '
          'member id, a client-generated uuid and a pointer to the '
          'reservation, and the RESERVATION is exported; the row itself '
          'says only that the app asked twice',
};


/// What `export_my_data` returns today.
const Set<String> _exported = {
  'members',
  // #1287 — which roles this member was given, and when. 0247 adds the
  // key by an anchored patch, not a restatement.
  'workspace_role_members',
  // #1238 — the six the export was missing, added by migration 0209.
  'price_negotiations',
  'quota_extensions',
  'usage_records',
  'payment_intents',
  'event_decisions',
  'member_badges',
  'profiles',
  'reservations',
  'ledger_entries',
  'invoices',
  'member_notes',
  'events',
  'data_access_log',
  // #1279 — carnets.
  'member_credits',
};

Set<String> _tablesWithAMemberColumn() {
  final found = <String>{};
  final dir = Directory('supabase/migrations');
  final create = RegExp(
    r'create table (?:if not exists )?public\.(\w+)\s*\((.*?)\n\);',
    caseSensitive: false,
    dotAll: true,
  );
  final column = RegExp(
    r'\b(member_id|user_id|from_member_id|subject_member_id|actor_member_id)\b',
    caseSensitive: false,
  );
  final files = dir.listSync().whereType<File>().toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final f in files) {
    if (!f.path.endsWith('.sql')) continue;
    for (final m in create.allMatches(f.readAsStringSync())) {
      if (column.hasMatch(m.group(2)!)) found.add(m.group(1)!);
    }
  }
  return found;
}

void main() {
  test('every table holding a member\'s data is exported, or exempt with '
      'a reason', () {
    final carrying = _tablesWithAMemberColumn();
    final undecided =
        carrying.difference(_exported).difference(_notExported.keys.toSet());
    expect(
      undecided,
      isEmpty,
      reason: 'these tables carry a member or user column and are neither '
          'in the GDPR export nor on the exempt list. A subject-access '
          'right is not "most of your data": add the table to '
          'export_my_data, or to _notExported with the reason it is not '
          'the subject\'s:\n${undecided.join('\n')}',
    );
  });

  test('the exempt list has not gone stale', () {
    final carrying = _tablesWithAMemberColumn();
    final gone = _notExported.keys.where((t) => !carrying.contains(t));
    expect(gone, isEmpty,
        reason: 'these no longer carry a member column — delete them from '
            '_notExported: ${gone.join(', ')}');
  });

  test('what the export claims to return is what the SQL returns', () {
    final fn = _latestExportBody();
    expect(fn, isNotEmpty, reason: 'no export_my_data found in migrations');
    for (final table in _exported) {
      expect(fn, contains(table),
          reason: '_exported names $table; export_my_data does not read it');
    }
  });
}
