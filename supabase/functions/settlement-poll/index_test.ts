// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- the scheduled settlement poll against a fake Mollie (one
// settlement a page, so eleven pages stay small) and a fake database whose
// claim and result follow 0732's rules (pgTAP 399 proves those on the real
// one). The oracle is the recorder's own table: every settlement once.
import { assertEquals } from "jsr:@std/assert@1";
import { handle, MAX_PAGES, POLL_SECRET_HEADER, RUN_BUDGET_MS } from "./index.ts";

const SECRET = "poll-secret-for-tests";
const SERVICE = "service-credential-for-tests";

type Poll = { backfilled: boolean; continuation: string | null; lease: string | null; attempted: string | null };
type Row = Record<string, unknown>;

/** The database: polls per workspace, the recorder's table, the results. */
function database(workspaces: Record<string, string>) {
  const polls: Record<string, Poll> = {};
  for (const ws of Object.keys(workspaces)) polls[ws] = { backfilled: false, continuation: null, lease: null, attempted: null };
  const recorded = new Map<string, number>(); // ws|settlement -> times booked
  const results: Array<Row> = [];
  let tokens = 0;
  let loseLease = false;
  const rpc = (fn: string, args: Row) => {
    if (fn === "settlement_poll_claim_v1") {
      const run = String(args.p_run_started);
      const ws = Object.keys(polls).find((w) => !polls[w].lease && (!polls[w].attempted || polls[w].attempted! < run));
      if (!ws) return Promise.resolve({ data: [], error: null });
      const p = polls[ws];
      p.lease = `lease-${++tokens}`;
      p.attempted = run;
      return Promise.resolve({
        data: [{ workspace_id: ws, backfilled: p.backfilled, continuation: p.continuation, lease_token: p.lease, api_key: workspaces[ws] }],
        error: null,
      });
    }
    if (fn === "settlement_poll_finish_v1") {
      const p = polls[String(args.p_workspace_id)];
      if (loseLease || p.lease !== args.p_lease_token) return Promise.resolve({ data: false, error: null });
      const r = args.p_result as Row;
      const ok = !r.failure;
      p.lease = null;
      p.backfilled = p.backfilled || (ok && r.complete === true);
      p.continuation = ok && r.complete ? null : (r.continuation as string | null);
      results.push({ workspace: args.p_workspace_id, ...r });
      return Promise.resolve({ data: true, error: null });
    }
    if (fn === "record_provider_settlement_v1") {
      const k = `${args.p_workspace_id}|${args.p_settlement_id}`;
      const seen = recorded.has(k);
      if (!seen) recorded.set(k, 1);
      return Promise.resolve({ data: { outcome: seen ? "unchanged" : "new" }, error: null });
    }
    throw new Error(`unexpected rpc ${fn}`);
  };
  return { polls, recorded, results, rpc, lose: () => (loseLease = true) };
}

const settlement = (id: string) => ({
  id,
  status: "paidout",
  settledAt: "2026-03-15T08:00:00+00:00",
  amount: { currency: "EUR", value: "10.00" },
  periods: {},
});

/** Mollie: each key's settlements, newest first, one a page; `failing`
 * answers one settlement's page with a status (or throws for 0). */
function mollie(accounts: Record<string, string[]>, failing: Record<string, number> = {}) {
  const asked: string[] = [];
  const fetchFn = (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    const key = ((init?.headers ?? {}) as Record<string, string>).Authorization.replace("Bearer ", "");
    const ids = accounts[key] ?? [];
    const from = url.searchParams.get("from");
    const at = from ? ids.indexOf(from) : 0;
    const id = ids[at];
    asked.push(`${key}:${id ?? "end"}`);
    const status = id ? failing[id] : undefined;
    if (status === 0) return Promise.reject(new Error("network"));
    if (status) return Promise.resolve(new Response("{}", { status }));
    const next = ids[at + 1];
    return Promise.resolve(new Response(JSON.stringify({
      _embedded: { settlements: id ? [settlement(id)] : [] },
      _links: { next: next ? { href: `https://api.mollie.com/v2/settlements?from=${next}&limit=1` } : null },
    })));
  };
  return { fetchFn, asked };
}

const run = (db: ReturnType<typeof database>, fetchFn: typeof fetch, opts: { headers?: Record<string, string>; now?: () => number } = {}) =>
  handle(
    new Request("http://x", { method: "POST", body: "{}", headers: opts.headers ?? { [POLL_SECRET_HEADER]: SECRET } }),
    {
      service: () => ({ rpc: db.rpc }),
      env: (n) => (n === "SETTLEMENT_POLL_SECRET" ? SECRET : n === "SUPABASE_SERVICE_ROLE_KEY" ? SERVICE : undefined),
      fetch: fetchFn,
      now: opts.now ?? (() => Date.now()),
    },
  );

/** One run a minute: runs of the schedule never share a start. */
let clock = Date.parse("2026-11-12T10:00:00Z");
const nextRun = () => {
  clock += 60_000;
  const t = clock;
  return () => t;
};

const eleven = Array.from({ length: 11 }, (_, i) => `stl_${String(i + 1).padStart(2, "0")}`);

Deno.test("only the database job's secret or the service credential may run it; nothing is read otherwise", async () => {
  const db = database({ ws1: "key1" });
  const m = mollie({ key1: ["stl_01"] });
  const refused: Array<Record<string, string>> = [{}, { [POLL_SECRET_HEADER]: "wrong" }, { Authorization: "Bearer anon-key" }];
  for (const headers of refused) {
    assertEquals((await run(db, m.fetchFn, { headers, now: nextRun() })).status, 401);
  }
  assertEquals(m.asked, [], "no call to Mollie");
  assertEquals(db.recorded.size, 0);
  assertEquals((await run(db, m.fetchFn, { headers: { Authorization: `Bearer ${SERVICE}` }, now: nextRun() })).status, 200);
  assertEquals(db.recorded.size, 1, "an operator's run with the service credential reads");
});

Deno.test("eleven pages: a bounded first read stops with its continuation, the next run finishes it, each settlement once", async () => {
  const db = database({ ws1: "key1" });
  const m = mollie({ key1: eleven });
  const first = await (await run(db, m.fetchFn, { now: nextRun() })).json();
  assertEquals(first.read[0].pages, MAX_PAGES);
  assertEquals(first.read[0].complete, false);
  assertEquals(first.read[0].continuation, "stl_11");
  assertEquals(db.polls.ws1.continuation, "stl_11");
  const second = await (await run(db, m.fetchFn, { now: nextRun() })).json();
  assertEquals([second.read[0].new, second.read[0].complete], [1, true]);
  assertEquals(db.polls.ws1.backfilled, true);
  assertEquals(db.recorded.size, 11);
  assertEquals([...db.recorded.values()].every((n) => n === 1), true, "no settlement is booked twice");
});

Deno.test("after the first full read, a newer settlement is found from the head and the read stops at the known ones", async () => {
  const db = database({ ws1: "key1" });
  const m = mollie({ key1: eleven });
  await run(db, m.fetchFn, { now: nextRun() });
  await run(db, m.fetchFn, { now: nextRun() });
  const asked = m.asked.length;
  // The account grows by one at the head.
  const grown = mollie({ key1: ["stl_00", ...eleven] });
  const res = await (await run(db, grown.fetchFn, { now: nextRun() })).json();
  assertEquals([res.read[0].new, res.read[0].unchanged, res.read[0].pages, res.read[0].complete], [1, 1, 2, true]);
  assertEquals(grown.asked, ["key1:stl_00", "key1:stl_01"], "the older pages are not read again");
  assertEquals(asked, 11);
});

Deno.test("a failure on page 3 keeps pages 1 and 2 and the next run reads page 3 again, not the first two", async () => {
  const db = database({ ws1: "key1" });
  const broken = mollie({ key1: eleven }, { stl_03: 503 });
  const res = await (await run(db, broken.fetchFn, { now: nextRun() })).json();
  assertEquals(res.read[0].new, 2);
  assertEquals(res.read[0].failure, { kind: "unreachable", status: 503 });
  assertEquals(db.polls.ws1.continuation, "stl_03");
  const healed = mollie({ key1: eleven });
  await run(db, healed.fetchFn, { now: nextRun() });
  assertEquals(healed.asked[0], "key1:stl_03", "resumed at the page that failed");
  assertEquals(healed.asked.includes("key1:stl_01"), false);
  assertEquals(db.recorded.size, 11);
});

Deno.test("one workspace's refused key does not stop the others; 429 and the network are retryable", async () => {
  const db = database({ ws1: "bad", ws2: "key2", ws3: "busy", ws4: "down" });
  const m = mollie({ bad: ["stl_b"], key2: ["stl_k"], busy: ["stl_r"], down: ["stl_n"] }, { stl_b: 401, stl_r: 429, stl_n: 0 });
  const res = await (await run(db, m.fetchFn, { now: nextRun() })).json();
  const by = Object.fromEntries(res.read.map((r: Row) => [r.workspace, r]));
  assertEquals((by.ws1 as Row).failure, { kind: "refused", status: 401 });
  assertEquals([(by.ws2 as Row).new, (by.ws2 as Row).failure], [1, null]);
  assertEquals((by.ws3 as Row).failure, { kind: "unreachable", status: 429 });
  assertEquals((by.ws4 as Row).failure, { kind: "unreachable" });
});

Deno.test("a replay of everything recorded books nothing: new 0, the rest unchanged", async () => {
  const db = database({ ws1: "key1" });
  const m = mollie({ key1: ["stl_01", "stl_02"] });
  await run(db, m.fetchFn, { now: nextRun() });
  db.polls.ws1.backfilled = false; // read the whole account again
  const res = await (await run(db, m.fetchFn, { now: nextRun() })).json();
  assertEquals([res.read[0].new, res.read[0].unchanged], [0, 2]);
});

Deno.test("a run past its budget claims no more workspaces; a lost lease keeps nothing", async () => {
  const db = database({ ws1: "key1", ws2: "key2" });
  const m = mollie({ key1: ["stl_01"], key2: ["stl_02"] });
  const t0 = Date.parse("2026-11-12T12:00:00Z");
  let calls = 0;
  // The budget is spent after the first workspace.
  const res = await (await run(db, m.fetchFn, { now: () => (calls++ < 2 ? t0 : t0 + RUN_BUDGET_MS) })).json();
  assertEquals(res.read.length, 1);
  db.lose();
  const lost = await (await run(db, m.fetchFn, { now: nextRun() })).json();
  assertEquals(lost.read.every((r: Row) => r.kept === false), true);
});
