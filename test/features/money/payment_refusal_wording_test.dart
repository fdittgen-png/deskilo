// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 -- the sheet says each refusal of `apply_payment_to_invoices` in the
// app's own words, matched on the server's English sentence. A sentence
// reworded in a migration would silently become "generic": every
// `raise exception` text of the apply, of the allocation guard and of the
// capacity read must map to a named refusal. Stable codes come with #3657.
import 'dart:io';

import 'package:deskilo/features/money/application/assign_payment_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const _migration = 'supabase/migrations/0718_apply_payment_to_invoices.sql';

/// The body of public.[name] in [sql]: from its create to the next `$fn$;`.
String _body(String sql, String name) {
  final start = sql.indexOf('create or replace function public.$name(');
  expect(start, isNot(-1), reason: '$name is defined in $_migration');
  return sql.substring(start, sql.indexOf(r'$fn$;', start));
}

void main() {
  final sql = File(_migration).readAsStringSync();
  final raised = RegExp(r"raise exception '((?:[^']|'')*)'");

  for (final name in const [
    'apply_payment_to_invoices',
    'guard_payment_allocation_sum',
    'payment_invoice_capacity_v1',
  ]) {
    test('every refusal of $name has its own sentence in the app', () {
      final texts = [
        for (final m in raised.allMatches(_body(sql, name)))
          m.group(1)!.replaceAll("''", "'"),
      ];
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(
          PaymentRefusal.of(StateError(text)),
          isNot(PaymentRefusal.generic),
          reason: '"$text" would be said as a generic failure',
        );
      }
    });
  }

  test('match_invoice\'s new refusal is a payment used meanwhile', () {
    expect(sql, contains("raise exception 'nothing is due on this invoice'"));
    expect(
      PaymentRefusal.of(StateError('nothing is due on this invoice')),
      PaymentRefusal.usedMeanwhile,
    );
  });
}
