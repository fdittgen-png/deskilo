// SPDX-License-Identifier: 0BSD
//
// #914/#915 — who may administer a managed profile, and what the person
// sees when they take it over.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/managed_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the rule', () {
    test('empty is the rule nobody narrowed: every owner and every admin '
        '— exactly what #887 shipped', () {
      const rule = ManagedAccess.unnarrowed;
      expect(rule.isDefault, isTrue);
      expect(rule.hasRole(ManagedAccess.roleOwner), isTrue);
      expect(rule.hasRole(ManagedAccess.roleAdmin), isTrue);
      expect(rule.toJson(), isEmpty,
          reason: 'silence is stored as silence, not as a list');
    });

    test('an EMPTY roles list is a statement, not silence: "no role, '
        'only these people"', () {
      final rule = ManagedAccess.fromJson({
        'roles': <String>[],
        'members': ['member-7'],
      });
      expect(rule.isDefault, isFalse);
      expect(rule.hasRole(ManagedAccess.roleAdmin), isFalse);
      expect(rule.hasRole(ManagedAccess.roleOwner), isFalse);
      expect(rule.memberIds, {'member-7'});
    });

    test('narrowing the first time starts from the default, so turning '
        'ONE role off does not silently drop the other', () {
      final rule =
          ManagedAccess.unnarrowed.withRole(ManagedAccess.roleAdmin, false);
      expect(rule.isDefault, isFalse);
      expect(rule.hasRole(ManagedAccess.roleAdmin), isFalse);
      expect(rule.hasRole(ManagedAccess.roleOwner), isTrue,
          reason: 'the owner was in the default and was not touched');
    });

    test('naming a person keeps the roles that applied', () {
      final rule = ManagedAccess.unnarrowed.withMember('member-3', true);
      expect(rule.memberIds, {'member-3'});
      expect(rule.hasRole(ManagedAccess.roleOwner), isTrue);
      expect(rule.hasRole(ManagedAccess.roleAdmin), isTrue);
    });

    test('round-trips through the wire the SQL predicate reads', () {
      final rule = ManagedAccess.fromJson({
        'roles': ['admin'],
        'members': ['m1', 'm2'],
      });
      expect(ManagedAccess.fromJson(rule.toJson()), rule);
      expect(rule.toJson()['roles'], ['admin']);
      expect(rule.toJson()['members'], ['m1', 'm2']);
    });
  });

  group('the SQL twin (migration 0161)', () {
    final sql = File('supabase/migrations/0161_managed_profile_access.sql')
        .readAsStringSync();

    test('the identity LEAVES the widely-readable row: only the name, '
        'company and country stay where every member can see them', () {
      expect(sql, contains('create table if not exists public.managed_identities'));
      expect(sql, contains('create or replace function public.managed_identity_public'));
      for (final public in ['courtesy', 'first_name', 'last_name', 'company',
        'country_code']) {
        expect(sql, contains("'$public'"), reason: '$public is public');
      }
    });

    test('reading it is gated AND written down', () {
      expect(sql, contains('create policy managed_identities_select'));
      expect(sql, contains('public.can_manage_managed_profile(member_id)'));
      expect(sql, contains("values (v_member.workspace_id, v_me.id, p_member_id, 'profile')"));
      expect(sql, contains("raise exception 'not allowed to read this profile'"));
    });

    test('the default rule is owner and admin, and an empty roles list '
        'is honoured as a narrowing', () {
      expect(sql, contains("coalesce(target.managed_access->'roles', 'null'::jsonb) = 'null'::jsonb"));
      expect(sql, contains("target.managed_access->'roles' ? 'owner'"));
      expect(sql, contains("target.managed_access->'roles' ? 'admin'"));
    });

    test('the OWNER may always change a rule, so a profile can never '
        'become unadministrable', () {
      expect(sql, contains('public.is_owner_of(v_member.workspace_id)\n          or public.can_manage_managed_profile(p_member_id)'));
    });

    test('editing, handing over and revoking all obey the rule', () {
      expect("not allowed to manage this profile".allMatches(sql).length,
          greaterThanOrEqualTo(3));
    });

    test('the log learned the word, and nobody may edit history', () {
      expect(sql, contains("check (category in ('finances', 'messages', 'export', 'negotiations', 'profile'))"));
      expect(sql, isNot(contains('create policy data_access_log_update')));
    });
  });
}
