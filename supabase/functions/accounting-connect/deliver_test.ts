// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The delivery of a period with the database and Pennylane played: the
// postings are the engine's answer to the caller, every document is
// recorded before it is sent and created once, a second run creates
// nothing, an answer lost after a create is read back instead of created
// again, an unmapped role blocks its document with the key named, and every
// refusal (who, which target, which period, a blocked book) delivers
// nothing.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { type Deps, handle } from "./index.ts";

const WS = "11111111-1111-4111-8111-111111111111";
const SITE = "22222222-2222-4222-8222-222222222222";
const CONN = "33333333-3333-4333-8333-333333333333";
const INV = "44444444-4444-4444-8444-444444444444";
const INV2 = "55555555-5555-4555-8555-555555555555";

const sale = (id: string, number: string, day: string) => ({
  journal: "sales",
  kind: "invoice",
  date: day,
  document_id: id,
  document_number: number,
  currency: "EUR",
  lines: [
    {
      role: "customers",
      qualifier: null,
      account_code: "411",
      debit_cents: 12000,
      credit_cents: 0,
    },
    {
      role: "revenue",
      qualifier: "standard",
      account_code: "706",
      debit_cents: 0,
      credit_cents: 10000,
    },
    {
      role: "vat_output",
      qualifier: "standard",
      account_code: "44571",
      debit_cents: 0,
      credit_cents: 2000,
    },
  ],
});

const receipt = (id: string, number: string, day: string) => ({
  journal: "bank",
  kind: "receipt",
  date: day,
  document_id: id,
  document_number: number,
  currency: "EUR",
  lines: [
    {
      role: "bank",
      qualifier: null,
      account_code: "512",
      debit_cents: 12000,
      credit_cents: 0,
    },
    {
      role: "customers",
      qualifier: null,
      account_code: "411",
      debit_cents: 0,
      credit_cents: 12000,
    },
  ],
});

const allMaps = [
  { kind: "account", key: "customers", remote_id: "41100", remote_code: "" },
  {
    kind: "account",
    key: "revenue:standard",
    remote_id: "70600",
    remote_code: "",
  },
  {
    kind: "account",
    key: "vat_output:standard",
    remote_id: "44571",
    remote_code: "",
  },
  { kind: "account", key: "bank", remote_id: "51200", remote_code: "" },
];

type Row = {
  status: string;
  idempotency_key: string;
  remote_id: string;
  sha: string;
  error: string;
};

/** The rules of `record_accounting_delivery`, in memory. */
function deliveryLog() {
  const rows = new Map<string, Row>();
  let keys = 0;
  const record = (a: Record<string, unknown>) => {
    const identity =
      `c:${a.p_connection_id}:${a.p_document_kind}:${a.p_document_id}:${a.p_event_date}`;
    const status = String(a.p_status);
    const remote = String((a.p_remote as Record<string, unknown>).id ?? "");
    const sha = String(a.p_payload_sha256);
    let row = rows.get(identity);
    if (!row) {
      row = {
        status: status === "acknowledged" ? "sent" : status,
        idempotency_key: (++keys).toString(16).padStart(64, "0"),
        remote_id: "",
        sha,
        error: String(a.p_error),
      };
      rows.set(identity, row);
      if (status !== "acknowledged") {
        return { data: { ...row, outcome: "created" }, error: null };
      }
    }
    if (row.status === "acknowledged") {
      if (row.sha === sha && (!remote || remote === row.remote_id)) {
        return { data: { ...row, outcome: "unchanged" }, error: null };
      }
      if (row.sha !== sha) {
        return {
          data: null,
          error: { code: "23514", message: "needs a correction" },
        };
      }
    }
    if (status === "generated") {
      return { data: { ...row, outcome: "existing" }, error: null };
    }
    row.status = status;
    row.error = status === "conflict" || status === "failed"
      ? String(a.p_error)
      : "";
    if (status === "acknowledged") row.remote_id = remote;
    return { data: { ...row, outcome: "updated" }, error: null };
  };
  return { rows, record };
}

/** A Pennylane company with journals and ledger entries. */
function pennylane() {
  const entries: Record<string, unknown>[] = [];
  let next = 900;
  const st = { posts: 0, loseNextAnswer: false, gets: 0 };
  const fetcher =
    (async (input: string | URL | Request, init?: RequestInit) => {
      const url = new URL(String(input));
      const path = url.pathname.replace(/^.*\/v2\//, "");
      if (path === "journals") {
        return Response.json({
          items: [{ id: 1, code: "VE" }, { id: 2, code: "BQ" }],
          has_more: false,
        });
      }
      if (path === "ledger_entries" && (init?.method ?? "GET") === "GET") {
        st.gets++;
        const f = JSON.parse(url.searchParams.get("filter") ?? "[]")[0];
        return Response.json({
          items: entries.filter((e) => e.external_reference === f.value),
        });
      }
      if (path === "ledger_entries" && init?.method === "POST") {
        st.posts++;
        const body = JSON.parse(String(init.body));
        const entry = { ...body, id: next++ };
        entries.push(entry);
        if (st.loseNextAnswer) {
          st.loseNextAnswer = false;
          throw new TypeError("connection reset");
        }
        return Response.json(entry, { status: 201 });
      }
      return new Response("not found", { status: 404 });
    }) as typeof fetch;
  return { entries, st, fetcher };
}

function world(opts: {
  postings?: unknown[];
  blockers?: unknown[];
  maps?: typeof allMaps;
  manageable?: boolean;
  target?: string;
  status?: string;
  /** The connection was revoked (offboarding): the credentials answer so. */
  revoked?: boolean;
  /** An OAuth connection whose token expires at this instant. */
  oauthExpiresAt?: string;
  refresh?: () => Response;
  /** The invoices table as the caller reads it; null refuses the read. */
  invoices?: { id: string; replaces_number?: string; vat_totals?: unknown }[] | null;
  /** The target's API, when it is not Pennylane (#2371: a played QuickBooks). */
  fetcher?: typeof fetch;
  /** The remote company the connection reaches. */
  tenant?: string;
  /** Another run holds every delivery: the log answers in_flight to a
   * prepare that names a window (what the function's budget gives it). */
  otherRunSending?: boolean;
} = {}) {
  const log = deliveryLog();
  const pl = pennylane();
  const order: string[] = [];
  const stored: Record<string, unknown>[] = [];
  const calls: { as: string; fn: string; args: Record<string, unknown> }[] = [];
  const postings = opts.postings ??
    [sale(INV, "F-1", "2026-03-02"), receipt(INV, "F-1", "2026-03-09")];
  const caller = {
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ as: "caller", fn, args });
      if (fn === "accounting_connection_manageable_v1") {
        return Promise.resolve(
          opts.manageable === false
            ? { data: null, error: { code: "42501" } }
            : {
              data: {
                id: CONN,
                workspace_id: WS,
                target_id: opts.target ?? "pennylane_api",
                auth_kind: "token",
              },
              error: null,
            },
        );
      }
      if (fn === "accounting_connections_v1") {
        return Promise.resolve({
          data: [{ id: CONN, maps: opts.maps ?? allMaps }],
          error: null,
        });
      }
      if (fn === "compute_postings") {
        return Promise.resolve({
          data: { postings, blockers: opts.blockers ?? [] },
          error: null,
        });
      }
      if (fn === "posting_parties") {
        return Promise.resolve({
          data: { [INV]: { kind: "member", number: "M-7", name: "Ada" } },
          error: null,
        });
      }
      return Promise.resolve({ data: null, error: { code: "42883" } });
    },
    from: (table: string) => ({
      select: (columns: string) => ({
        in: (column: string, values: string[]) => {
          calls.push({
            as: "caller",
            fn: `${table}.${columns}`,
            args: { [column]: values },
          });
          if (opts.invoices === null) {
            return Promise.resolve({ data: null, error: { code: "42501" } });
          }
          const rows = (opts.invoices ?? []).filter((r) =>
            values.includes(r.id)
          );
          return Promise.resolve({ data: rows, error: null });
        },
      }),
    }),
  };
  const service = {
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ as: "service", fn, args });
      if (fn === "accounting_credentials_resolved") {
        return Promise.resolve({
          data: {
            id: CONN,
            workspace_id: WS,
            issuer_site_id: SITE,
            target_id: opts.target ?? "pennylane_api",
            auth_kind: opts.oauthExpiresAt ? "oauth2" : "token",
            status: opts.status ?? "connected",
            remote_tenant_id: opts.tenant ?? "",
            revoked: opts.revoked ?? false,
            token_expires_at: opts.oauthExpiresAt ?? null,
            secrets: { access_token: "PL-secret", refresh_token: "RT-secret" },
          },
          error: null,
        });
      }
      if (fn === "record_accounting_delivery") {
        if (
          opts.otherRunSending && args.p_status === "generated" &&
          Number(args.p_in_flight_seconds) > 0
        ) {
          return Promise.resolve({
            data: {
              status: "sent",
              idempotency_key: "0".repeat(64),
              remote_id: "",
              outcome: "in_flight",
            },
            error: null,
          });
        }
        return Promise.resolve(log.record(args));
      }
      // The refresh lease (0648): no other writer in this world.
      if (fn === "claim_accounting_refresh_lease") {
        return Promise.resolve({ data: true, error: null });
      }
      if (fn === "release_accounting_refresh_lease") {
        return Promise.resolve({ data: null, error: null });
      }
      if (fn === "set_accounting_credentials" || fn === "set_accounting_credentials_leased") {
        stored.push(args);
        return Promise.resolve({ data: { id: CONN }, error: null });
      }
      return Promise.resolve({ data: null, error: { code: "42883" } });
    },
  };
  const deps: Deps = {
    caller: () => caller,
    service: () => service,
    env: (name) =>
      ({
        ACCOUNTING_PENNYLANE_API_CLIENT_ID: "app-id",
        ACCOUNTING_PENNYLANE_API_CLIENT_SECRET: "app-secret",
      } as Record<
        string,
        string
      >)[name],
    redirectUri: "https://x.test/functions/v1/accounting-connect",
    fetcher: ((input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      if (url.includes("/oauth/token")) {
        order.push("token");
        return Promise.resolve(
          opts.refresh?.() ??
            Response.json({
              access_token: "AT-fresh",
              refresh_token: "RT-2",
              expires_in: 3600,
            }),
        );
      }
      order.push(
        `pennylane ${new URL(url).pathname.split("/").pop()} ${
          (init?.headers as Record<string, string>)?.authorization ?? ""
        }`,
      );
      return (opts.fetcher ?? pl.fetcher)(input, init);
    }) as typeof fetch,
    now: () => new Date("2026-04-02T10:00:00Z"),
  };
  return { deps, calls, log, pl, order, stored };
}

const run = (
  w: ReturnType<typeof world>,
  extra: Record<string, unknown> = {},
  auth = "Bearer user-token",
) =>
  handle(
    new Request("https://x.test/functions/v1/accounting-connect", {
      method: "POST",
      headers: { Authorization: auth, "content-type": "application/json" },
      body: JSON.stringify({
        action: "deliver",
        connection_id: CONN,
        from: "2026-03-01",
        to: "2026-03-31",
        ...extra,
      }),
    }),
    w.deps,
  );

Deno.test("a period is delivered once: a second run creates nothing", async () => {
  const w = world();
  const first = await run(w);
  assertEquals(first.status, 200);
  const body = await first.json();
  assertEquals(body.counts, { acknowledged: 2 });
  assertEquals(w.pl.st.posts, 2);
  // Every entry carries its delivery's idempotency key and balances.
  const keys = [...w.log.rows.values()].map((r) => r.idempotency_key).sort();
  assertEquals(w.pl.entries.map((e) => e.external_reference).sort(), keys);
  assertEquals(w.pl.entries[0].journal_id, 1);
  assertEquals(w.pl.entries[1].journal_id, 2);
  // The postings were the engine's answer to the caller, not the client's.
  assert(w.calls.some((c) => c.as === "caller" && c.fn === "compute_postings"));
  assert(
    !w.calls.some((c) => c.as === "service" && c.fn === "compute_postings"),
  );

  const second = await run(w);
  assertEquals((await second.json()).counts, { unchanged: 2 });
  assertEquals(w.pl.st.posts, 2);
  // No answer leaks a secret.
  assert(!JSON.stringify(body).includes("PL-secret"));
});

Deno.test("an answer lost after the create is read back, never created twice", async () => {
  const w = world({ postings: [sale(INV, "F-1", "2026-03-02")] });
  w.pl.st.loseNextAnswer = true;
  const first = await (await run(w)).json();
  assertEquals(first.counts, { conflict: 1 });
  assertEquals(w.pl.st.posts, 1);
  const second = await (await run(w)).json();
  assertEquals(second.counts, { acknowledged: 1 });
  assertEquals(w.pl.st.posts, 1);
  assertEquals(w.pl.entries.length, 1);
});

Deno.test("two entries holding one delivery's key stay a conflict and nothing is sent", async () => {
  const w = world({ postings: [sale(INV, "F-1", "2026-03-02")] });
  w.pl.st.loseNextAnswer = true;
  await run(w);
  w.pl.entries.push({ ...w.pl.entries[0], id: 999 });
  const again = await (await run(w)).json();
  assertEquals(again.counts, { conflict: 1 });
  assertEquals(w.pl.st.posts, 1);
  assert([...w.log.rows.values()][0].error.includes("2 documents"));
});

Deno.test("an unmapped role blocks its document with the key named; the others go", async () => {
  const w = world({ maps: allMaps.filter((m) => m.key !== "bank") });
  const body = await (await run(w)).json();
  assertEquals(body.counts, { acknowledged: 1, blocked: 1 });
  const blocked = body.results.find((r: { status: string }) =>
    r.status === "blocked"
  );
  assertEquals(blocked.document_kind, "receipt");
  assertEquals(blocked.missing, ["account bank"]);
  assertEquals(w.pl.st.posts, 1);
});

Deno.test("a delivery another run is still sending is reported in flight: nothing is read back or created", async () => {
  const w = world({
    postings: [sale(INV, "F-1", "2026-03-02")],
    otherRunSending: true,
  });
  const body = await (await run(w)).json();
  assertEquals(body.counts, { in_flight: 1 });
  assertEquals(body.results[0].status, "in_flight");
  assertEquals([w.pl.st.gets, w.pl.st.posts], [0, 0]);
  // The window is the function's wall-clock budget, in seconds.
  const prepare = w.calls.find((c) => c.fn === "record_accounting_delivery")!;
  assertEquals(prepare.args.p_in_flight_seconds, 400);
});

Deno.test("one document is delivered again on its own", async () => {
  const w = world({
    postings: [sale(INV, "F-1", "2026-03-02"), sale(INV2, "F-2", "2026-03-03")],
  });
  const body = await (await run(w, { document: { kind: "invoice", id: INV2 } }))
    .json();
  assertEquals(
    body.results.map((r: { document_number: string }) => r.document_number),
    ["F-2"],
  );
  assertEquals(w.pl.st.posts, 1);
});

Deno.test("a blocked book, a refused caller, a foreign target, a closed connection and a long period deliver nothing", async () => {
  const blocked = world({
    blockers: [{ block: "unmappedRole", subject: "bank" }],
  });
  const b = await run(blocked);
  assertEquals(b.status, 409);
  assertEquals((await b.json()).blockers, [{
    block: "unmappedRole",
    subject: "bank",
  }]);

  const stranger = world({ manageable: false });
  assertEquals((await run(stranger)).status, 403);
  assert(
    !stranger.calls.some((c) =>
      c.fn === "compute_postings" || c.fn === "accounting_credentials_resolved"
    ),
  );

  const foreign = world({ target: "datev" });
  assertEquals((await (await run(foreign)).json()).error, "not_delivered_here");

  const expired = world({ status: "expired" });
  assertEquals((await run(expired)).status, 409);

  const long = world();
  assertEquals((await run(long, { to: "2026-04-01" })).status, 400);
  assertEquals(
    (await run(long, { document: { kind: "invoice", id: "x" } })).status,
    400,
  );

  for (const w of [blocked, stranger, foreign, expired, long]) {
    assertEquals(w.pl.st.posts, 0);
    assertEquals(w.log.rows.size, 0);
  }
});

Deno.test("an assistant's delegated token never delivers", async () => {
  const w = world();
  const claims = btoa(JSON.stringify({ sub: "u", client_id: "assistant" }))
    .replace(/=+$/, "");
  const res = await run(w, {}, `Bearer h.${claims}.s`);
  assertEquals(res.status, 403);
  assertEquals(w.calls.length, 0);
});

Deno.test("two payments of one invoice on one day are two deliveries", async () => {
  const w = world({
    postings: [
      receipt(INV, "F-1", "2026-03-09"),
      receipt(INV, "F-1", "2026-03-09"),
    ],
  });
  const body = await (await run(w)).json();
  assertEquals(body.counts, { acknowledged: 2 });
  assertEquals(w.pl.st.posts, 2);
  const [a, b] = body.results.map((r: { document_id: string }) =>
    r.document_id
  );
  assert(a !== b && a !== INV && b !== INV);
  // Each is delivered again by its own id, and nothing is created twice.
  const again = await (await run(w, { document: { kind: "receipt", id: b } }))
    .json();
  assertEquals(again.counts, { unchanged: 1 });
  assertEquals(w.pl.st.posts, 2);
});

Deno.test("a document acknowledged with another content is refused by the log, with its code", async () => {
  const w = world({ postings: [sale(INV, "F-1", "2026-03-02")] });
  await run(w);
  const changed = world({
    postings: [{
      ...sale(INV, "F-1", "2026-03-02"),
      document_number: "F-1bis",
    }],
  });
  // The same log: the document was acknowledged with the first content.
  changed.log.rows.clear();
  for (const [k, v] of w.log.rows) changed.log.rows.set(k, v);
  const body = await (await run(changed)).json();
  assertEquals(body.results[0].status, "failed");
  assertEquals(body.results[0].code, "23514");
  assertEquals(changed.pl.st.posts, 0);
});

Deno.test("a token about to expire is refreshed before the first call; a refused refresh sends nothing", async () => {
  const w = world({ oauthExpiresAt: "2026-04-02T10:01:00Z" });
  assertEquals((await run(w)).status, 200);
  assertEquals(w.order[0], "token");
  assert(w.order.slice(1).every((c) => c.endsWith("Bearer AT-fresh")));
  assertEquals(w.stored.length, 1);

  const gone = world({
    oauthExpiresAt: "2026-04-02T10:01:00Z",
    refresh: () => Response.json({ error: "invalid_grant" }, { status: 400 }),
  });
  const res = await run(gone);
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error, "not_connected");
  assertEquals(gone.order, ["token"]);
  assertEquals(
    (gone.stored[0].p_patch as Record<string, unknown>).status,
    "expired",
  );
  assertEquals(gone.log.rows.size, 0);
});

const CRN = "66666666-6666-4666-8666-666666666666";

const creditNote = {
  ...sale(CRN, "A-1", "2026-03-20"),
  kind: "credit_note",
  lines: [
    {
      role: "customers",
      qualifier: null,
      account_code: "411",
      debit_cents: 0,
      credit_cents: 1200,
    },
    {
      role: "revenue",
      qualifier: "standard",
      account_code: "706",
      debit_cents: 1000,
      credit_cents: 0,
    },
    {
      role: "vat_output",
      qualifier: "standard",
      account_code: "44571",
      debit_cents: 200,
      credit_cents: 0,
    },
  ],
};

Deno.test("the invoice a credit note corrects is read as the caller; a refused read delivers nothing", async () => {
  const w = world({
    postings: [sale(INV, "F-1", "2026-03-02"), creditNote],
    invoices: [{ id: CRN, replaces_number: "F-1" }],
  });
  assertEquals((await run(w)).status, 200);
  const read = w.calls.find((c) => c.fn === "invoices.id, replaces_number")!;
  assertEquals([read.as, read.args], ["caller", { id: [CRN] }]);

  // A read refused outright, and one row-level security answers empty.
  for (const invoices of [null, []]) {
    const refused = world({ postings: [creditNote], invoices });
    const res = await run(refused);
    assertEquals(res.status, 403);
    assertEquals(refused.pl.st.posts, 0);
    assertEquals(refused.log.rows.size, 0);
  }
});

Deno.test("a period without a credit note reads no invoice", async () => {
  const w = world();
  assertEquals((await run(w)).status, 200);
  assert(!w.calls.some((c) => c.fn.startsWith("invoices.")));
});

/** #2371 — a QuickBooks Canada company that books a sale's tax as its
 * code says: one tax line at 20 % on the line's net. */
function quickbooks() {
  const st = { posts: 0 };
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    if (url.pathname.includes("/companyinfo/")) return Response.json({ CompanyInfo: { Country: "CA" } });
    if (url.pathname.endsWith("/preferences")) {
      return Response.json({ Preferences: { SalesFormsPrefs: { CustomTxnNumbers: true } } });
    }
    if (url.pathname.endsWith("/query")) {
      const entity = /from (\w+)/.exec(url.searchParams.get("query") ?? "")![1];
      // The code the sale's rate group is mapped to, and its one rate.
      const rows: Record<string, unknown[]> = {
        TaxCode: [{ Id: "TC-20", SalesTaxRateList: { TaxRateDetail: [{ TaxRateRef: { value: "T20" } }] } }],
        TaxRate: [{ Id: "T20", RateValue: 20 }],
      };
      return Response.json({ QueryResponse: { [entity]: rows[entity] ?? [] } });
    }
    if (init?.method === "POST") {
      st.posts++;
      const body = JSON.parse(String(init.body)) as Record<string, unknown>;
      if (url.pathname.endsWith("/customer")) return Response.json({ Customer: { ...body, Id: "C-1" } });
      const net = (body.Line as Record<string, unknown>[]).reduce((n, l) => n + Number(l.Amount), 0);
      const tax = Number((body.TxnTaxDetail as Record<string, unknown>).TotalTax);
      return Response.json({
        Invoice: {
          ...body,
          Id: "Q-1",
          SyncToken: "0",
          TotalAmt: net + tax,
          TxnTaxDetail: {
            TotalTax: tax,
            TaxLine: [{
              Amount: Math.round(net * 20) / 100,
              DetailType: "TaxLineDetail",
              TaxLineDetail: { TaxRateRef: { value: "T20" }, TaxPercent: 20, NetAmountTaxable: net },
            }],
          },
        },
      });
    }
    return new Response("not found", { status: 404 });
  }) as typeof fetch;
  return { st, fetcher };
}

const qboMaps = [
  { kind: "item", key: "revenue:standard", remote_id: "IT-1", remote_code: "" },
  { kind: "item", key: "vat_output:standard", remote_id: "TC-20", remote_code: "" },
];

Deno.test("#2371 a QuickBooks delivery reads each sale's frozen tax as the caller and checks the booked split with it", async () => {
  const qb = quickbooks();
  const w = world({
    target: "quickbooks_online_ca",
    maps: qboMaps as typeof allMaps,
    postings: [{ ...sale(INV, "F-1", "2026-03-02"), currency: "CAD" }],
    invoices: [{ id: INV, vat_totals: [{ percent: 20, category: "S", net_cents: 10000, vat_cents: 2000, gross_cents: 12000 }] }],
    fetcher: qb.fetcher,
    tenant: "9130350000000001",
  });
  const res = await run(w);
  assertEquals(res.status, 200, JSON.stringify(await res.clone().json()));
  const read = w.calls.find((c) => c.fn === "invoices.id, vat_totals")!;
  assertEquals([read.as, read.args], ["caller", { id: [INV] }]);
  assertEquals([...w.log.rows.values()].map((r) => r.status), ["acknowledged"]);
});

Deno.test("#2371 a sale whose frozen tax cannot be read delivers nothing to QuickBooks", async () => {
  for (const invoices of [null, []]) {
    const qb = quickbooks();
    const w = world({
      target: "quickbooks_online_ca",
      maps: qboMaps as typeof allMaps,
      postings: [{ ...sale(INV, "F-1", "2026-03-02"), currency: "CAD" }],
      invoices,
      fetcher: qb.fetcher,
      tenant: "9130350000000001",
    });
    assertEquals((await run(w)).status, 403);
    assertEquals(qb.st.posts, 0);
  }
});


Deno.test("#2371 through the runner: a taxed sale whose invoice froze an empty breakdown is a conflict, one with none is refused", async () => {
  // vat_totals [] on a sale that carries 20.00 of tax: the evidence does not
  // prove a zero-tax document, so the split stays unverified.
  const qb = quickbooks();
  const empty = world({
    target: "quickbooks_online_ca",
    maps: qboMaps as typeof allMaps,
    postings: [{ ...sale(INV, "F-1", "2026-03-02"), currency: "CAD" }],
    invoices: [{ id: INV, vat_totals: [] }],
    fetcher: qb.fetcher,
    tenant: "9130350000000001",
  });
  assertEquals((await run(empty)).status, 200);
  const [row] = [...empty.log.rows.values()];
  assertEquals(row.status, "conflict");
  assert(row.error.includes("the frozen breakdown does not explain the tax of standard"), row.error);

  // An invoice row without its breakdown at all is missing evidence: the
  // run fails closed before anything is sent.
  const none = quickbooks();
  const absent = world({
    target: "quickbooks_online_ca",
    maps: qboMaps as typeof allMaps,
    postings: [{ ...sale(INV, "F-1", "2026-03-02"), currency: "CAD" }],
    invoices: [{ id: INV }],
    fetcher: none.fetcher,
    tenant: "9130350000000001",
  });
  assertEquals((await run(absent)).status, 403);
  assertEquals(none.st.posts, 0);
});

// #3336 L14 -- a connection revoked while work was unresolved: the recovery
// request (a delivery run) reads the credentials, finds them revoked and asks
// the provider for nothing -- no readback, no create, no token refresh --
// and records no new delivery; the uncertainty stays for a person to resolve.
Deno.test("a revoked connection's recovery run makes no provider call and records nothing", async () => {
  const revoked = world({
    status: "revoked",
    revoked: true,
  });
  const answer = await run(revoked);
  assertEquals(answer.status, 409);
  assertEquals(revoked.order, [], "the provider was never called");
  assertEquals(revoked.stored, [], "no token was refreshed or stored");
  assert(
    !revoked.calls.some((c) => c.fn === "record_accounting_delivery"),
    "no delivery was recorded on a revoked connection",
  );
});
