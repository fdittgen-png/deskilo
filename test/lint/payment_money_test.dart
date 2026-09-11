// SPDX-License-Identifier: 0BSD
//
// #1137 / #1144 — the payment functions convert money ONE way and verify
// a Stripe signature the way Stripe does. Deno is not in the Flutter CI,
// so this reads the sources; `edge-functions.yml` typechecks them.
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

  test('the Stripe verifier keeps every v1 signature', () {
    final s = _src('stripe-webhook');
    expect(s, isNot(contains('Object.fromEntries')),
        reason: 'fromEntries keeps only the LAST v1 — rollover breaks');
    expect(s, contains('filter(([k]) => k === "v1")'));
  });

  test('the order takes the currency from the workspace, not the body', () {
    final s = _src('create-payment-order');
    expect(s, contains('ws?.currency_code'));
    expect(s, isNot(contains('(body.currency as string) ?? "EUR"')));
    expect(s, contains('Number.isInteger(amountCents)'));
  });
}
