// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4126 -- an attempt still on the provisional id of an uncertain answer is
// ended by the reconciliation only after payment_resend_window(): until then
// the same order request may be sent again under its key (KEY_RETENTION_S in
// create-payment-order/outcome.ts) and would hand the payer a way to pay. The
// two say the same time, or one of them moved without the other.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// KEY_RETENTION_S, in seconds: a number or a product of numbers.
int keyRetentionSeconds(String outcomeTs) {
  final m = RegExp(r'KEY_RETENTION_S\s*=\s*([0-9_\s*]+);')
      .firstMatch(outcomeTs);
  if (m == null) throw StateError('KEY_RETENTION_S not found');
  return m
      .group(1)!
      .split('*')
      .map((f) => int.parse(f.replaceAll('_', '').trim()))
      .reduce((a, b) => a * b);
}

/// The latest payment_resend_window(), in seconds.
int resendWindowSeconds(Iterable<String> migrations) {
  final defining = migrations
      .where((s) => s.contains('function public.payment_resend_window()'))
      .toList();
  if (defining.isEmpty) {
    throw StateError('payment_resend_window() is not defined');
  }
  final body = defining.last.substring(
    defining.last.indexOf('function public.payment_resend_window()'),
  );
  final m = RegExp(r"interval '(\d+) (hours|minutes|seconds)'")
      .firstMatch(body);
  if (m == null) throw StateError('payment_resend_window() names no interval');
  final n = int.parse(m.group(1)!);
  return switch (m.group(2)) {
    'hours' => n * 3600,
    'minutes' => n * 60,
    _ => n,
  };
}

void main() {
  test('the two readings', () {
    expect(
      keyRetentionSeconds('export const KEY_RETENTION_S = 23 * 3600;'),
      82800,
    );
    expect(
      resendWindowSeconds([
        "create or replace function public.payment_resend_window()\n  select interval '23 hours';",
      ]),
      82800,
    );
  });

  test('the reconciliation waits as long as an order request may be resent', () {
    final outcome = File('supabase/functions/create-payment-order/outcome.ts')
        .readAsStringSync();
    final migrations = [
      for (final f in sqlFiles('supabase/migrations'))
        File(f.path).readAsStringSync(),
    ];
    expect(
      resendWindowSeconds(migrations),
      keyRetentionSeconds(outcome),
      reason:
          'payment_resend_window() and KEY_RETENTION_S must say the same time',
    );
  });
}
