// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2014 — configuration fails closed. A failed credential read throws
// (no order on the installation fallback); a deliberately absent row still
// falls back to the environment; Stripe is "configured" only with the
// webhook secret its settlement needs; a provider name must be one of
// ours, not an inherited property such as `constructor`.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  effectiveConfig,
  failureOutcome,
  idempotencyKey,
  isProvider,
  missingFields,
  ProviderRefusal,
} from "./index.ts";

// deno-lint-ignore no-explicit-any
function admin(result: { data: unknown; error: unknown }): any {
  const chain = {
    select: () => chain,
    eq: () => chain,
    maybeSingle: () => Promise.resolve(result),
  };
  return { from: () => chain };
}

const env = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("a failed credential read throws, even with env credentials", async () => {
  await assertRejects(() =>
    effectiveConfig(
      admin({ data: null, error: { message: "down" } }),
      "ws-1",
      "stripe",
      env({ STRIPE_SECRET_KEY: "sk", STRIPE_WEBHOOK_SECRET: "wh", PAYMENT_RETURN_URL: "r" }),
    )
  );
});

Deno.test("a deliberately absent row falls back to the environment", async () => {
  const cfg = await effectiveConfig(
    admin({ data: null, error: null }),
    "ws-1",
    "stripe",
    env({ STRIPE_SECRET_KEY: "sk", STRIPE_WEBHOOK_SECRET: "wh", PAYMENT_RETURN_URL: "r" }),
  );
  assertEquals(missingFields(cfg, "stripe"), []);
});

Deno.test("Stripe without its webhook secret is not configured", async () => {
  const cfg = await effectiveConfig(
    admin({ data: { config: { secret_key: "sk", return_url: "r" } }, error: null }),
    "ws-1",
    "stripe",
    env({}),
  );
  assertEquals(missingFields(cfg, "stripe"), ["webhook_secret"]);
});

Deno.test("only our own provider names are providers", () => {
  assertEquals(isProvider("stripe"), true);
  assertEquals(isProvider("constructor"), false);
  assertEquals(isProvider("toString"), false);
  assertEquals(isProvider(42), false);
});

Deno.test("#2014 B — only a provider 4xx fails the intent; the rest is unknown", () => {
  assertEquals(failureOutcome(new ProviderRefusal(402)), "failed");
  assertEquals(failureOutcome(new ProviderRefusal(400)), "failed");
  assertEquals(failureOutcome(new ProviderRefusal(503)), "unknown");
  assertEquals(failureOutcome(new TypeError("network")), "unknown");
  assertEquals(failureOutcome(new DOMException("timeout", "TimeoutError")), "unknown");
});

Deno.test("#2014 B — one stable idempotency key per intent", () => {
  assertEquals(idempotencyKey("i-1"), idempotencyKey("i-1"));
  assertEquals(idempotencyKey("i-1") === idempotencyKey("i-2"), false);
});

// #1863 C — replaces the source grep for `"webhook_id"`: paypal-webhook
// refuses every event without one, so PayPal is not configured without it.
Deno.test("PayPal without its webhook id is not configured", async () => {
  const cfg = await effectiveConfig(
    admin({ data: { config: { client_id: "c", secret: "s", return_url: "r" } }, error: null }),
    "ws-1",
    "paypal",
    env({}),
  );
  assertEquals(missingFields(cfg, "paypal"), ["webhook_id"]);
});
