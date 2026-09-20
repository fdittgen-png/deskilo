// SPDX-License-Identifier: AGPL-3.0-or-later
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

  // #1556 — Mollie and Wero settle ONLY through `mollie-webhook`; there
  // is no polling behind it and the redirect proves nothing about the
  // money. A payment created without `webhookUrl` is a payment nobody
  // is ever told about, and the word appeared nowhere in the repository.
  test('a Mollie payment says where to report its outcome', () {
    final s = _src('create-payment-order');
    expect(s, contains('webhookUrl:'),
        reason: 'without it the member pays and the account is never '
            'credited — the webhook is the only settlement path');
    expect(s, contains('functions/v1/mollie-webhook'),
        reason: 'and it points at the deployment that asked for it');
    expect(s, contains('Deno.env.get("SUPABASE_URL")'),
        reason: 'derived from this backend, never compiled in: a '
            'self-hoster\'s callbacks must not land on another project');
  });

  // #1555 — approval moves no money. An order with `intent: "CAPTURE"`
  // still has to be captured, and nothing ever called capture, so the
  // flow waited for a PAYMENT.CAPTURE.COMPLETED that could not arrive.
  test('an approved PayPal order is captured, once', () {
    final s = _src('paypal-webhook');
    expect(s, contains('CHECKOUT.ORDER.APPROVED'),
        reason: 'the approval is the signal to capture; ignoring it '
            'leaves the member charged nothing and told everything');
    expect(s, contains('/capture'),
        reason: 'no call to the capture endpoint exists anywhere else');
    expect(s, contains('PayPal-Request-Id'),
        reason: 'PayPal redelivers events: without an idempotency key a '
            'second APPROVED takes the money twice');
    expect(_src('create-payment-order'), contains('"webhook_id"'),
        reason: 'paypal-webhook refuses every event without a webhook_id, '
            'so an instance without one can never be told the money '
            'arrived — "configured" has to mean the whole round trip');
  });

  // #1554 — `completed` is the checkout finishing, not the money
  // arriving: a delayed method ends the session `unpaid` and settles
  // days later, or fails.
  test('Stripe settles on payment, not on the checkout closing', () {
    final s = _src('stripe-webhook');
    expect(s, contains('payment_status'),
        reason: 'crediting a completed session without reading '
            'payment_status posts a ledger entry for money that may '
            'never come');
    expect(s, contains('async_payment_succeeded'),
        reason: 'and the delayed success was being logged and dropped, '
            'so a SEPA payment that DID arrive was never credited');
    expect(s, contains('async_payment_failed'));
  });
}
