// SPDX-License-Identifier: 0BSD
//
// #934 — the workspace status as the database returns it, the net the
// screen and the report agree on, and the repartition rule's round trip.
import 'dart:io';

import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The figures workspace_status returned for COWORKONTI dev over
  // 2026-07..09 on 2026-09-06, reconciled by hand against the raw tables.
  const json = {
    'from': '2026-07', 'to': '2026-09', 'currency': 'EUR',
    'revenue': {'invoiced_cents': 60000, 'credit_notes_cents': 188100, 'by_kind': {'full': -20000, 'usage': -108100}, 'repartition_charges_cents': 0},
    'payments': {'matched_cents': 218228, 'received_cents': 323228},
    'expenses': {'reimbursed_cents': 2100, 'repartitioned_cents': 0, 'awaiting_cents': 0, 'credits_granted_cents': 223228},
    'members': [
      {'member_id': 'm1', 'member_number': 'M-0001', 'name': 'Ma Petite Entreprise', 'subscription_pct': 50, 'invoiced_cents': -188100, 'paid_cents': 135000, 'reimbursed_cents': 100, 'credits_cents': 110000, 'charged_cents': 110100},
    ],
  };

  test('reads every figure and computes the net the screen prints', () {
    final s = WorkspaceStatus.fromJson(json);
    expect((s.invoicedCents, s.creditNotesCents, s.paymentsMatchedCents, s.reimbursedCents, s.creditsGrantedCents),
        (60000, 188100, 218228, 2100, 223228));
    expect(s.byKind, {'full': -20000, 'usage': -108100});
    expect(s.netCents, 60000 - 188100 - 2100 - 223228);
    expect(s.members.single.memberNumber, 'M-0001');
    expect(s.members.single.subscriptionPct, 50);
  });

  test('an empty answer is a zero status, not a crash', () {
    final s = WorkspaceStatus.fromJson(const {'from': '2026-01', 'to': '2026-01'});
    expect((s.currency, s.invoicedCents), ('EUR', 0));
    expect(s.members, isEmpty);
  });

  test('the repartition rule round-trips, and nonsense falls back to the '
      'subscription method', () {
    const rule = RepartitionRule(
      method: RepartitionMethod.custom,
      weights: {'m1': 2, 'm2': 1},
      excluded: {'m3'},
    );
    final back = RepartitionRule.fromJson(Map<String, dynamic>.from(rule.toJson()));
    expect(back.method, RepartitionMethod.custom);
    expect(back.weights, {'m1': 2, 'm2': 1});
    expect(back.excluded, {'m3'});
    expect(RepartitionRule.fromJson(const {'method': 'lottery'}).method, RepartitionMethod.subscription);
    expect(RepartitionRule.fromJson(null).method, RepartitionMethod.subscription);
  });

  test('the wizard\'s proposal by subscription share sums to the cost '
      'exactly (50/50/100 → 1/4, 1/4, 1/2)', () {
    final shares = distributeExpense(
      amountCents: 10000,
      method: RepartitionMethod.subscription,
      members: const [
        (id: 'a', name: 'A', subscriptionPct: 50, usageDays: 0, customWeight: 0),
        (id: 'b', name: 'B', subscriptionPct: 50, usageDays: 0, customWeight: 0),
        (id: 'c', name: 'C', subscriptionPct: 100, usageDays: 0, customWeight: 0),
      ],
    );
    expect(shares.map((s) => s.amountCents), [2500, 2500, 5000]);
    expect(shares.fold<int>(0, (t, s) => t + s.amountCents), 10000);
  });

  test('the SQL twin (0167) refuses non-admins and keeps settlements '
      'transparent', () {
    final sql = File('supabase/migrations/0167_workspace_status.sql').readAsStringSync();
    expect("raise exception 'admins only'".allMatches(sql).length, 2);
    expect(sql, contains("i.kind <> 'settlement'"));
    expect(sql, contains("jsonb_build_object('repartition', p_rule)"));
    expect(sql, contains("where m.workspace_id = p_workspace_id and m.status = 'active' and not m.is_kiosk"));
  });
}
