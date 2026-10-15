// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the vocabulary the order handler is composed from. A provider
// adapter takes a verified request's money facts, the provider's resolved
// configuration and an injected transport, and answers a typed result or
// throws; it never sees the caller's session, a workspace table or a
// database client.

export type Provider = "paypal" | "stripe" | "mollie" | "wero";

/** The effective configuration of one provider for one workspace. */
export type ProviderConfig = Record<string, string>;

/** What an adapter needs to open ONE provider order. */
export interface OrderInput {
  /** Minor units, as the app stores them. */
  amountCents: number;
  /** The WORKSPACE's ISO 4217 currency (#1138), upper case. */
  currency: string;
  /** The readable per-workspace reference (#928). */
  reference: string;
  /** The provider idempotency key: one per intent, the same on a retry. */
  key: string;
}

export interface OrderResult {
  orderId: string;
  approveUrl: string;
}

/** The HTTP transport an adapter sends through. */
export type Transport = (url: string, init: RequestInit) => Promise<Response>;

/** What an adapter is injected with: the transport and the environment. */
export interface AdapterDeps {
  transport: Transport;
  env: (name: string) => string | undefined;
}

export type OrderAdapter = (
  cfg: ProviderConfig,
  order: OrderInput,
  deps: AdapterDeps,
) => Promise<OrderResult>;

/** The deployment's own transport and environment. */
export const runtimeDeps = (): AdapterDeps => ({
  transport: (url, init) => fetch(url, init),
  env: (name) => Deno.env.get(name),
});
