// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice — posts an issued invoice to the workspace's e-invoicing
// platform, so "Envoyer" sends instead of handing the user a file.
//
// The CLIENT builds the document (Factur-X PDF or EN 16931 XML) with the
// same builders that produce the download, and posts the bytes here; this
// function holds the credential and does the transmission. That split is
// deliberate: the platform token must never reach a phone, and the
// document must never be rebuilt from a second, divergent code path.
//
// Providers (#2358, connectors.ts): 'generic' — any platform that accepts
// an HTTP upload with a bearer/basic credential — and the named national
// channels: 'peppol' (an access point), 'fr_pa' (a French plateforme
// agréée), 'it_sdi' (the SdI through an intermediary), 'pl_ksef' (KSeF)
// and 'ro_efactura' (ANAF). The client sends each the syntax it takes;
// the connector refuses any other before a byte leaves.
//
// The credentials are read through einvoice_credentials_resolved(), which
// decrypts the Vault-held secrets for the service role only (#2358).
//
// Every attempt is logged to invoice_transmissions, accepted or not: a
// document that may or may not have left is worse than one that failed.

import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { CORS, preflight } from "../_shared/cors.ts";
import { requiredFields, status as askStatus, submit } from "./connectors.ts";

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

/** The provider and its configuration with the secrets resolved. An
 * instance whose database predates #2358 has no resolver and still keeps
 * plain values in config: read the table then, as before. */
async function credentialsOf(
  admin: SupabaseClient,
  workspaceId: string,
): Promise<{ provider: string; config: Config } | null> {
  const { data, error } = await admin.rpc("einvoice_credentials_resolved", {
    p_workspace_id: workspaceId,
  });
  if (!error) {
    return data
      ? { provider: data.provider ?? "generic", config: data.config ?? {} }
      : null;
  }
  const { data: row } = await admin
    .from("einvoice_credentials")
    .select("provider, config")
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  return row
    ? { provider: row.provider ?? "generic", config: row.config ?? {} }
    : null;
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

Deno.serve(async (req) => {
  // #1553 — the preflight is answered before anything else: it
  // carries no JWT, so any auth or body work would refuse the
  // browser's question instead of answering it.
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  // #1614 — a delegated (MCP) token never transmits an invoice.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
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
    // #2358 — the syntax the client built for this channel, and where the
    // network should deliver it (the buyer's BT-49).
    format?: string;
    receiver_scheme?: string;
    receiver_id?: string;
    transmission_id?: string;
  };
  try {
    payload = await req.json();
  } catch (error) {
    console.warn("send-e-invoice: invalid body", error);
    return json({ error: "invalid body" }, 400);
  }
  const workspaceId = payload.workspace_id ?? "";
  if (!workspaceId) return json({ error: "workspace_id required" }, 400);
  // #2357 — a VAT return is not an upload. France files it through
  // EDI-TVA or EFI, Germany through ELSTER: the owner files it with the
  // authority and records the receipt (mark_vat_declaration_submitted).
  // This channel carries invoices only and never marks a return filed.
  if (payload.declaration_id) {
    return json({
      error: "vat_return_not_transmitted",
      detail: "A VAT return is filed by its owner with the tax authority; " +
        "this channel carries invoices only.",
    }, 410);
  }

  const admin: SupabaseClient = createClient(url, serviceKey);

  // #1078 — WHO is asking, BEFORE anything answers. This check used to
  // sit below the `action:"config"` branch, which meant anyone holding a
  // workspace UUID — no membership, no relationship to the space —
  // learned whether e-invoicing was configured, its provider, which
  // fields were missing and which environments and destinations were
  // wired. A workspace id is not a secret: it travels in links, in
  // exported questionnaires, in invitation flows. `create-payment-order`
  // documents closing this exact hole; the fix was never carried across.
  //
  // And it is scoped by user_id. Without that, `members_select` lets a
  // member read every row of their workspace, so PostgREST returned as
  // many rows as the workspace had members, `maybeSingle()` treated more
  // than one as an error, and EVERY send was refused with "not an admin
  // of this workspace" — to the owner. A one-member fixture is why the
  // tests never saw it.
  const { data: userData, error: userError } = await admin.auth.getUser(
    authorization.replace("Bearer ", ""),
  );
  if (userError || !userData?.user) {
    console.error("send-e-invoice auth failed", userError?.message);
    return json({ error: "unauthorized" }, 401);
  }
  const { data: me } = await admin
    .from("members")
    .select("id, is_admin, is_owner, status")
    .eq("workspace_id", workspaceId)
    .eq("user_id", userData.user.id)
    .maybeSingle();
  // #2137 — or whoever holds issueInvoices, through a role.
  let mayIssue = !!me && (me.is_admin || me.is_owner);
  if (me && me.status === "active" && !mayIssue) {
    const { data: held } = await admin.rpc("member_has_permission", {
      p_member_id: me.id,
      perm: "issueInvoices",
    });
    mayIssue = held === true;
  }
  if (!me || me.status !== "active" || !mayIssue) {
    return json({ error: "not an admin of this workspace" }, 403);
  }

  const credentials = await credentialsOf(admin, workspaceId);
  const fullCfg = (credentials?.config ?? {}) as Config;
  const environment = (
      ENVIRONMENTS as readonly string[]
    ).includes(payload.environment ?? "")
    ? (payload.environment as Environment)
    : "prod";
  const destination = (
      DESTINATIONS as readonly string[]
    ).includes(payload.destination ?? "")
    ? (payload.destination as Destination)
    : "government";
  const cfg = configForDestination(fullCfg, destination);
  // The customer leg is always the generic upload (#568): its platforms
  // are the customer's, not a national channel.
  const provider = destination === "customer"
    ? "generic"
    : (credentials?.provider ?? "generic");
  const missing = missingFor(cfg, environment, provider);

  // The client asks first whether sending is even possible, so it can hide
  // the affordance instead of offering a button that cannot work. The
  // per-environment map doubles as the deployment probe: a client only
  // offers the UAT/dev choice when this function demonstrably understands
  // it — an older function would ignore the parameter and send to prod.
  // The per-destination map (#568) is the same latch for the customer leg.
  if (payload.action === "config") {
    const govCfg = configForDestination(fullCfg, "government");
    const govProvider = credentials?.provider ?? "generic";
    return json({
      configured: missingFor(govCfg, "prod", govProvider).length === 0,
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
    });
  }

  // #917 — a DEVELOPMENT workspace does not talk to the outside world.
  // Reading configuration is fine — the owner sets a rehearsal space up
  // exactly as the real one — but nothing leaves it: the government
  // platform and the customer's service both receive documents that are
  // legal instruments, and a rehearsal document is not one. Checked
  // AFTER the config branch above, which only reports what is set, and
  // before any credential is used.
  const { data: ws } = await admin
    .from("workspaces")
    .select("environment")
    .eq("id", workspaceId)
    .maybeSingle();
  if ((ws?.environment ?? "dev") !== "prod") {
    return json({
      error: "development_workspace",
      detail:
        "This workspace is a development one: it does not send documents " +
        "to a government platform or to a customer. Declare it production " +
        "to send for real.",
    }, 409);
  }

  if (missing.length > 0) {
    return json({ error: "not_configured", missing, environment }, 409);
  }

  // #2358 — what became of an earlier submission: the provider's receipt
  // (a Peppol evidence, the PA lifecycle, the SdI notification, the KSeF
  // number and UPO, the ANAF state) lands on the transmission it answers.
  if (payload.action === "status") {
    const { data: sent } = await admin
      .from("invoice_transmissions")
      .select("id, workspace_id, provider, external_id, environment")
      .eq("id", payload.transmission_id ?? "")
      .maybeSingle();
    if (!sent || sent.workspace_id !== workspaceId || !sent.external_id) {
      return json({ error: "unknown transmission" }, 404);
    }
    const answer = await askStatus(
      sent.provider,
      configFor(
        cfg,
        (sent.environment ?? "prod") as Environment,
        sent.provider,
      ),
      sent.external_id,
    );
    await admin.from("invoice_transmissions").update({
      receipt: answer.receipt,
      receipt_at: new Date().toISOString(),
      ...(answer.status === "rejected" ? { status: "rejected" } : {}),
    }).eq("id", sent.id);
    return json({
      status: answer.status,
      detail: answer.detail,
      receipt: answer.receipt,
    });
  }

  const invoiceId = payload.invoice_id ?? "";
  const content = payload.content_base64 ?? "";
  if (!invoiceId || !content) {
    return json({ error: "invoice_id and content_base64 required" }, 400);
  }
  const { data: invoice } = await admin
    .from("invoices")
    .select("id, number, workspace_id")
    .eq("id", invoiceId)
    .maybeSingle();
  if (!invoice || invoice.workspace_id !== workspaceId) {
    return json({ error: "unknown invoice" }, 404);
  }

  const bytes = Uint8Array.from(atob(content), (c) => c.charCodeAt(0));
  const hash = await sha256(bytes);
  const fileName = payload.file_name || `${invoice.number}.pdf`;
  const mimeType = payload.mime_type || "application/pdf";

  const format = payload.format ||
    (mimeType === "application/pdf" ? "facturX" : "en16931Ubl");
  // Connectors never throw: an unreachable platform is a "failed" outcome.
  const outcome = await submit(
    provider,
    configFor(cfg, environment, provider),
    {
      fileName,
      mimeType,
      bytes,
      format,
      number: invoice.number,
      receiver: payload.receiver_id
        ? { scheme: payload.receiver_scheme ?? "", id: payload.receiver_id }
        : undefined,
    },
  );
  if (outcome.status === "failed") {
    console.error("send-e-invoice: transmission failed", outcome.detail);
  }

  // #1078 — the caller was already resolved at the top; this used to
  // build a second client and ask again.
  const { data: profile } = await admin
    .from("profiles")
    .select("display_name")
    .eq("id", userData.user.id)
    .maybeSingle();

  await admin.from("invoice_transmissions").insert({
    workspace_id: workspaceId,
    invoice_id: invoiceId,
    provider,
    status: outcome.status,
    external_id: outcome.externalId,
    document_hash: hash,
    detail: outcome.detail,
    by_name: profile?.display_name ?? "",
    environment,
    destination,
    format,
    receipt: outcome.receipt,
    receipt_at: Object.keys(outcome.receipt).length > 0
      ? new Date().toISOString()
      : null,
  });

  return json({
    status: outcome.status,
    external_id: outcome.externalId,
    detail: outcome.detail,
    environment,
    destination,
  }, outcome.status === "accepted" ? 200 : 502);
});
