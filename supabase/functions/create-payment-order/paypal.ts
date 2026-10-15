// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the PayPal order adapter (Orders v2). PayPal wants a major-unit
// decimal string, so the amount goes through the shared money rule (#1137).

import { toMajor } from "../_shared/money.ts";
import { paypalApi } from "../_shared/providers.ts";
import { ProviderRefusal } from "./outcome.ts";
import type { OrderAdapter } from "./types.ts";

export const createPaypalOrder: OrderAdapter = async (cfg, order, deps) => {
  const auth = btoa(`${cfg.client_id}:${cfg.secret}`);
  const tokenRes = await deps.transport(`${paypalApi(cfg.env)}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!tokenRes.ok) {
    throw new ProviderRefusal(tokenRes.status);
  }
  const { access_token } = await tokenRes.json();
  const orderRes = await deps.transport(`${paypalApi(cfg.env)}/v2/checkout/orders`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${access_token}`,
      "Content-Type": "application/json",
      "PayPal-Request-Id": order.key,
    },
    body: JSON.stringify({
      intent: "CAPTURE",
      purchase_units: [{
        amount: {
          currency_code: order.currency,
          value: toMajor(order.amountCents, order.currency),
        },
        custom_id: order.reference,
      }],
      application_context: {
        return_url: cfg.return_url,
        cancel_url: cfg.return_url,
        user_action: "PAY_NOW",
      },
    }),
  });
  if (!orderRes.ok) {
    throw new ProviderRefusal(orderRes.status);
  }
  const created = await orderRes.json();
  const approve = (created.links ?? []).find(
    (l: { rel: string }) => l.rel === "approve",
  );
  if (!approve) throw new Error("paypal order has no approve link");
  return { orderId: created.id, approveUrl: approve.href };
};
