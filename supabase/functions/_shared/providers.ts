// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1638/#1639 — the provider API origins, in ONE place for the order
// handler and the webhooks. `*_API_BASE` exists for the CI checks
// (scripts/edge_payment_check.sh), which answer from local stubs so no
// request leaves the runner; a deployment never sets it.

/** PayPal: the sandbox unless the workspace's config says `live`. */
export const paypalApi = (env?: string): string =>
  Deno.env.get("PAYPAL_API_BASE") ??
    (env === "live"
      ? "https://api-m.paypal.com"
      : "https://api-m.sandbox.paypal.com");

/** Mollie: one origin; test or live is decided by the key's prefix. */
export const mollieApi = (): string =>
  Deno.env.get("MOLLIE_API_BASE") ?? "https://api.mollie.com";

/** Whether a Mollie key belongs to test mode (`test_…`) or live. */
export const mollieKeyMode = (key: string): "test" | "live" | null =>
  key.startsWith("test_") ? "test" : key.startsWith("live_") ? "live" : null;
