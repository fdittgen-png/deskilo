// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1608 — the operator's door to database administrators: bootstrap,
// status and recovery, through the Management API's SQL (the service
// owner), never through a client session.
//
//   dart run tool/instance.dart db-admins --token … --ref R list
//   dart run tool/instance.dart db-admins --token … --ref R grant  --email E [--review-only] [--apply]
//   dart run tool/instance.dart db-admins --token … --ref R revoke --email E [--apply]
//
// Without --apply nothing is written: the plan is printed and the exit is
// 0. The target is named by e-mail and must already hold a verified
// identity binding (#1647) on THAT project. The last administrator cannot
// be revoked; the database says so and the exit is 1. Nothing secret is
// printed: no token, no key, no password.
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';

final _email = RegExp(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$");
final _uuid = RegExp(r'^[0-9a-f-]{36}$');

Future<int> runDbAdmins(
  SupabaseManagement api, {
  required String ref,
  required String action,
  String? email,
  bool reviewOnly = false,
  bool apply = false,
  IOSink? out,
}) async {
  final o = out ?? stdout;
  if (action == 'list') {
    final rows = await api.query(ref, '''
select u.email, a.can_provision, a.granted_by, a.granted_at
  from public.database_administrators a join auth.users u on u.id = a.local_user_id
 where a.status = 'active' order by a.granted_at''');
    o.writeln('$ref: ${rows.length} active database administrator(s)');
    for (final r in rows) {
      o.writeln('  ${r['email']}  ${r['can_provision'] == true ? 'reviews and provisions' : 'reviews'}'
          '  (granted by ${r['granted_by']}, ${r['granted_at']})');
    }
    return 0;
  }
  if (action != 'grant' && action != 'revoke') {
    o.writeln('db-admins: list | grant --email E | revoke --email E');
    return 2;
  }
  if (email == null || !_email.hasMatch(email)) {
    o.writeln('db-admins $action needs --email with the target\'s exact address');
    return 2;
  }
  final found = await api.query(ref, '''
select u.id::text as id,
       exists (select 1 from public.identity_bindings b
                where b.local_user_id = u.id and b.status = 'active') as bound
  from auth.users u where lower(u.email) = lower('$email')''');
  if (found.length != 1) {
    o.writeln('refused: no single account $email on $ref');
    return 1;
  }
  final id = '${found.single['id']}';
  if (!_uuid.hasMatch(id)) {
    o.writeln('refused: the account id is not a uuid');
    return 1;
  }
  if (action == 'grant' && found.single['bound'] != true) {
    o.writeln('refused: $email has no verified identity binding on $ref — they '
        'sign in and link their identity first');
    return 1;
  }
  final call = action == 'grant'
      ? 'public.operator_grant_database_admin(\'$id\'::uuid, ${!reviewOnly})'
      : 'public.operator_revoke_database_admin(\'$id\'::uuid)';
  final plan = action == 'grant'
      ? 'grant $email database administration on $ref '
          '(${reviewOnly ? 'reviews only' : 'reviews and provisions'})'
      : 'revoke $email\'s database administration on $ref';
  if (!apply) {
    o.writeln('dry run: would $plan. Nothing was written; add --apply.');
    return 0;
  }
  try {
    final rows = await api.query(ref, 'select $call::text as result');
    o.writeln('$plan: ${rows.single['result']}');
    return 0;
  } on ManagementApiException catch (e) {
    o.writeln('refused by the database: ${e.message}');
    return 1;
  }
}
