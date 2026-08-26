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
      // Born SETTLED: an auto-validated request is never pending for a
      // moment, or the realtime feed and the pending push mirror would
      // ask validators to decide something already decided.
      expect(
        fn,
        contains("case when v_auto then 'confirmed' else 'pending' end"),
        reason: 'the status is chosen at INSERT, not patched afterwards',
      );
      expect(
        fn,
        isNot(contains("set status = 'confirmed'")),
        reason: 'no pending-then-settle: that emits a real validator ping',
      );
      // Same effect as respond_to_event's reservation_delete confirm.
      expect(fn, contains("update public.reservations set status = "
          "'cancelled'"));
      // The 0017 idiom for a decision no human made — attributing it to
      // the requester would forge the peer review 0086 forbids.
      expect(fn, contains("values (v_id, null, 'accept', true)"));
      expect(fn, contains('decided_by_system'));
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

  // #636 — 0119 shipped the two switches ENTANGLED: every owner also
  // carries is_admin (0001 seeds both, 0058 sets both), so the admin arm
  // matched owners too and the admin switch alone auto-settled the
  // owner's own requests. 0121 regenerates the function with the admin
  // arm excluding owners and NOTHING else changed.
  group('server contract (migration 0121, #636)', () {
    final sql =
        File('supabase/migrations/0121_autovalidate_independence.sql')
            .readAsStringSync();

    String body(String name) {
      final start = sql.indexOf('create or replace function public.$name');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final next = sql.indexOf('create or replace function', start + 1);
      return next < 0 ? sql.substring(start) : sql.substring(start, next);
    }

    test('the admin arm excludes owners — the ADMIN switch never '
        'settles an owner request', () {
      final fn = body('request_reservation_deletion');
      expect(
        fn,
        contains('v_member.is_admin and not v_member.is_owner'),
        reason: 'without it the admin switch also auto-settles the owner, '
            'making the owner switch redundant',
      );
      // The entangled 0119 expression must be gone.
      expect(
        fn,
        isNot(contains('v_member.is_admin and '
            'coalesce(v_policy.auto_validate_admin, false)')),
      );
      expect(
        fn,
        contains('coalesce(v_policy.auto_validate_admin, false)'),
        reason: 'the admin arm still keys on its OWN flag',
      );
    });

    test('the owner arm is untouched — an owner is auto-settled by the '
        'OWNER switch and only by it', () {
      final fn = body('request_reservation_deletion');
      expect(
        fn,
        contains('v_member.is_owner and '
            'coalesce(v_policy.auto_validate_owner, false)'),
      );
      expect(fn, isNot(contains('not v_member.is_admin')),
          reason: 'the owner arm asks nothing about the admin bit');
    });

    test('everything else in the body is byte-identical to 0119', () {
      final v3 = File(
        'supabase/migrations/0119_simultaneous_and_autovalidate.sql',
      ).readAsStringSync();
      String slice(String source) {
        final start = source
            .indexOf('create or replace function '
                'public.request_reservation_deletion');
        final next =
            source.indexOf('create or replace function', start + 1);
        return next < 0
            ? source.substring(start)
            : source.substring(start, next);
      }

      // Strip comment lines and the v_auto assignment (the only patch)
      // from both bodies: what remains must match exactly.
      String skeleton(String fn) => fn
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('--'))
          .join('\n')
          .replaceAll(RegExp(r'v_auto :=[\s\S]*?;\n'), '')
          .replaceAll(RegExp(r'\n\s*\n'), '\n');
      expect(skeleton(body('request_reservation_deletion')),
          skeleton(slice(v3)));
    });

    test('the settled shape survives the regeneration', () {
      final fn = body('request_reservation_deletion');
      expect(fn,
          contains("case when v_auto then 'confirmed' else 'pending' end"));
      expect(fn, contains("values (v_id, null, 'accept', true)"));
      expect(fn, contains("jsonb_build_object('auto_validated', true)"));
      expect(fn, contains("and event_type = 'reservation_delete'"));
      expect(fn, isNot(contains('event_type is null')));
    });
  });
}
