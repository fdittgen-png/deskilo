// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4217 — a checkout is sent again under its original request only while its
// provider still keeps that request's key. The window is one platform setting
// per provider, and what the provider guarantees is the ceiling: the default
// and the largest value an operator may set stay below it, so a claim never
// reopens an order the provider no longer remembers. Nothing else carries the
// figure: not the edge function, not a migration's function body.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/settings/seed.dart';
import 'lint_sources.dart';

/// What each provider guarantees for a request's key, in minutes (Mollie one
/// hour, PayPal six hours by default, Stripe at least a day), less a margin.
const _guaranteed = {'mollie': 60, 'paypal': 360, 'stripe': 1440};

void main() {
  test('each provider window is a setting that stays inside what the provider keeps', () {
    for (final entry in _guaranteed.entries) {
      final seed = settingSeeds
          .map((s) => s.row)
          .where((r) => r.key == 'payments.resend_window_${entry.key}_minutes')
          .singleOrNull;
      expect(seed, isNotNull, reason: 'no setting for ${entry.key}');
      expect(seed!.defaultValue as int, lessThan(entry.value));
      expect(seed.max, lessThanOrEqualTo(entry.value * 12),
          reason: 'PayPal may extend its window by arrangement; the bound stays sane');
      expect(seed.editable, isTrue);
    }
  });

  test('no function body or edge function holds a window of its own', () {
    final edge = File('supabase/functions/create-payment-order/outcome.ts').readAsStringSync();
    expect(edge.contains('KEY_RETENTION_S'), isFalse);
    final migrations = sqlFiles('supabase/migrations')
      ..sort((a, b) => a.path.compareTo(b.path));
    final latest = migrations.lastWhere((f) => f.readAsStringSync().contains('payment_intent_claim_open'));
    expect(latest.readAsStringSync().contains("interval '23 hours'"), isFalse);
  });
}
