// SPDX-License-Identifier: 0BSD
//
// #926 — two reminders cannot take the same level by racing.
//
// Both writers derived the level as count(*) + 1 with no lock: the
// morning sweep, the sweep that runs when an admin opens Finances, and a
// manual send could all read the same count and write the same level,
// and the member was escalated twice with one letter. The fix is the
// invoice ROW lock before the count — and deliberately NOT a unique
// constraint, because the dunning cap reuses its last level on purpose.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/0162_reminder_level_lock.sql')
      .readAsStringSync();

  test('the manual send locks the invoice row before it counts', () {
    expect(sql, contains("p.proname = 'record_invoice_reminder'"));
    expect(sql, contains(
        'perform 1 from public.invoices where id = p_invoice_id for update;'));
  });

  test('so does the automatic sweep, per invoice', () {
    expect(sql, contains("p.proname = 'sweep_payment_reminders'"));
    expect(sql, contains(
        'perform 1 from public.invoices where id = v_inv.id for update;'));
  });

  test('the lock is PREPENDED to the count in both — the replacement '
      'puts it first, so in the live function it runs first', () {
    // The migration builds `lock || v_anchor`: the lock line is followed
    // by the anchor (the count). After it would be too late.
    expect(
      sql,
      contains("for update;\\n'\n    || v_anchor);"),
      reason: 'manual path: lock, then the count it guards',
    );
    expect(
      "for update;\\n'\n    || v_anchor);".allMatches(sql).length,
      2,
      reason: 'and the sweep, the same way',
    );
  });

  test('a silent no-op is refused: both anchors are asserted', () {
    expect(sql, contains("raise exception '0162: manual anchor missing'"));
    expect(sql, contains("raise exception '0162: sweep anchor missing'"));
  });

  test('no unique (invoice_id, level) constraint — on purpose: the cap '
      'reuses its last level, and a constraint would forbid a designed '
      'outcome', () {
    // The rationale MENTIONS the constraint it rejects; the statement
    // must not exist.
    expect(sql, isNot(contains('add constraint')));
    expect(sql, isNot(contains('create unique index')));
    expect(sql, isNot(contains('alter table public.invoice_reminders')));
    expect(sql, contains('REUSES the last level'),
        reason: 'the reason is written where the next reader will look');
  });

  test('and no history is rewritten: the legacy duplicates stay', () {
    expect(sql, isNot(contains('update public.invoice_reminders')));
    expect(sql, isNot(contains('delete from public.invoice_reminders')));
  });
}
