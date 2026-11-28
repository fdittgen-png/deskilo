// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4423 -- the environment an edge function reads, in one place. A function asks `env(KEYS.x)`
// or `requiredEnv(KEYS.x)` and never spells a key twice; `config_test.ts` holds a ceiling on the
// `Deno.env.get(` calls left outside this module, and the ceiling only falls as functions adopt it.

/** The environment keys the functions read: the Supabase client's three and the provider bases. */
export const KEYS = {
  supabaseUrl: "SUPABASE_URL",
  supabaseAnonKey: "SUPABASE_ANON_KEY",
  supabaseServiceRoleKey: "SUPABASE_SERVICE_ROLE_KEY",
  paypalApiBase: "PAYPAL_API_BASE",
  mollieApiBase: "MOLLIE_API_BASE",
  pushSharedSecret: "PUSH_SHARED_SECRET",
  fcmServiceAccount: "FCM_SERVICE_ACCOUNT",
  /** #4454 -- the key the embedded-till function seals the cashiers' tokens with: 32 random bytes, base64. */
  embeddedTillTokenKey: "EMBEDDED_TILL_TOKEN_KEY",
} as const;

/** The value of an environment key, or undefined. */
export function env(key: string): string | undefined {
  return Deno.env.get(key);
}

/** The value of an environment key; a missing one is an error naming the key (never its value). */
export function requiredEnv(key: string): string {
  const value = Deno.env.get(key);
  if (value === undefined || value === "") {
    throw new Error(`missing environment key ${key}`);
  }
  return value;
}
