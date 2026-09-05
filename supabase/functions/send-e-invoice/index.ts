// SPDX-License-Identifier: 0BSD
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
// Providers: 'generic' — any platform that accepts an HTTP upload with a
// bearer/basic credential (that covers most plateformes agréées, Peppol
// access points and clearance-platform upload APIs). Named adapters can
// join REQUIRED/submit() without touching the client.
//
// Every attempt is logged to invoice_transmissions, accepted or not: a
// document that may or may not have left is worse than one that failed.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

/** Fields the generic adapter needs before it can send anything. */
const REQUIRED = ["endpoint", "auth_value"];

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
function configFor(cfg: Config, env: Environment): Config {
  if (env === "prod") return cfg;
  return {
    ...cfg,
    endpoint: cfg[`endpoint_${env}`] ?? "",
    auth_value: cfg[`auth_value_${env}`] ?? "",
    auth_header: cfg[`auth_header_${env}`] || cfg.auth_header || "",
    field_name: cfg[`field_name_${env}`] || cfg.field_name || "",
  };
}

function missingFor(cfg: Config, env: Environment): string[] {
  const scoped = configFor(cfg, env);
  return REQUIRED.filter((field) => !scoped[field]);
}

async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** POSTs the document as multipart/form-data — the shape upload endpoints
 * agree on. `auth_header` defaults to Authorization, `field_name` to file. */
async function submitGeneric(
  cfg: Config,
  fileName: string,
  mimeType: string,
  bytes: Uint8Array,
): Promise<{ status: "accepted" | "rejected"; externalId: string; detail: string }> {
  const form = new FormData();
  form.append(
    cfg.field_name || "file",
    new Blob([bytes], { type: mimeType }),
    fileName,
  );
  const res = await fetch(cfg.endpoint, {
    method: "POST",
    headers: { [cfg.auth_header || "Authorization"]: cfg.auth_value },
    body: form,
  });
  const text = await res.text();
  if (!res.ok) {
    return {
      status: "rejected",
      externalId: "",
      detail: `${res.status} ${text}`.slice(0, 500),
    };
  }
  // Most platforms answer JSON with an id under one of these names.
  let externalId = "";
  try {
    const body = JSON.parse(text);
    externalId = String(
      body.id ?? body.documentId ?? body.document_id ?? body.guid ??
        body.transmissionId ?? "",
    );
  } catch {
    // A plain-text acknowledgement is still an acknowledgement.
    externalId = text.trim().slice(0, 120);
  }
  return { status: "accepted", externalId, detail: text.slice(0, 500) };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
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
  };
  try {
    payload = await req.json();
  } catch (error) {
    console.warn("send-e-invoice: invalid body", error);
    return json({ error: "invalid body" }, 400);
  }
  const workspaceId = payload.workspace_id ?? "";
  if (!workspaceId) return json({ error: "workspace_id required" }, 400);

  const admin: SupabaseClient = createClient(url, serviceKey);
  const { data: credentials } = await admin
    .from("einvoice_credentials")
    .select("provider, config")
    .eq("workspace_id", workspaceId)
    .maybeSingle();
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
  const missing = missingFor(cfg, environment);

  // The client asks first whether sending is even possible, so it can hide
  // the affordance instead of offering a button that cannot work. The
  // per-environment map doubles as the deployment probe: a client only
  // offers the UAT/dev choice when this function demonstrably understands
  // it — an older function would ignore the parameter and send to prod.
  // The per-destination map (#568) is the same latch for the customer leg.
  if (payload.action === "config") {
    const govCfg = configForDestination(fullCfg, "government");
    return json({
      configured: missingFor(govCfg, "prod").length === 0,
      provider: credentials?.provider ?? "generic",
      missing: missingFor(govCfg, "prod"),
      environments: Object.fromEntries(
        ENVIRONMENTS.map((env) => [env, missingFor(govCfg, env).length === 0]),
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

  // WHO is asking: the caller's own JWT, checked against the workspace.
  // The service role must never send on behalf of a stranger.
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: me } = await caller
    .from("members")
    .select("id, is_admin, is_owner, status")
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (!me || me.status !== "active" || !(me.is_admin || me.is_owner)) {
    return json({ error: "not an admin of this workspace" }, 403);
  }

  // #534 — VAT declarations ride the SAME configured channel: the owner
  // (only) posts the declaration document to the platform; an accepted
  // upload stamps the declaration submitted with the platform's receipt.
  const declarationId = payload.declaration_id ?? "";
  if (declarationId) {
    if (!me.is_owner) {
      return json({ error: "only the owner files VAT declarations" }, 403);
    }
    const content2 = payload.content_base64 ?? "";
    if (!content2) return json({ error: "content_base64 required" }, 400);
    const { data: declaration } = await admin
      .from("vat_declarations")
      .select("id, workspace_id, status, period_start")
      .eq("id", declarationId)
      .maybeSingle();
    if (!declaration || declaration.workspace_id !== workspaceId) {
      return json({ error: "unknown declaration" }, 404);
    }
    if (declaration.status === "submitted") {
      return json({ error: "already submitted" }, 409);
    }
    const bytes2 = Uint8Array.from(atob(content2), (c) => c.charCodeAt(0));
    let outcome2: {
      status: "accepted" | "rejected" | "failed";
      externalId: string;
      detail: string;
    };
    try {
      // A declaration is a filing: it goes to the government platform no
      // matter what destination a client claims.
      outcome2 = await submitGeneric(
        configFor(configForDestination(fullCfg, "government"), environment),
        payload.file_name || `vat-${declaration.period_start}.pdf`,
        payload.mime_type || "application/pdf",
        bytes2,
      );
    } catch (error) {
      console.error("send-e-invoice: VAT declaration transmission failed", error);
      outcome2 = {
        status: "failed",
        externalId: "",
        detail: String(error).slice(0, 500),
      };
    }
    if (outcome2.status === "accepted") {
      await admin.from("vat_declarations").update({
        status: "submitted",
        submitted_at: new Date().toISOString(),
        submitted_channel: "platform",
        submitted_receipt:
          (outcome2.externalId || outcome2.detail).slice(0, 500),
      }).eq("id", declarationId);
    }
    return json({
      status: outcome2.status,
      external_id: outcome2.externalId,
      detail: outcome2.detail,
      environment,
    }, outcome2.status === "accepted" ? 200 : 502);
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

  let outcome: {
    status: "accepted" | "rejected" | "failed";
    externalId: string;
    detail: string;
  };
  try {
    outcome = await submitGeneric(
      configFor(cfg, environment),
      fileName,
      mimeType,
      bytes,
    );
  } catch (error) {
    console.error("send-e-invoice: transmission failed", error);
    outcome = {
      status: "failed",
      externalId: "",
      detail: String(error).slice(0, 500),
    };
  }

  const { data: profile } = await admin
    .from("profiles")
    .select("display_name")
    .eq("id", (await caller.auth.getUser()).data.user?.id ?? "")
    .maybeSingle();

  await admin.from("invoice_transmissions").insert({
    workspace_id: workspaceId,
    invoice_id: invoiceId,
    provider: credentials?.provider ?? "generic",
    status: outcome.status,
    external_id: outcome.externalId,
    document_hash: hash,
    detail: outcome.detail,
    by_name: profile?.display_name ?? "",
    environment,
    destination,
  });

  return json({
    status: outcome.status,
    external_id: outcome.externalId,
    detail: outcome.detail,
    environment,
    destination,
  }, outcome.status === "accepted" ? 200 : 502);
});
