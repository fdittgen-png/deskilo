// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1608 — the operator's db-admins command. A dry run writes nothing, a
// grant needs an exact target that already holds a verified identity
// binding, --apply calls the operator function once per run, the
// database's refusal (the last administrator) is exit 1, and no token or
// key reaches the output.
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/db_admins.dart';
import '../helpers/fake_supabase_management.dart';

class _Out implements IOSink {
  final text = StringBuffer();
  @override
  void writeln([Object? obj = '']) => text.writeln(obj);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const id = '00000000-0000-4000-8000-0000000160a1';

FakeSupabaseManagement fake({bool bound = true, int accounts = 1, String? refuse}) {
  final api = FakeSupabaseManagement();
  api.onQuery = (ref, sql) {
    if (sql.contains('from auth.users u where lower(u.email)')) {
      return [for (var i = 0; i < accounts; i++) {'id': id, 'bound': bound}];
    }
    if (sql.contains('operator_')) {
      if (refuse != null) throw ManagementApiException(400, refuse);
      return [
        {'result': '{"status": "granted"}'},
      ];
    }
    if (sql.contains('from public.database_administrators a')) {
      return [
        {'email': 'adm-a@deskilo.test', 'can_provision': true, 'granted_by': 'operator', 'granted_at': '2026-09-26'},
      ];
    }
    return const [];
  };
  return api;
}

int writes(FakeSupabaseManagement api) =>
    api.queriedSql.where((s) => s.contains('operator_')).length;

void main() {
  test('a dry run names the plan and writes nothing', () async {
    final api = fake();
    final out = _Out();
    final code = await runDbAdmins(api, ref: 'abc', action: 'grant', email: 'adm-a@deskilo.test', out: out);
    expect(code, 0);
    expect(writes(api), 0);
    expect(out.text.toString(), contains('dry run: would grant adm-a@deskilo.test'));
  });

  test('--apply grants once, reviews-only when asked', () async {
    final api = fake();
    final out = _Out();
    expect(await runDbAdmins(api, ref: 'abc', action: 'grant', email: 'adm-a@deskilo.test',
        reviewOnly: true, apply: true, out: out), 0);
    expect(writes(api), 1);
    expect(api.queriedSql.last, contains("operator_grant_database_admin('$id'::uuid, false)"));
  });

  test('an unknown, ambiguous or unbound target is refused before any write', () async {
    for (final api in [fake(accounts: 0), fake(accounts: 2), fake(bound: false)]) {
      final out = _Out();
      expect(await runDbAdmins(api, ref: 'abc', action: 'grant', email: 'x@deskilo.test',
          apply: true, out: out), 1);
      expect(writes(api), 0);
    }
    final bad = _Out();
    expect(await runDbAdmins(fake(), ref: 'abc', action: 'grant', email: "x'; drop table x;--", out: bad), 2);
  });

  test('the last administrator: the database refuses, the exit says so', () async {
    final api = fake(refuse: 'the last database administrator cannot be removed; add a successor first');
    final out = _Out();
    expect(await runDbAdmins(api, ref: 'abc', action: 'revoke', email: 'adm-a@deskilo.test',
        apply: true, out: out), 1);
    expect(out.text.toString(), contains('last database administrator'));
  });

  test('list shows the roster to the operator, and nothing secret', () async {
    final out = _Out();
    expect(await runDbAdmins(fake(), ref: 'abc', action: 'list', out: out), 0);
    expect(out.text.toString(), contains('adm-a@deskilo.test  reviews and provisions'));
    expect(out.text.toString(), isNot(contains('sbp_')));
    expect(out.text.toString(), isNot(contains('sb_publishable')));
  });
}
