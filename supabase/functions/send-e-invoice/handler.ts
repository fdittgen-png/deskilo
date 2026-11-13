// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice — the handler (#3335). It lives apart from index.ts so
// its decisions can be exercised with an injected store and provider:
//
//   authenticate → authorise → (config | status | resolve | send)
//
// A send is PREPARED durably before any byte leaves (prepare_einvoice_v1:
// one record per business transmission, bytes and recipient pinned), its
// artifact is read back and verified, and the dispatch is CLAIMED
// atomically with an owner and a generation. The provider is called only
// by the claim's winner; its outcome is recorded against that owner and
// generation, so a late writer changes nothing. A dispatch that may have
// landed and whose answer is lost is `uncertain` and is never resent
// automatically: a lookup (where the channel has one) or a person with
// the send authority settles it.

import { refuseDelegated } from "../_shared/delegated.ts";
import { CORS, preflight } from "../_shared/cors.ts";
import {
  isProvider,
  requiredFields,
  status as askStatus,
  type Submission,
  submit,
} from "./connectors.ts";
import { clientDetail, safeFetch } from "./connectors/safe_fetch.ts";
import type { Phase, TransmissionStore } from "./store.ts";

/** The longest a dispatch may stay in flight before it is treated as
 * uncertain: the Edge Function's own wall-clock budget, a technical
 * transport limit of the platform rather than a business value (#3335 D4). */
export const DISPATCH_WINDOW_SECONDS = 150;

/** The keys a client may declare about itself, and the longest value (#3336).
 * The database clips again (record_provenance); this keeps what leaves the
 * handler small and honest. A value that is not a string is DROPPED, never
 * coerced into one. */
const DECLARED_KEYS = ["renderer", "renderer_version", "app_version", "format"];
const DECLARED_WIDTH = 120;

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

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

/** Where a document may be sent. 'prod' is the unsuffixed key set that
 * predates environments; 'uat'/'dev' read the suffixed keys (0074). */
const ENVIRONMENTS = ["prod", "uat", "dev"] as const;
type Environment = (typeof ENVIRONMENTS)[number];

/** WHO receives the document (#568): the platform the government mandate
 * points at, or the customer's own delivery service. 'government' is the
 * unprefixed key set that predates destinations; 'customer' reads the
 * customer_-prefixed keys. */
const DESTINATIONS = ["government", "customer"] as const;
type Destination = (typeof DESTINATIONS)[number];

type Config = Record<string, string>;

/** The config as one destination sees it. The customer channel is a
 * SEPARATE endpoint and credential — never a fallback to the government
 * ones, because an invoice quietly landing on the wrong platform is the
 * accident this split exists to prevent. */
function configForDestination(cfg: Config, dest: Destination): Config {
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
function configFor(
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

function missingFor(
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
async function sha256(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** What an older client can read: it knows accepted, rejected and failed
 * only, so an unresolved phase reads `failed` with words that say the
 * document was NOT sent again. `phase` carries the truth for new readers. */
const legacyStatus = (phase: Phase): "accepted" | "rejected" | "failed" =>
  phase === "accepted" || phase === "rejected" ? phase : "failed";

const UNRESOLVED_DETAIL = "In progress or unresolved - do not resend";

/** The wire answer of a send or a replay (#3335). `status` stays one of the
 * three values an older client decodes; `phase` is the whole truth. */
function answer(
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

export async function handle(req: Request, deps: Deps): Promise<Response> {
  const { store } = deps;
  const fetchImpl = deps.fetchImpl ?? safeFetch();
  // #1553 — the preflight is answered before anything else.
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  // #1614 — a delegated (MCP) token never transmits an invoice.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;

  const authorization = req.headers.get("Authorization") ?? "";
  let payload: {
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
    // #3336 — what the client says about its renderer (clipped below)
    declared?: unknown;
  };
  try {
    payload = await req.json();
  } catch (error) {
    console.warn("send-e-invoice: invalid body", error);
    return json({ error: "invalid body" }, 400);
  }
  const workspaceId = payload.workspace_id ?? "";
  if (!workspaceId) return json({ error: "workspace_id required" }, 400);
  // #2357 — a VAT return is not an upload.
  if (payload.declaration_id) {
    return json({
      error: "vat_return_not_transmitted",
      detail: "A VAT return is filed by its owner with the tax authority; " +
        "this channel carries invoices only.",
    }, 410);
  }

  // #1078 — WHO is asking, BEFORE anything answers; scoped by user_id.
  const userId = await store.user(authorization.replace("Bearer ", ""));
  if (!userId) return json({ error: "unauthorized" }, 401);
  const me = await store.member(workspaceId, userId);
  // An active owner, or an active member who holds issueInvoices (the
  // permission matrix: from the base role or a role of the space).
  const mayIssue = !!me && me.status === "active" &&
    (me.is_owner || await store.hasPermission(me.id, "issueInvoices"));
  if (!me || !mayIssue) {
    return json({ error: "not allowed to issue invoices in this workspace" }, 403);
  }

  const credentials = await store.credentials(workspaceId);
  const fullCfg = (credentials?.config ?? {}) as Config;
  const environment = (ENVIRONMENTS as readonly string[]).includes(
      payload.environment ?? "",
    )
    ? (payload.environment as Environment)
    : "prod";
  const destination = (DESTINATIONS as readonly string[]).includes(
      payload.destination ?? "",
    )
    ? (payload.destination as Destination)
    : "government";
  const cfg = configForDestination(fullCfg, destination);
  // The customer leg is always the generic upload (#568).
  const provider = destination === "customer"
    ? "generic"
    : (credentials?.provider ?? "generic");
  const missing = missingFor(cfg, environment, provider);

  // The client asks first whether sending is even possible.
  if (payload.action === "config") {
    const govCfg = configForDestination(fullCfg, "government");
    const govProvider = credentials?.provider ?? "generic";
    // a provider whose connector was retired cannot send: say so (#3338)
    const installed = isProvider(govProvider);
    return json({
      configured: installed &&
        missingFor(govCfg, "prod", govProvider).length === 0,
      ...(installed ? {} : { error: "provider_not_installed" }),
      provider: govProvider,
      missing: missingFor(govCfg, "prod", govProvider),
      environments: Object.fromEntries(
        ENVIRONMENTS.map((
          env,
        ) => [env, missingFor(govCfg, env, govProvider).length === 0]),
      ),
      destinations: Object.fromEntries(
        DESTINATIONS.map((dest) => {
          const scoped = configForDestination(fullCfg, dest);
          return [dest, {
            configured: missingFor(scoped, "prod").length === 0,
            missing: missingFor(scoped, "prod"),
            environments: Object.fromEntries(
              ENVIRONMENTS.map(
                (env) => [env, missingFor(scoped, env).length === 0],
              ),
            ),
          }];
        }),
      ),
      // a client that sees this understands the unresolved phases (#3335)
      phases: true,
    });
  }

  // #917 — a DEVELOPMENT workspace does not talk to the outside world.
  if ((await store.workspaceEnvironment(workspaceId)) !== "prod") {
    return json({
      error: "development_workspace",
      detail:
        "This workspace is a development one: it does not send documents " +
        "to a government platform or to a customer. Declare it production " +
        "to send for real.",
    }, 409);
  }

  // A dispatch whose deadline passed with no outcome is uncertain now.
  try {
    await store.expire(workspaceId);
  } catch (error) {
    console.error("send-e-invoice: expiry sweep failed", error);
  }

  // ── what became of an earlier submission ────────────────────────────
  if (payload.action === "status") {
    const sent = await store.transmission(payload.transmission_id ?? "");
    if (!sent || sent.workspace_id !== workspaceId) {
      return json({ error: "unknown transmission" }, 404);
    }
    // Only a recorded upload can be asked about, and never by a resend.
    if (
      !sent.external_id ||
      (sent.phase !== "accepted" && sent.phase !== "uncertain")
    ) {
      return json({
        phase: sent.phase,
        status: legacyStatus(sent.phase),
        lookup: "unavailable",
        detail: sent.phase === "uncertain" ? UNRESOLVED_DETAIL : sent.detail,
      });
    }
    // The stored destination and environment decide the credentials, not
    // the request's defaults (O11).
    const sentCfg = configForDestination(
      fullCfg,
      sent.destination as Destination,
    );
    const asked = await askStatus(
      sent.provider,
      configFor(sentCfg, sent.environment as Environment, sent.provider),
      sent.external_id,
      fetchImpl,
    );
    // A document verdict is something the connector READ from a successful
    // answer; a refused or failed query is a query error, never a verdict.
    const isVerdict = asked.httpStatus === undefined &&
      (asked.status === "accepted" || asked.status === "rejected") &&
      Object.keys(asked.receipt).length > 0;
    if (isVerdict) {
      await store.lookup(
        sent.id,
        sent.phase === "uncertain" ? "accepted" : null,
        sent.external_id,
        asked.receipt,
        {
          status: asked.status,
          detail: clientDetail(asked.status, asked.detail),
        },
        "",
      );
    } else {
      console.error("send-e-invoice: status query failed", asked.detail);
      await store.lookup(
        sent.id,
        null,
        "",
        null,
        null,
        clientDetail(asked.status, asked.detail),
      );
    }
    const current = await store.transmission(sent.id);
    return json({
      phase: current?.phase ?? sent.phase,
      status: legacyStatus(current?.phase ?? sent.phase),
      document_status: isVerdict ? asked.status : "unknown",
      detail: isVerdict ? clientDetail(asked.status, asked.detail) : "",
      receipt: current?.receipt ?? sent.receipt,
    });
  }

  // ── a person settles an uncertain submission ────────────────────────
  if (payload.action === "resolve") {
    const target = await store.transmission(payload.transmission_id ?? "");
    if (!target || target.workspace_id !== workspaceId) {
      return json({ error: "unknown transmission" }, 404);
    }
    if (!["accepted", "rejected", "failed"].includes(payload.outcome ?? "")) {
      return json({ error: "invalid resolution" }, 400);
    }
    try {
      const done = await store.resolve(
        target.id,
        userId,
        payload.outcome as "accepted" | "rejected" | "failed",
        payload.reason ?? "",
        payload.evidence ?? "",
        payload.verdict ?? null,
      );
      return json(
        { resolved: done.resolved, phase: done.phase ?? null },
        done.resolved ? 200 : 409,
      );
    } catch (error) {
      const code = (error as { code?: string }).code;
      if (code === "42501") {
        return json({ error: "not allowed to issue invoices in this workspace" }, 403);
      }
      if (code === "22023") {
        return json({ error: "a reason and the evidence are required" }, 400);
      }
      console.error("send-e-invoice: resolve failed", error);
      return json({ error: "resolve_failed" }, 500);
    }
  }

  if (missing.length > 0) {
    return json({ error: "not_configured", missing, environment }, 409);
  }

  // ── send ─────────────────────────────────────────────────────────────
  const invoiceId = payload.invoice_id ?? "";
  const content = payload.content_base64 ?? "";
  if (!invoiceId || !content) {
    return json({ error: "invoice_id and content_base64 required" }, 400);
  }
  const invoice = await store.invoice(invoiceId);
  if (!invoice || invoice.workspace_id !== workspaceId) {
    return json({ error: "unknown invoice" }, 404);
  }
  // A voided invoice is not sent.
  if (invoice.voided_at) return json({ error: "invoice_voided" }, 409);
  // About ten megabytes once decoded.
  if (content.length > 14_000_000) {
    return json({ error: "document_too_large" }, 413);
  }

  const bytes = Uint8Array.from(atob(content), (c) => c.charCodeAt(0));
  const hash = await sha256(bytes);
  const fileName = payload.file_name || `${invoice.number}.pdf`;
  const mimeType = payload.mime_type || "application/pdf";
  const format = payload.format ||
    (mimeType === "application/pdf" ? "facturX" : "en16931Ubl");

  // 1. PREPARE: durable, deduplicated by the business identity. Any
  // failure here means nothing has left (O1).
  let prepared;
  try {
    prepared = await store.prepare({
      workspaceId,
      invoiceId,
      provider,
      destination,
      environment,
      actor: userId,
      byName: await store.profileName(userId),
      format,
      hash,
      fileName,
      mimeType,
      receiverScheme: payload.receiver_scheme ?? "",
      receiverId: payload.receiver_id ?? "",
      bytes,
      declared: clipDeclared(payload.declared),
    });
  } catch (error) {
    console.error("send-e-invoice: prepare failed", error);
    return json({ error: "prepare_failed" }, 500);
  }
  if (prepared.outcome === "unknown_invoice" || !prepared.id) {
    return json({ error: "unknown invoice" }, 404);
  }
  if (prepared.outcome === "conflict") {
    return json({
      error: "binding_changed",
      phase: prepared.phase,
      transmission_id: prepared.id,
      detail: "This invoice already has a submission to this destination " +
        "with other content; it is not sent again.",
    }, 409);
  }
  const id = prepared.id;
  const state = prepared.phase ?? "prepared";
  // An existing record that is not waiting for a first (or proven
  // no-effect) dispatch answers as it stands: no second upload (O7).
  if (
    prepared.outcome === "existing" && state !== "prepared" &&
    state !== "failed"
  ) {
    return answer(
      state,
      id,
      prepared.external_id ?? "",
      prepared.detail ?? "",
      environment,
      destination,
    );
  }

  // 2. VERIFY the stored artifact before it can leave (O1).
  let artifact;
  try {
    artifact = await store.artifact(id);
  } catch (error) {
    console.error("send-e-invoice: artifact read failed", error);
    return json({ error: "artifact_unavailable" }, 500);
  }
  if (
    !artifact || artifact.sha256 !== hash ||
    (await sha256(artifact.bytes)) !== hash
  ) {
    return json({ error: "artifact_unavailable" }, 500);
  }

  // 3. CLAIM the dispatch atomically; only the winner calls the provider.
  const owner = crypto.randomUUID();
  let claim;
  try {
    claim = await store.claim(id, owner, DISPATCH_WINDOW_SECONDS);
  } catch (error) {
    console.error("send-e-invoice: claim failed", error);
    return json({ error: "claim_failed" }, 500);
  }
  if (!claim.claimed || claim.generation === undefined) {
    return answer(
      claim.phase ?? "sent",
      id,
      claim.external_id ?? "",
      claim.detail ?? "",
      environment,
      destination,
    );
  }

  // 4. POST from the STORED artifact, provider, destination, environment.
  const outcome: Submission = await submit(
    provider,
    configFor(cfg, environment, provider),
    {
      fileName: artifact.fileName || fileName,
      mimeType: artifact.mimeType || mimeType,
      bytes: artifact.bytes,
      format,
      number: invoice.number,
      receiver: artifact.receiverId
        ? { scheme: artifact.receiverScheme, id: artifact.receiverId }
        : undefined,
    },
    fetchImpl,
  );
  // #3090 — the provider's own words are for the server log only.
  if (outcome.status !== "accepted") {
    console.error(
      `send-e-invoice: transmission ${outcome.status}`,
      outcome.detail,
    );
  }

  // 5. RECORD against this owner and generation. If the write is lost the
  // dispatch stays `sent` and expires to `uncertain`: never rejected.
  const detail = clientDetail(
    outcome.status === "uncertain" ? "failed" : outcome.status,
    outcome.detail,
  );
  let recorded = false;
  try {
    recorded = await store.record(
      id,
      claim.generation,
      owner,
      outcome.status,
      outcome.externalId,
      detail,
      outcome.receipt,
    );
  } catch (error) {
    console.error("send-e-invoice: outcome write failed", error);
  }
  if (!recorded) {
    return answer(
      "uncertain",
      id,
      outcome.externalId,
      "",
      environment,
      destination,
    );
  }
  return answer(
    outcome.status,
    id,
    outcome.externalId,
    detail,
    environment,
    destination,
  );
}
