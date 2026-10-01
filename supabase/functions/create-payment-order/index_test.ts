// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2014 — configuration fails closed. A failed credential read throws
// (no order on the installation fallback); a deliberately absent row still
// falls back to the environment; Stripe is "configured" only with the
// webhook secret its settlement needs; a provider name must be one of
// ours, not an inherited property such as `constructor`.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { effectiveConfig, isProvider, missingFields } from "./index.ts";

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
