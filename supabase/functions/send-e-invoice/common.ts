// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- what the handler and its actions share (#4400): the wire
// helpers, the configuration of a destination and an environment, the
// answer of a send, and the context an action receives.

import { CORS } from "../_shared/cors.ts";
import { requiredFields } from "./connectors.ts";
import type { Phase, TransmissionStore } from "./store.ts";


/** The longest a dispatch may stay in flight before it is treated as
 * uncertain: the Edge Function's own wall-clock budget, a technical
 * transport limit of the platform rather than a business value (#3335 D4). */
export const DISPATCH_WINDOW_SECONDS = 150;

/** The keys a client may declare about itself, and the longest value (#3336).
 * The database clips again (record_provenance); this keeps what leaves the
 * handler small and honest. A value that is not a string is DROPPED, never
 * coerced into one. */
export const DECLARED_KEYS = ["renderer", "renderer_version", "app_version", "format"];
export const DECLARED_WIDTH = 120;

export function clipDeclared(value: unknown): Record<string, string> {
  const out: Record<string, string> = {};
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return out;
  }
  for (const key of DECLARED_KEYS) {
    const v = (value as Record<string, unknown>)[key];
    if (typeof v === "string" && v.length > 0) {
      out[key] = v.slice(0, DECLARED_WIDTH);
    }
  }
  return out;
}

export interface Deps {
  store: TransmissionStore;
  fetchImpl?: typeof fetch;
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

/** Where a document may be sent. 'prod' is the unsuffixed key set that
 * predates environments; 'uat'/'dev' read the suffixed keys (0074). */
export const ENVIRONMENTS = ["prod", "uat", "dev"] as const;
export type Environment = (typeof ENVIRONMENTS)[number];

/** WHO receives the document (#568): the platform the government mandate
 * points at, or the customer's own delivery service. 'government' is the
 * unprefixed key set that predates destinations; 'customer' reads the
 * customer_-prefixed keys. */
export const DESTINATIONS = ["government", "customer"] as const;
export type Destination = (typeof DESTINATIONS)[number];

export type Config = Record<string, string>;

/** The config as one destination sees it. The customer channel is a
 * SEPARATE endpoint and credential — never a fallback to the government
 * ones, because an invoice quietly landing on the wrong platform is the
 * accident this split exists to prevent. */
export function configForDestination(cfg: Config, dest: Destination): Config {
  if (dest === "government") {
    return Object.fromEntries(
      Object.entries(cfg).filter(([key]) => !key.startsWith("customer_")),
    );
  }
  return Object.fromEntries(
    Object.entries(cfg)
      .filter(([key]) => key.startsWith("customer_"))
      .map(([key, value]) => [key.slice("customer_".length), value]),
  );
}

/** The config as one environment sees it. endpoint and auth_value are
 * STRICTLY per-environment — no fallback to prod, because a UAT document
 * silently reaching the production platform is the exact accident this
 * feature exists to prevent. Header and field name fall back to the
 * production values, then to the adapter defaults: they describe the
 * upload shape, not the destination. */
export function configFor(
  cfg: Config,
  env: Environment,
  provider = "generic",
): Config {
  if (env === "prod") return cfg;
  // #2358 — every field a connector REQUIRES is strictly per environment,
  // like the generic endpoint and token: a sandbox key must never fall
  // back to the production one.
  const scoped: Config = { ...cfg };
  for (const field of requiredFields(provider)) {
    scoped[field] = cfg[`${field}_${env}`] ?? "";
  }
  scoped.auth_header = cfg[`auth_header_${env}`] || cfg.auth_header || "";
  scoped.field_name = cfg[`field_name_${env}`] || cfg.field_name || "";
  return scoped;
}

export function missingFor(
  cfg: Config,
  env: Environment,
  provider = "generic",
): string[] {
  const scoped = configFor(cfg, env, provider);
  return requiredFields(provider).filter((field) => !scoped[field]);
}

// #1117 — `Uint8Array<ArrayBuffer>`, not the bare `Uint8Array`.
// TypeScript 5.7 made the type generic over its buffer, and the bare
// form widens to `ArrayBufferLike`, which admits a SharedArrayBuffer
// and is therefore not a `BufferSource`. These bytes always come from
// `Uint8Array.from(atob(...))`, whose buffer is a real ArrayBuffer, so
// naming it is a narrowing, not a cast.
export async function sha256(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** The binding of a transmission as the database keeps it: the document's
 * hash, its format and its receiver. */
export async function bindingOf(
  hash: string,
  format: string,
  receiverScheme: string,
  receiverId: string,
): Promise<string> {
  return await sha256(
    new TextEncoder().encode([hash, format, receiverScheme, receiverId].join("|")),
  );
}

/** What an older client can read: it knows accepted, rejected and failed
 * only, so an unresolved phase reads `failed` with words that say the
 * document was NOT sent again. `phase` carries the truth for new readers. */
export const legacyStatus = (phase: Phase): "accepted" | "rejected" | "failed" =>
  phase === "accepted" || phase === "rejected" ? phase : "failed";

export const UNRESOLVED_DETAIL = "In progress or unresolved - do not resend";

/** The wire answer of a send or a replay (#3335). `status` stays one of the
 * three values an older client decodes; `phase` is the whole truth. */
export function answer(
  phase: Phase,
  id: string,
  externalId: string,
  detail: string,
  environment: string,
  destination: string,
  httpStatus?: number,
): Response {
  const unresolved = phase === "prepared" || phase === "sent" ||
    phase === "uncertain";
  return json({
    status: legacyStatus(phase),
    phase,
    transmission_id: id,
    external_id: externalId,
    detail: unresolved ? UNRESOLVED_DETAIL : detail,
    environment,
    destination,
  }, httpStatus ?? (phase === "accepted" ? 200 : unresolved ? 409 : 502));
}

/** #3883 -- whether every address the connector documents for its sandbox
 * is the one [scoped] (the sandbox credentials) points at, host for host. */
export function onDocumentedSandbox(scoped: Config, sandbox: Config): boolean {
  const host = (url: string): string | null => {
    try {
      const u = new URL(url);
      return u.protocol === "https:" ? u.host : null;
    } catch {
      return null;
    }
  };
  const keys = Object.keys(sandbox);
  return keys.length > 0 &&
    keys.every((k) => {
      const want = host(sandbox[k]);
      return want !== null && host(scoped[k] ?? "") === want;
    });
}

/** What the client may put in a request: every action reads its own fields. */
export interface Payload {
  workspace_id?: string;
  invoice_id?: string;
  declaration_id?: string;
  file_name?: string;
  mime_type?: string;
  content_base64?: string;
  action?: string;
  environment?: string;
  destination?: string;
  format?: string;
  receiver_scheme?: string;
  receiver_id?: string;
  transmission_id?: string;
  outcome?: string;
  reason?: string;
  evidence?: string;
  verdict?: Record<string, unknown>;
  // #3336 -- what the client says about its renderer (clipped on the way in)
  declared?: unknown;
}

/** What an action is given: who asks, in which business, with which
 * credentials, and the request as the handler read it. */
export interface ActionContext {
  store: TransmissionStore;
  fetchImpl: typeof fetch;
  payload: Payload;
  workspaceId: string;
  userId: string;
  mayIssue: boolean;
  mayManage: boolean;
  credentials: Awaited<ReturnType<TransmissionStore["credentials"]>>;
  fullCfg: Config;
  cfg: Config;
  environment: Environment;
  destination: Destination;
  provider: string;
  missing: string[];
}

/** An action reads its context and answers. */
export type Action = (ctx: ActionContext) => Promise<Response>;
