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

  // match_invoice runs inside the apply: what the apply can reach is said in
  // its own words; what it cannot reach is named here with the reason.
  const unreachable = {
    'unknown invoice':
        'the apply refuses an unknown invoice first, as another payer\'s',
    'unknown resolution': 'the apply sends exact or under_accepted only',
    'amount does not match the invoice':
        'the apply sends exact only when the part is what is due',
    'amount does not exceed the invoice':
        'the apply never sends an overpayment',
    'amount is not below the invoice':
        'the apply sends under_accepted only below what is due',
  };
  test('every refusal of match_invoice the apply can reach has its own '
      'sentence; the others are named with why they cannot be reached', () {
    final texts = {
      for (final m in raised.allMatches(_body(sql, 'match_invoice')))
        m.group(1)!.replaceAll("''", "'"),
    };
    expect(texts, containsAll(unreachable.keys), reason: 'the list is current');
    for (final text in texts.difference(unreachable.keys.toSet())) {
      expect(
        PaymentRefusal.of(StateError(text)),
        isNot(PaymentRefusal.generic),
        reason: '"$text" would be said as a generic failure',
      );
    }
  });

  test('an invoice paid or changed meanwhile is said as such, not as a '
      'payment used meanwhile', () {
    for (final text in const [
      'invoice already matched',
      'nothing is due on this invoice',
      'invoice is voided',
      'invoice is settled',
    ]) {
      expect(
        PaymentRefusal.of(StateError(text)),
        PaymentRefusal.invoiceChanged,
        reason: text,
      );
    }
    expect(
      PaymentRefusal.of(
        StateError('credit already deducted on an issued invoice'),
      ),
      PaymentRefusal.creditDeducted,
    );
  });
}
