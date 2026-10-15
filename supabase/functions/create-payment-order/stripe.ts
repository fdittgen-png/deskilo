// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the Stripe order adapter (Checkout). Stripe takes MINOR units
// directly, so no conversion. The idempotency key is Stripe's own header.

import { ProviderRefusal } from "./outcome.ts";
import type { OrderAdapter } from "./types.ts";

/** Stripe's API root. `STRIPE_API_BASE` exists for the CI check
 * (scripts/edge_payment_check.sh), which answers from a local stub so no
 * request ever leaves the runner. */
const stripeApi = (env: (name: string) => string | undefined) =>
  env("STRIPE_API_BASE") ?? "https://api.stripe.com";

export const createStripeSession: OrderAdapter = async (cfg, order, deps) => {
  const params = new URLSearchParams({
    mode: "payment",
    success_url: cfg.return_url,
    cancel_url: cfg.return_url,
    client_reference_id: order.reference,
    "line_items[0][quantity]": "1",
    "line_items[0][price_data][currency]": order.currency.toLowerCase(),
    "line_items[0][price_data][unit_amount]": String(order.amountCents),
    "line_items[0][price_data][product_data][name]": `DesKilo ${order.reference}`,
  });
  const res = await deps.transport(`${stripeApi(deps.env)}/v1/checkout/sessions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${cfg.secret_key}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": order.key,
    },
    body: params,
  });
  if (!res.ok) {
    throw new ProviderRefusal(res.status);
  }
  const session = await res.json();
  return { orderId: session.id, approveUrl: session.url };
};
