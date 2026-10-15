// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the Mollie order adapter (Payments), and Wero, which rides it
// with `method: "wero"`. Mollie wants a major-unit decimal string.

import { toMajor } from "../_shared/money.ts";
import { mollieApi } from "../_shared/providers.ts";
import { ProviderRefusal } from "./outcome.ts";
import type { AdapterDeps, OrderAdapter, OrderInput, ProviderConfig } from "./types.ts";

async function createMolliePaymentWith(
  cfg: ProviderConfig,
  order: OrderInput,
  deps: AdapterDeps,
  method?: string,
) {
  const res = await deps.transport(`${mollieApi()}/v2/payments`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${cfg.api_key}`,
      "Content-Type": "application/json",
      "Idempotency-Key": order.key,
    },
    body: JSON.stringify({
      amount: { currency: order.currency, value: toMajor(order.amountCents, order.currency) },
      description: `DesKilo ${order.reference}`,
      redirectUrl: cfg.return_url,
      // #1556 — where Mollie reports the outcome. Without it the
      // payment is created, the member pays, and nothing ever tells us:
      // `mollie-webhook` is the ONLY settlement path for Mollie and for
      // Wero, and there is no polling behind it. The redirect proves the
      // browser came back, never that the money moved.
      //
      // Derived from this deployment's own backend, never compiled in,
      // so a self-hosted instance's callbacks land on its own project
      // and not on somebody else's. `webhook_url` overrides it for an
      // instance behind a custom domain — Mollie refuses a URL it
      // cannot reach, localhost included, which is why the override
      // exists at all.
      webhookUrl: cfg.webhook_url ??
        `${deps.env("SUPABASE_URL")}/functions/v1/mollie-webhook`,
      metadata: { reference: order.reference },
      ...(method ? { method } : {}),
    }),
  });
  if (!res.ok) {
    throw new ProviderRefusal(res.status);
  }
  const payment = await res.json();
  return { orderId: payment.id as string, approveUrl: payment._links.checkout.href as string };
}

export const createMolliePayment: OrderAdapter = (cfg, order, deps) =>
  createMolliePaymentWith(cfg, order, deps);

export const createWeroPayment: OrderAdapter = (cfg, order, deps) =>
  createMolliePaymentWith(cfg, order, deps, "wero");
