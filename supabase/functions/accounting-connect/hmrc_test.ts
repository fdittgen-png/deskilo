// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the HMRC actions against played databases and a played HMRC: the
// caller's right first, then the figures against the server's own, then the
// obligation, then the submission; only a receipt files the return, and an
// unconfirmed answer files nothing and is never retried here.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { type Deps, handle } from "./index.ts";

const WS = "11111111-1111-4111-8111-111111111111";
const CONN = "33333333-3333-4333-8333-333333333333";
const DECL = "44444444-4444-4444-8444-444444444444";
const USER = "55555555-5555-4555-8555-555555555555";
const API = "https://test-api.service.hmrc.gov.uk";

// The prepared return of the shared contract case "sales and purchases":
// the server's own lines, whose nine boxes are the contract file's.
const LINES = [{
  "percent": 20,
  "gross_cents": 126600,
  "net_cents": 105500,
  "vat_cents": 21100,
  "invoice_count": 4,
  "category": "S",
}, {
  "percent": 0,
  "gross_cents": 33399,
  "net_cents": 33399,
  "vat_cents": 0,
  "invoice_count": 1,
  "category": "Z",
}, {
  "percent": 20,
  "gross_cents": 28800,
  "net_cents": 24000,
  "vat_cents": 4800,
  "invoice_count": 2,
  "direction": "input",
  "category": "S",
}];
const CONTEXT = {
  declaration_id: DECL,
  workspace_id: WS,
  period_start: "2026-01-01",
  period_end: "2026-03-31",
  total_vat_cents: 16300, // box 3 211.00 - box 4 48.00
  lines: LINES,
  vrn: "123456789",
  connection_id: CONN,
};

const BOXES = {
  "vatDueSales": 211.0,
  "vatDueAcquisitions": 0.0,
  "totalVatDue": 211.0,
  "vatReclaimedCurrPeriod": 48.0,
  "netVatDue": 163.0,
  "totalValueSalesExVAT": 1388,
  "totalValuePurchasesExVAT": 240,
  "totalValueGoodsSuppliedExVAT": 0,
  "totalAcquisitionsExVAT": 0,
};

const CLIENT = {
  browser_js_user_agent: "Mozilla/5.0",
  device_id: "7e3f1a52-0000-4000-8000-123456789abc",
  user_id: "user-1",
  timezone: "UTC+01:00",
  screens: "width=1920&height=1080&scaling-factor=1&colour-depth=24",
  window_size: "width=1256&height=803",
  do_not_track: false,
};

const OBLIGATIONS = {
  obligations: [{
    start: "2026-01-01",
    end: "2026-03-31",
    due: "2026-05-07",
    status: "O",
    periodKey: "26A1",
  }],
};

type Rpc = { as: string; fn: string; args: Record<string, unknown> };
type Http = {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
};

function world(opts: {
  context?: unknown;
  contextError?: boolean;
  env?: Record<string, string | undefined>;
  heldTenant?: string;
  fileError?: boolean;
  claim?: Record<string, unknown>;
  hmrc?: (req: Http) => Response | Promise<Response>;
} = {}) {
  const rpcs: Rpc[] = [];
  const http: Http[] = [];
  const answer = (as: string) => ({
    rpc: (fn: string, args: Record<string, unknown>) => {
      rpcs.push({ as, fn, args });
      if (fn === "hmrc_filing_context_v1") {
        return Promise.resolve(
          opts.contextError
            ? { data: null, error: { code: "42501" } }
            : { data: opts.context ?? CONTEXT, error: null },
        );
      }
      if (fn === "hmrc_connection_manageable_v1") {
        return Promise.resolve({ data: { id: CONN }, error: null });
      }
      if (fn === "accounting_credentials_resolved") {
        return Promise.resolve({
          data: {
            id: CONN,
            target_id: "hmrc_mtd",
            auth_kind: "oauth2",
            status: "connected",
            revoked: false,
            remote_tenant_id: opts.heldTenant ?? "123456789",
            token_expires_at: "2026-11-02T00:00:00Z",
            secrets: { access_token: "AT-hmrc", refresh_token: "RT" },
          },
          error: null,
        });
      }
      if (fn === "claim_accounting_refresh_lease") {
        return Promise.resolve({ data: true, error: null });
      }
      if (fn === "release_accounting_refresh_lease") {
        return Promise.resolve({ data: null, error: null });
      }
      if (fn === "claim_hmrc_submission") {
        return Promise.resolve({
          data: opts.claim ?? { claimed: true },
          error: null,
        });
      }
      if (fn === "record_hmrc_acceptance" || fn === "release_hmrc_submission") {
        return Promise.resolve({ data: null, error: null });
      }
      if (fn === "file_vat_declaration_hmrc_v1") {
        return Promise.resolve(
          opts.fileError
            ? { data: null, error: { code: "XX000" } }
            : { data: null, error: null },
        );
      }
      return Promise.resolve({ data: null, error: { code: "42883" } });
    },
  });
  const env: Record<string, string | undefined> = {
    HMRC_ENVIRONMENT: "sandbox",
    HMRC_VENDOR_PUBLIC_IP: "203.0.113.9",
    DESKILO_VERSION: "1.4.0",
    ...opts.env,
  };
  const deps: Deps = {
    caller: () => ({
      ...answer("caller"),
      from: () => ({
        select: () => ({
          in: () => Promise.resolve({ data: null, error: null }),
        }),
      }),
    }),
    service: () => answer("service"),
    env: (n) => env[n],
    redirectUri: "https://x.test/f",
    now: () => new Date("2026-11-01T10:00:00.123Z"),
    sleep: () => Promise.resolve(),
    fetcher: ((url: string | URL | Request, init?: RequestInit) => {
      const req: Http = {
        url: String(url),
        method: String(init?.method ?? "GET"),
        headers: (init?.headers ?? {}) as Record<string, string>,
        body: String(init?.body ?? ""),
      };
      http.push(req);
      if (opts.hmrc) return Promise.resolve(opts.hmrc(req));
      if (req.method === "GET") {
        return Promise.resolve(Response.json(OBLIGATIONS));
      }
      return Promise.resolve(
        Response.json({
          formBundleNumber: "256660290587",
          processingDate: "2026-11-01T10:00:00.000Z",
          chargeRefNumber: "ref",
        }, { status: 201 }),
      );
    }) as typeof fetch,
  };
  return { deps, rpcs, http };
}

const jwt = `x.${btoa(JSON.stringify({ sub: USER })).replace(/=+$/, "")}.y`;
const post = (body: unknown, extra: Record<string, string> = {}) =>
  new Request("https://x.test/functions/v1/accounting-connect", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${jwt}`,
      "content-type": "application/json",
      "x-forwarded-for": "203.0.113.50, 198.51.100.7",
      "x-forwarded-port": "49152",
      ...extra,
    },
    body: JSON.stringify(body),
  });
const submit = {
  action: "hmrc_submit",
  connection_id: CONN,
  declaration_id: DECL,
  boxes: BOXES,
  client: CLIENT,
};
const filedCalls = (w: ReturnType<typeof world>) =>
  w.rpcs.filter((r) => r.fn === "file_vat_declaration_hmrc_v1");

Deno.test("a submission: gates, figures, obligation, return, then the receipt files it once", async () => {
  const w = world();
  const res = await handle(post(submit), w.deps);
  const out = await res.json();
  assertEquals(res.status, 200);
  assertEquals(out.status, "filed");
  assertEquals(out.receipt.formBundleNumber, "256660290587");
  assertEquals(w.rpcs[0], {
    as: "caller",
    fn: "hmrc_filing_context_v1",
    args: { p_declaration_id: DECL, p_connection_id: CONN },
  });
  assertEquals(w.http.map((h) => `${h.method} ${h.url}`), [
    `GET ${API}/organisations/vat/123456789/obligations?from=2026-01-01&to=2026-03-31&status=O`,
    `POST ${API}/organisations/vat/123456789/returns`,
  ]);
  const post1 = w.http[1];
  assertEquals(post1.headers.authorization, "Bearer AT-hmrc");
  assertEquals(
    post1.headers["Gov-Client-Connection-Method"],
    "WEB_APP_VIA_SERVER",
  );
  assertEquals(
    post1.headers["Gov-Client-Public-IP"],
    "198.51.100.7",
    "the hop the proxy appended last",
  );
  assertEquals(post1.headers["Gov-Client-Public-Port"], "49152");
  assertEquals(post1.headers["Gov-Vendor-Public-IP"], "203.0.113.9");
  const sent = JSON.parse(post1.body);
  assertEquals(sent.periodKey, "26A1");
  assertEquals(sent.finalised, true);
  // The order: claim, HMRC, the receipt KEPT, then filed, the claim released.
  assertEquals(
    w.rpcs.filter((r) =>
      [
        "claim_hmrc_submission",
        "record_hmrc_acceptance",
        "file_vat_declaration_hmrc_v1",
        "release_hmrc_submission",
      ].includes(r.fn)
    ).map((r) => r.fn),
    [
      "claim_hmrc_submission",
      "record_hmrc_acceptance",
      "file_vat_declaration_hmrc_v1",
      "release_hmrc_submission",
    ],
  );
  assertEquals(
    w.rpcs.find((r) => r.fn === "release_hmrc_submission")!.args.p_sent,
    false,
  );
  assertEquals(
    post1.headers["Gov-Client-User-IDs"],
    `deskilo=${USER}`,
    "the user id is the verified sign-in's",
  );
  const filed = filedCalls(w);
  assertEquals(filed.length, 1);
  assertEquals(filed[0], {
    as: "service",
    fn: "file_vat_declaration_hmrc_v1",
    args: {
      p_declaration_id: DECL,
      p_actor_user: USER,
      p_receipt: "256660290587",
    },
  });
});

Deno.test("a caller the database refuses reaches neither HMRC nor the filing", async () => {
  const w = world({ contextError: true });
  const res = await handle(post(submit), w.deps);
  assertEquals(res.status, 403);
  assertEquals(w.http.length, 0);
  assertEquals(filedCalls(w).length, 0);
});

Deno.test("a client figure that differs from the server's boxes, in ANY box, is refused before HMRC", async () => {
  // Box 6 alone: boxes 3 and 4 still agree with the declaration's VAT.
  const w = world();
  const res = await handle(
    post({
      ...submit,
      boxes: { ...BOXES, totalValueSalesExVAT: BOXES.totalValueSalesExVAT + 1 },
    }),
    w.deps,
  );
  assertEquals(res.status, 409);
  const out = await res.json();
  assertEquals(out.error, "figures_differ_from_return");
  assertEquals(out.boxes, ["totalValueSalesExVAT"]);
  assertEquals(w.http.length, 0);
  assertEquals(
    w.rpcs.filter((r) => r.fn === "claim_hmrc_submission").length,
    0,
    "nothing is claimed either",
  );
  // The server's own totals are checked too.
  const other = world({ context: { ...CONTEXT, total_vat_cents: 7000 } });
  assertEquals((await handle(post(submit), other.deps)).status, 409);
  assertEquals(other.http.length, 0);
});

Deno.test("what is submitted is the server's boxes, whatever shape the client sent them in", async () => {
  const w = world();
  await handle(post({ ...submit, boxes: { ...BOXES, extra: 1 } }), w.deps);
  const sent = JSON.parse(w.http[1].body);
  assertEquals(
    Object.keys(sent).sort(),
    ["finalised", "periodKey", ...Object.keys(BOXES)].sort(),
  );
});

Deno.test("a double tap is in_flight: one claim, one POST", async () => {
  const w = world({ claim: { claimed: false, state: "in_flight" } });
  const res = await handle(post(submit), w.deps);
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error, "in_flight");
  assertEquals(w.http.length, 0);
});

Deno.test("a return HMRC already accepted is filed from the kept receipt and posts nothing", async () => {
  const w = world({
    claim: {
      claimed: false,
      state: "accepted",
      form_bundle_number: "999",
      processing_date: "d",
      charge_ref_number: "",
    },
  });
  const res = await handle(post(submit), w.deps);
  const out = await res.json();
  assertEquals(out.status, "filed");
  assertEquals(out.receipt.formBundleNumber, "999");
  assertEquals(w.http.length, 0);
  assertEquals(filedCalls(w)[0].args.p_receipt, "999");
});

Deno.test("an attempt that does not reach acceptance releases its claim: deleted when nothing was sent, unconfirmed when the outcome is unknown", async () => {
  const sentOf = (w: ReturnType<typeof world>) =>
    w.rpcs.find((r) => r.fn === "release_hmrc_submission")!.args.p_sent;
  const refused = world({
    hmrc: (r) =>
      r.method === "GET"
        ? Response.json(OBLIGATIONS)
        : Response.json({ code: "TAX_PERIOD_NOT_ENDED" }, { status: 403 }),
  });
  await handle(post(submit), refused.deps);
  assertEquals(sentOf(refused), false, "HMRC refused it: nothing is held");
  const duplicate = world({
    hmrc: (r) =>
      r.method === "GET"
        ? Response.json(OBLIGATIONS)
        : Response.json({ code: "DUPLICATE_SUBMISSION" }, { status: 403 }),
  });
  await handle(post(submit), duplicate.deps);
  assertEquals(
    sentOf(duplicate),
    true,
    "HMRC has it but we hold no receipt: unconfirmed",
  );
  const down = world({
    hmrc: (r) => {
      if (r.method === "GET") return Response.json(OBLIGATIONS);
      throw new Error("timeout");
    },
  });
  await handle(post(submit), down.deps);
  assertEquals(sentOf(down), true);
  const noObligation = world({
    hmrc: () => Response.json({ obligations: [] }),
  });
  await handle(post(submit), noObligation.deps);
  assertEquals(sentOf(noObligation), false, "nothing was posted");
});

Deno.test("an obligations read that fails is unreachable, not unconfirmed: nothing was sent", async () => {
  const w = world({
    hmrc: () => {
      throw new Error("offline");
    },
  });
  const res = await handle(post(submit), w.deps);
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error, "unreachable");
  assertEquals(
    w.rpcs.find((r) => r.fn === "release_hmrc_submission")!.args.p_sent,
    false,
  );
  assertEquals(filedCalls(w).length, 0);
});

Deno.test("no open obligation for the period: nothing is posted", async () => {
  const w = world({ hmrc: () => Response.json({ obligations: [] }) });
  const res = await handle(post(submit), w.deps);
  assertEquals(res.status, 422);
  assertEquals((await res.json()).error, "no_open_obligation");
  assertEquals(w.http.length, 1);
  assertEquals(filedCalls(w).length, 0);
});

Deno.test("HMRC's refusals, read by their code, file nothing", async () => {
  for (
    const [status, code, error, http] of [
      [403, "DUPLICATE_SUBMISSION", "already_submitted", 409],
      [403, "TAX_PERIOD_NOT_ENDED", "refused", 422],
      [403, "CLIENT_OR_AGENT_NOT_AUTHORISED", "not_authorised", 403],
    ] as const
  ) {
    const w = world({
      hmrc: (r) =>
        r.method === "GET"
          ? Response.json(OBLIGATIONS)
          : Response.json({ code }, { status }),
    });
    const res = await handle(post(submit), w.deps);
    assertEquals(res.status, http, code);
    assertEquals((await res.json()).error, error, code);
    assertEquals(filedCalls(w).length, 0, code);
  }
});

Deno.test("a timeout is unconfirmed: nothing is filed, no receipt is invented, nothing is retried", async () => {
  let posts = 0;
  const w = world({
    hmrc: (r) => {
      if (r.method === "GET") return Response.json(OBLIGATIONS);
      posts++;
      throw new Error("timeout");
    },
  });
  const res = await handle(post(submit), w.deps);
  assertEquals(res.status, 504);
  assertEquals((await res.json()).error, "unconfirmed");
  assertEquals(posts, 1);
  assertEquals(filedCalls(w).length, 0);
});

Deno.test("an empty success is unconfirmed too: no receipt, no filing", async () => {
  const w = world({
    hmrc: (r) =>
      r.method === "GET"
        ? Response.json(OBLIGATIONS)
        : Response.json({}, { status: 201 }),
  });
  const res = await handle(post(submit), w.deps);
  assertEquals(res.status, 504);
  assertEquals((await res.json()).code, "NO_RECEIPT");
  assertEquals(filedCalls(w).length, 0);
});

Deno.test("a missing browser value names the header and sends nothing to HMRC", async () => {
  const w = world();
  const res = await handle(
    post({ ...submit, client: { ...CLIENT, device_id: "" } }),
    w.deps,
  );
  assertEquals(res.status, 422);
  const out = await res.json();
  assertEquals(out.error, "fraud_headers_missing");
  assert(out.missing.includes("Gov-Client-Device-ID"));
  assertEquals(w.http.length, 0);
});

Deno.test("no chosen environment, or a connection for another registration, stops before HMRC", async () => {
  const none = world({ env: { HMRC_ENVIRONMENT: undefined } });
  assertEquals((await handle(post(submit), none.deps)).status, 503);
  assertEquals(none.http.length, 0);
  const other = world({ heldTenant: "987654321" });
  const res = await handle(post(submit), other.deps);
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error, "wrong_registration");
  assertEquals(other.http.length, 0);
});

Deno.test("HMRC accepted but the filing failed here: the receipt is handed back", async () => {
  const w = world({ fileError: true });
  const res = await handle(post(submit), w.deps);
  assertEquals(res.status, 500);
  const out = await res.json();
  assertEquals(out.error, "accepted_not_recorded");
  assertEquals(out.receipt.formBundleNumber, "256660290587");
});

Deno.test("the header validator is HMRC's own check, after the caller's right", async () => {
  const w = world({ hmrc: () => Response.json({ code: "VALID_HEADERS" }) });
  const res = await handle(
    post({
      action: "hmrc_validate_headers",
      connection_id: CONN,
      client: CLIENT,
    }),
    w.deps,
  );
  assertEquals((await res.json()).code, "VALID_HEADERS");
  assertEquals(w.http[0].url, `${API}/test/fraud-prevention-headers/validate`);
  assertEquals(w.rpcs[0].fn, "hmrc_connection_manageable_v1");
});

Deno.test("obligations are read for the prepared return's own period", async () => {
  const w = world();
  const res = await handle(
    post({
      action: "hmrc_obligations",
      connection_id: CONN,
      declaration_id: DECL,
      client: CLIENT,
    }),
    w.deps,
  );
  const out = await res.json();
  assertEquals(out.matched.periodKey, "26A1");
  assertEquals(filedCalls(w).length, 0);
});
