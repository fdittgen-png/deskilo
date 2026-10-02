// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1137 — the payment functions convert money ONE way: through
// `_shared/money.ts`, never a literal `* 100` (a yen has no minor digits).
// This narrow architecture guard is the only source check left here.
//
// #1863 C — the other source claims this file used to grep are proven by
// running the real handlers (`deno test` in edge-functions.yml, and
// scripts/edge_payment_check.sh with scripts/payment_scenarios/ in the
// quality workflow). Where each claim lives now:
//   * every Stripe v1 signature is tried → stripe-webhook/index_test.ts
//     "every v1 signature is tried" (red under a last-wins parse);
//   * the currency is the workspace's, the amount whole minor units →
//     edge_payment_check.sh step 3b (USD body on an EUR workspace and a
//     fractional amount: 400, no intent, no provider call); the provider's
//     record equals the intent → payment_scenarios/stripe.sh;
//   * Mollie reports to THIS backend's mollie-webhook → mollie.sh
//     "creation" (webhookUrl read back from the stub);
//   * an approved PayPal order is captured once, with a request id →
//     paypal.sh scenarios 1, 7, 8, 9; PayPal needs `webhook_id` →
//     create-payment-order/index_test.ts "PayPal without its webhook id";
//   * Stripe settles on payment_status, async success/failure →
//     stripe.sh scenarios 2 and 3.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Code lines only: a comment that NAMES the mistake must not trip the
/// rule that forbids it.
String _src(String slug) => File('supabase/functions/$slug/index.ts')
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('*'))
    .join('\n');

void main() {
  test('no webhook multiplies a provider amount by a literal 100', () {
    for (final slug in ['mollie-webhook', 'paypal-webhook']) {
      final s = _src(slug);
      expect(s, isNot(contains('* 100')),
          reason: '$slug: a yen has no minor digits — use _shared/money.ts');
      expect(s, contains('from "../_shared/money.ts"'),
          reason: '$slug must convert through the shared rule');
    }
    expect(_src('create-payment-order'), contains('from "../_shared/money.ts"'));
  });
}
