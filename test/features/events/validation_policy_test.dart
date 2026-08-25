// SPDX-License-Identifier: 0BSD
//
// #629 (migration 0119) adds auto_validate_admin / auto_validate_owner:
// a DELIBERATE, owner-configured exception to the 0086 "nobody
// validates their own event" rule, scoped to reservation deletions and
// OFF by default. The round-trip and the server contract are pinned
// below.
import 'dart:io';

import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expensePolicy = ValidationPolicy(
    id: 'vp-1',
    workspaceId: 'ws-1',
    eventType: 'expense',
    requiredCount: 3,
    adminsMayValidate: true,
    eligibleAdminIds: [],
    ownerRequired: true,
  );
  const defaultPolicy = ValidationPolicy(
    id: 'vp-2',
    workspaceId: 'ws-1',
    eventType: null,
    requiredCount: 2,
    adminsMayValidate: false,
    eligibleAdminIds: [],
    ownerRequired: false,
  );

  group('policyFor', () {
    test('the exact event-type row wins', () {
      expect(
        policyFor('expense', [defaultPolicy, expensePolicy]),
        expensePolicy,
      );
    });

    test('falls back to the workspace-default (null type) row', () {
      expect(
        policyFor('reservation', [defaultPolicy, expensePolicy]),
        defaultPolicy,
      );
    });

    test('absent rows yield the pre-quorum defaults', () {
      final policy = policyFor('payment', const []);
      expect(policy.id, isNull);
      expect(policy.requiredCount, 1);
      expect(policy.adminsMayValidate, isTrue);
      expect(policy.eligibleAdminIds, isEmpty);
      expect(policy.ownerRequired, isFalse);
    });

    test('defaults inherit the workspace of the stored rows', () {
      expect(policyFor('payment', [expensePolicy]).workspaceId, 'ws-1');
    });
  });

  test('ValidationPolicy.defaults mirrors the pre-#130 protocol', () {
    final policy = ValidationPolicy.defaults('ws-9', 'service_charge');
    expect(policy.workspaceId, 'ws-9');
    expect(policy.eventType, 'service_charge');
    expect(policy.requiredCount, 1);
    expect(policy.adminsMayValidate, isTrue);
    expect(policy.eligibleAdminIds, isEmpty);
    expect(policy.ownerRequired, isFalse);
    expect(policy.autoValidateAdmin, isFalse);
    expect(policy.autoValidateOwner, isFalse);
  });

  group('auto-validation round-trip (#629)', () {
    test('both booleans default to false — an existing workspace keeps '
        'the 0086 behavior', () {
      expect(expensePolicy.autoValidateAdmin, isFalse);
      expect(expensePolicy.autoValidateOwner, isFalse);
      expect(policyFor('payment', const []).autoValidateOwner, isFalse);
    });

    test('each flag round-trips independently through copyWith', () {
      final owned = expensePolicy.copyWith(autoValidateOwner: true);
      expect(owned.autoValidateOwner, isTrue);
      expect(owned.autoValidateAdmin, isFalse);
      final both = owned.copyWith(autoValidateAdmin: true);
      expect(both.autoValidateOwner, isTrue);
      expect(both.autoValidateAdmin, isTrue);
      // The quorum fields are untouched.
      expect(both.requiredCount, expensePolicy.requiredCount);
      expect(both.ownerRequired, expensePolicy.ownerRequired);
    });

    test('the flags are per-row, never inherited from the default row',
        () {
      const auto = ValidationPolicy(
        id: 'vp-3',
        workspaceId: 'ws-1',
        eventType: null,
        requiredCount: 1,
        adminsMayValidate: true,
        eligibleAdminIds: [],
        ownerRequired: false,
        autoValidateOwner: true,
      );
      // policyFor still resolves the default row for an unlisted type —
      // the SERVER is what refuses to consult it (pinned below).
      expect(policyFor('payment', const [auto]), auto);
    });
  });

  group('server contract (migration 0119)', () {
    final sql =
        File('supabase/migrations/0119_simultaneous_and_autovalidate.sql')
            .readAsStringSync();

    String body(String name) {
      final start = sql.indexOf('create or replace function public.$name');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final next = sql.indexOf('create or replace function', start + 1);
      return next < 0 ? sql.substring(start) : sql.substring(start, next);
    }

    test('both columns are added, NOT NULL and defaulting false', () {
      expect(sql,
          contains('add column auto_validate_admin boolean not null '
              'default false'));
      expect(sql,
          contains('add column auto_validate_owner boolean not null '
              'default false'));
    });

    test('request_reservation_deletion settles on EITHER role, each '
        'keyed on its own flag', () {
      final fn = body('request_reservation_deletion');
      expect(
        fn,
        contains('v_member.is_owner and '
            'coalesce(v_policy.auto_validate_owner, false)'),
      );
      expect(
        fn,
        contains('v_member.is_admin and '
            'coalesce(v_policy.auto_validate_admin, false)'),
      );
      // Mirrors respond_to_event's reservation_delete confirm branch.
      expect(fn, contains("update public.events\n       set status = "
          "'confirmed'"));
      expect(fn, contains("update public.reservations set status = "
          "'cancelled'"));
      expect(fn, contains('insert into public.event_decisions'));
      expect(fn, contains("jsonb_build_object('auto_validated', true)"),
          reason: 'the feed and the audit must tell it apart');
    });

    test('the exception cannot leak: the lookup is pinned to the '
        'reservation_delete row, never the null fallback', () {
      final fn = body('request_reservation_deletion');
      expect(fn, contains("and event_type = 'reservation_delete'"));
      expect(fn, isNot(contains('event_type is null')),
          reason: 'consulting the workspace default row would generalize '
              'the 0086 exception to every event type');
    });

    test('the migration header states the deliberate 0086 exception', () {
      final header = sql.substring(0, sql.indexOf('alter table'));
      expect(header, contains('0086'));
      expect(header, contains('DESIGN NOTE'));
      expect(header.toLowerCase(), contains('never be generalized'));
    });
  });
}
