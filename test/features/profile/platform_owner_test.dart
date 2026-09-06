// SPDX-License-Identifier: 0BSD
//
// #937 — the platform owner's overview: the rows the RPCs return, and
// the SQL twin that refuses everyone else and insists on an e-mail.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/workspace_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/0166_platform_owner.sql').readAsStringSync();

  test('an overview row: enough to recognise a workspace, nothing inside it', () {
    final w = WorkspaceOverview.fromRow({
      'id': 'w', 'name': 'COWORKONTI (prod)', 'environment': 'prod',
      'member_count': 11, 'owner_count': 2, 'is_member': false,
    });
    expect((w.name, w.isDevelopment, w.memberCount, w.ownerCount, w.isMember),
        ('COWORKONTI (prod)', false, 11, 2, false));
    expect(WorkspaceOverview.fromRow({'id': 'x'}).isDevelopment, isTrue,
        reason: 'unknown is development — never mistaken for production');
  });

  test('an owner row carries the e-mail the rule guarantees', () {
    final o = WorkspaceOwner.fromRow({'member_id': 'm', 'name': 'Mathieu', 'email': 'm@x.fr'});
    expect((o.name, o.email), ('Mathieu', 'm@x.fr'));
  });

  group('the SQL twin (migration 0166)', () {
    test('the role is held server-side and the RPCs refuse anyone else', () {
      expect(sql, contains('create table if not exists public.platform_admins'));
      expect("raise exception 'platform owners only'".allMatches(sql).length, 2);
      expect(sql, isNot(contains("email = 'fdittgen@gmail.com' then")),
          reason: 'the e-mail seeds the table once; it is not the check');
    });

    test('reading the owners is logged, and the workspace\'s owners can read the log', () {
      expect(sql, contains("insert into public.platform_access_log (user_id, workspace_id, category)"));
      expect(sql, contains('using (user_id = auth.uid() or public.is_owner_of(workspace_id))'));
    });

    test('an owner must always have an e-mail, at both places ownership is granted', () {
      // Written inside E'' strings in the patch block, so the quotes are
      // doubled there; the phrase itself is what matters.
      expect('an owner must have an e-mail address'.allMatches(sql).length, 2);
      expect(sql, contains("p.proname='create_workspace'"));
      expect(sql, contains("p.proname='activate_co_owner'"));
      expect(sql, contains('revoke execute on function public.user_has_email(uuid) from public, anon, authenticated'));
    });
  });
}
