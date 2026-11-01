// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the HMRC actions of accounting-connect: the open obligations of a
// connected VAT registration, the submission of a PREPARED return, and
// HMRC's own check of the fraud-prevention headers.
//
//   POST {action: "hmrc_obligations", connection_id, declaration_id, client}
//   POST {action: "hmrc_submit", connection_id, declaration_id, boxes, client}
//   POST {action: "hmrc_validate_headers", connection_id, client}
//
// The database decides first, with the caller's own token
// (`hmrc_filing_context_v1`: the owner of a GB space with mtdSubmission and
// vatDeclarations on, a prepared and unchanged return, a connected registration
// bound to the space's own VAT number). The URL, the VRN and the period come
// from that answer and the installation's chosen environment, never from the
// request. The nine boxes the client sends are checked against the server's
// own totals before anything leaves. Only a receipt from HMRC files the
// return, through the service-only `file_vat_declaration_hmrc_v1`. A timeout
// or an empty answer is UNCONFIRMED: nothing is filed, no receipt is invented
// and nothing is retried here; a later duplicate is HMRC's to report.

import { hmrcEndpoints } from "../_shared/hmrc_endpoints.ts";
import {
  type ClientValues,
  fraudHeaders,
  FraudHeadersMissing,
  type HmrcFailure,
  HmrcInputError,
  type NineBoxes,
  obligationFor,
  openObligations,
  submitReturn,
  validateHeaders,
  type VendorValues,
} from "../_shared/hmrc_mtd.ts";
import { type Deps, json, resolved, UUID } from "./connection.ts";
import { freshToken } from "./deliver.ts";

const text = (v: unknown, max: number): string =>
  typeof v === "string" ? v.trim().slice(0, max) : "";

/** The browser's own values, as the web client collected them. Nothing is
 * guessed here: a missing value stays empty and the headers refuse. */
function clientOf(raw: unknown, request: Request, now: Date): ClientValues {
  const c = typeof raw === "object" && raw !== null
    ? raw as Record<string, unknown>
    : {};
  const forwarded = text(request.headers.get("x-forwarded-for"), 200).split(
    ",",
  )[0].trim();
  return {
    browserJsUserAgent: text(c.browser_js_user_agent, 400),
    deviceId: text(c.device_id, 100),
    userId: text(c.user_id, 100),
    timezone: text(c.timezone, 20),
    screens: text(c.screens, 200),
    windowSize: text(c.window_size, 100),
    doNotTrack: c.do_not_track === true,
    multiFactor: text(c.multi_factor, 300) || undefined,
    // The person's public address and port as THIS server saw them.
    publicIp: forwarded,
    publicIpTimestamp: now.toISOString(),
    publicPort: text(request.headers.get("x-forwarded-port"), 6),
  };
}

function vendorOf(deps: Deps, client: ClientValues): VendorValues {
  return {
    productName: "Deskilo Cowork",
    version: `deskilo=${text(deps.env("DESKILO_VERSION"), 40) || "unknown"}`,
    publicIp: text(deps.env("HMRC_VENDOR_PUBLIC_IP"), 60),
    forwardedFor: client.publicIp,
  };
}

/** The user id of the bearer token (the gateway verified its signature). */
function subjectOf(authorization: string): string {
  try {
    const payload = authorization.replace(/^Bearer /i, "").split(".")[1] ?? "";
    const json = JSON.parse(
      atob(payload.replace(/-/g, "+").replace(/_/g, "/")),
    );
    const sub = typeof json?.sub === "string" ? json.sub : "";
    return UUID.test(sub) ? sub : "";
  } catch {
    return "";
  }
}

const failureStatus: Record<HmrcFailure["reason"], number> = {
  token: 401,
  not_authorised: 403,
  already_submitted: 409,
  refused: 422,
  busy: 429,
  unreachable: 504,
};

function failed(f: HmrcFailure): Response {
  // A timeout or a server fault is NOT a refusal: the return may have
  // arrived. It is unconfirmed, and the person checks at HMRC before trying
  // again.
  if (f.reason === "unreachable") {
    return json({ error: "unconfirmed", code: f.code }, 504);
  }
  return json({ error: f.reason, code: f.code }, failureStatus[f.reason]);
}

type Context = {
  declaration_id: string;
  period_start: string;
  period_end: string;
  total_vat_cents: number;
  vrn: string;
  connection_id: string;
};

/** Everything the three actions share: the caller's right, the chosen
 * environment, a fresh token and the headers. */
async function prepare(
  deps: Deps,
  request: Request,
  authorization: string,
  body: Record<string, unknown>,
  needsDeclaration: boolean,
): Promise<
  | { response: Response }
  | {
    api: string;
    token: string;
    vrn: string;
    fraud: Record<string, string>;
    context?: Context;
  }
> {
  const connectionId = text(body.connection_id, 40);
  const declarationId = text(body.declaration_id, 40);
  if (
    !UUID.test(connectionId) || (needsDeclaration && !UUID.test(declarationId))
  ) {
    return {
      response: json(
        { error: "connection_id and declaration_id required" },
        400,
      ),
    };
  }
  const endpoints = hmrcEndpoints(deps.env);
  if (!endpoints) {
    return { response: json({ error: "hmrc_not_configured" }, 503) };
  }
  let context: Context | undefined;
  if (needsDeclaration) {
    const r = await deps.caller(authorization).rpc("hmrc_filing_context_v1", {
      p_declaration_id: declarationId,
      p_connection_id: connectionId,
    });
    if (r.error || !r.data) {
      return {
        response: json({ error: "not allowed to file this return" }, 403),
      };
    }
    context = r.data as Context;
  } else {
    const r = await deps.caller(authorization).rpc(
      "hmrc_connection_manageable_v1",
      { p_connection_id: connectionId },
    );
    if (r.error || !r.data) {
      return {
        response: json({ error: "not allowed to use this connection" }, 403),
      };
    }
  }
  const held = await resolved(deps, connectionId);
  if (
    !held || held.revoked || held.target_id !== "hmrc_mtd" ||
    held.status !== "connected"
  ) {
    return { response: json({ error: "connect_hmrc_first" }, 409) };
  }
  const vrn = context?.vrn ?? held.remote_tenant_id;
  if (!/^\d{9}$/.test(vrn) || held.remote_tenant_id !== vrn) {
    return { response: json({ error: "wrong_registration" }, 409) };
  }
  const token = await freshToken(deps, held);
  if (!token) return { response: json({ error: "sign_in_again" }, 401) };
  const client = clientOf(
    body.client,
    request,
    (deps.now ?? (() => new Date()))(),
  );
  let fraud: Record<string, string>;
  try {
    fraud = fraudHeaders(client, vendorOf(deps, client));
  } catch (e) {
    if (e instanceof FraudHeadersMissing) {
      return {
        response: json(
          { error: "fraud_headers_missing", missing: e.missing },
          422,
        ),
      };
    }
    throw e;
  }
  return { api: endpoints.api, token, vrn, fraud, context };
}

const boxesOf = (raw: unknown): NineBoxes | null => {
  if (typeof raw !== "object" || raw === null) return null;
  const b = raw as Record<string, unknown>;
  const keys: (keyof NineBoxes)[] = [
    "vatDueSales",
    "vatDueAcquisitions",
    "totalVatDue",
    "vatReclaimedCurrPeriod",
    "netVatDue",
    "totalValueSalesExVAT",
    "totalValuePurchasesExVAT",
    "totalValueGoodsSuppliedExVAT",
    "totalAcquisitionsExVAT",
  ];
  const out = {} as Record<string, number>;
  for (const k of keys) {
    if (typeof b[k] !== "number") return null;
    out[k] = b[k] as number;
  }
  return out as unknown as NineBoxes;
};

export async function hmrcObligations(
  deps: Deps,
  request: Request,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const p = await prepare(deps, request, authorization, body, true);
  if ("response" in p) return p.response;
  const c = p.context!;
  const r = await openObligations(
    deps.fetcher ?? fetch,
    p.api,
    p.vrn,
    p.token,
    p.fraud,
    c.period_start,
    c.period_end,
  );
  if (!r.ok) return failed(r);
  return json({
    obligations: r.obligations,
    matched: obligationFor(r.obligations, c.period_start, c.period_end),
  });
}

export async function hmrcSubmit(
  deps: Deps,
  request: Request,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const boxes = boxesOf(body.boxes);
  if (!boxes) return json({ error: "nine boxes required" }, 400);
  const p = await prepare(deps, request, authorization, body, true);
  if ("response" in p) return p.response;
  const c = p.context!;
  // The figures are the server's own prepared return, shown as nine boxes:
  // the net of box 3 and box 4 IS the declaration's VAT, to the penny.
  const pence = (n: number) => Math.round(n * 100);
  if (
    pence(boxes.totalVatDue) - pence(boxes.vatReclaimedCurrPeriod) !==
      Number(c.total_vat_cents)
  ) {
    return json({ error: "figures_differ_from_return" }, 409);
  }
  const obligations = await openObligations(
    deps.fetcher ?? fetch,
    p.api,
    p.vrn,
    p.token,
    p.fraud,
    c.period_start,
    c.period_end,
  );
  if (!obligations.ok) return failed(obligations);
  const open = obligationFor(
    obligations.obligations,
    c.period_start,
    c.period_end,
  );
  if (!open) return json({ error: "no_open_obligation" }, 422);
  let result;
  try {
    result = await submitReturn(
      deps.fetcher ?? fetch,
      p.api,
      p.vrn,
      p.token,
      p.fraud,
      open.periodKey,
      boxes,
    );
  } catch (e) {
    if (e instanceof HmrcInputError) {
      return json({ error: "invalid_return", field: e.field }, 422);
    }
    throw e;
  }
  if (!result.ok) return failed(result);
  // HMRC has the return. The receipt files it here; if that write fails the
  // receipt is handed back, because HMRC will refuse a second submission.
  const actor = subjectOf(authorization);
  const filed = await deps.service().rpc("file_vat_declaration_hmrc_v1", {
    p_declaration_id: c.declaration_id,
    p_actor_user: actor,
    p_receipt: result.receipt.formBundleNumber,
  });
  if (filed.error) {
    console.error(
      "accounting-connect: HMRC accepted a return that could not be filed here",
    );
    return json(
      { error: "accepted_not_recorded", receipt: result.receipt },
      500,
    );
  }
  return json({
    status: "filed",
    channel: "hmrc_mtd",
    receipt: result.receipt,
  });
}

export async function hmrcValidateHeaders(
  deps: Deps,
  request: Request,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const p = await prepare(deps, request, authorization, body, false);
  if ("response" in p) return p.response;
  const r = await validateHeaders(
    deps.fetcher ?? fetch,
    p.api,
    p.token,
    p.fraud,
  );
  return r.ok ? json({ code: r.code, errors: r.errors }) : failed(r);
}
