// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — which adapter opens an order for which provider. A plain lookup:
// no base class, because the providers share no behaviour beyond the shape
// of the call.

import { createMolliePayment, createWeroPayment } from "./mollie.ts";
import { createPaypalOrder } from "./paypal.ts";
import { createStripeSession } from "./stripe.ts";
import type { OrderAdapter, Provider } from "./types.ts";

export const ORDER_ADAPTERS: Record<Provider, OrderAdapter> = {
  paypal: createPaypalOrder,
  stripe: createStripeSession,
  mollie: createMolliePayment,
  wero: createWeroPayment,
};
