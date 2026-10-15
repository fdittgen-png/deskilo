// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the configuration resolver. Credentials are PER WORKSPACE (the
// deny-all `payment_credentials` table, read through the privileged client
// the handler passes in); deployment-wide env vars are the fallback.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { Provider, ProviderConfig } from "./types.ts";

/** Config field → env-var fallback, per provider. */
const FIELD_ENV: Record<Provider, Record<string, string>> = {
  paypal: {
    client_id: "PAYPAL_CLIENT_ID",
    secret: "PAYPAL_SECRET",
    env: "PAYPAL_ENV",
    webhook_id: "PAYPAL_WEBHOOK_ID",
    return_url: "PAYMENT_RETURN_URL",
  },
  stripe: {
    secret_key: "STRIPE_SECRET_KEY",
    webhook_secret: "STRIPE_WEBHOOK_SECRET",
    return_url: "PAYMENT_RETURN_URL",
  },
  mollie: {
    api_key: "MOLLIE_API_KEY",
    return_url: "PAYMENT_RETURN_URL",
  },
  // Wero rides Mollie (same API key), a distinct provider for the chooser.
  wero: {
    api_key: "MOLLIE_API_KEY",
    return_url: "PAYMENT_RETURN_URL",
  },
};

/** Fields a provider must have before it can be offered. */
export const REQUIRED: Record<Provider, string[]> = {
  // #1555 — `webhook_id` belongs here: `paypal-webhook` refuses every
  // event without it, so an instance configured without one advertises
  // PayPal, takes the member to PayPal, and can never be told the money
  // arrived. "Configured" has to mean the whole round trip.
  paypal: ["client_id", "secret", "return_url", "webhook_id"],
  // #2014 — and `webhook_secret`, for the same reason: without it the
  // webhook cannot verify the payment, so the member pays and is never
  // credited.
  stripe: ["secret_key", "return_url", "webhook_secret"],
  mollie: ["api_key", "return_url"],
  wero: ["api_key", "return_url"],
};

/** #2014 — a provider name this handler supports, not an inherited
 * property (`"constructor" in REQUIRED` is true). */
export const isProvider = (value: unknown): value is Provider =>
  typeof value === "string" && Object.hasOwn(REQUIRED, value);

/** The effective config of a provider for a workspace: table row (owner UI)
 * overlaid on env-var fallbacks, per field.
 *
 * #2014 — a failed credential READ is not an absent credential: it
 * throws, so no order is opened on the installation's fallback. A row
 * that is deliberately absent still falls back to the environment. */
export async function effectiveConfig(
  admin: SupabaseClient,
  workspaceId: string,
  provider: Provider,
  env: (name: string) => string | undefined = (n) => Deno.env.get(n),
): Promise<ProviderConfig> {
  const { data, error } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", provider)
    .maybeSingle();
  if (error) throw new Error("payment credential lookup failed");
  const stored = (data?.config ?? {}) as ProviderConfig;
  const out: ProviderConfig = {};
  for (const [field, envVar] of Object.entries(FIELD_ENV[provider])) {
    const value = stored[field] ?? env(envVar) ?? "";
    if (value) out[field] = value;
  }
  return out;
}

export const missingFields = (config: ProviderConfig, provider: Provider) =>
  REQUIRED[provider].filter((f) => !config[f]);
