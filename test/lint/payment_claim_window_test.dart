// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 — an online payment's claim holds its invoices as long as the payment
// flow may still send the intent to its provider: the window the edge
// function keeps an idempotency key for (KEY_RETENTION_S), and nothing
// longer, or a payment never sent would hold its invoices for ever. The
// database cannot read the edge function's constant, so the two are one
// number written twice, and this test keeps them equal.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The seconds of `select interval 'N hours'` in the newest migration that
/// defines public.payment_claim_window().
int _sqlWindowSeconds() {
  final definition = RegExp(
    r"function public\.payment_claim_window\(\)[\s\S]*?interval '(\d+) hours'",
  );
  final files = sqlFiles('supabase/migrations')
    ..sort((a, b) => a.path.compareTo(b.path));
  int? hours;
  for (final file in files) {
    final match = definition.firstMatch(file.readAsStringSync());
    if (match != null) hours = int.parse(match.group(1)!);
  }
  expect(hours, isNotNull, reason: 'no migration defines payment_claim_window');
  return hours! * 3600;
}

/// KEY_RETENTION_S of the payment flow, as `N * 3600` or a plain number.
int _edgeWindowSeconds() {
  final source = File(
    'supabase/functions/create-payment-order/outcome.ts',
  ).readAsStringSync();
  final match = RegExp(
    r'KEY_RETENTION_S\s*=\s*(\d+)(?:\s*\*\s*(\d+))?\s*;',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'KEY_RETENTION_S moved: follow it here');
  return int.parse(match!.group(1)!) * int.parse(match.group(2) ?? '1');
}

void main() {
  test('a claim holds its invoices exactly as long as the payment flow may '
      'still send its intent', () {
    expect(_sqlWindowSeconds(), _edgeWindowSeconds());
  });
}
