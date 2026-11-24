// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3985 -- the maintenance function: only the database job's secret (or the
// service credential) starts a job; the invoice-originals sweep reports and
// removes nothing until removal is switched on, removes through the Storage
// API in batches when it is, names every file it could not remove, and
// records its run with its lease.
import { assertEquals } from "jsr:@std/assert@1";
import { handle, MAINTENANCE_SECRET_HEADER, REMOVE_BATCH, serve } from "./index.ts";

const SECRET = "maintenance-secret";

type Call = { fn: string; args: Record<string, unknown> };

function fakeService(opts: {
  claim: unknown[];
  remove?: (paths: string[]) => { data: unknown; error: unknown };
}) {
  const calls: Call[] = [];
  const removals: string[][] = [];
  const service = {
    rpc(
      fn: string,
      args: Record<string, unknown>,
    ): Promise<{ data: unknown; error: unknown }> {
      calls.push({ fn, args });
      if (fn === "invoice_originals_sweep_claim_v1") {
        return Promise.resolve({ data: opts.claim, error: null });
      }
      if (fn === "maintenance_finish_v1") {
        return Promise.resolve({ data: true, error: null });
      }
      return Promise.resolve({ data: null, error: null });
    },
    storage: {
      from: (bucket: string) => ({
        remove: (paths: string[]) => {
          removals.push([bucket, ...paths]);
          return Promise.resolve(
            opts.remove
              ? opts.remove(paths)
              : { data: paths.map((name) => ({ name })), error: null },
          );
        },
      }),
    },
  };
  return { service, calls, removals };
}

const files = (n: number) =>
  Array.from(
    { length: n },
    (_, i) => ({ name: `ws/inv/${String(i).padStart(64, "0")}.pdf` }),
  );

async function run(
  fake: ReturnType<typeof fakeService>,
  headers: Record<string, string>,
  job = "invoice-originals-sweep",
) {
  const res = await handle(
    new Request("http://x/maintenance", {
      method: "POST",
      headers,
      body: JSON.stringify({ job }),
    }),
    {
      // deno-lint-ignore no-explicit-any
      service: () => fake.service as any,
      env: (n) => (n === "MAINTENANCE_SECRET" ? SECRET : undefined),
      now: () => 1_800_000_000_000,
    },
  );
  return { status: res.status, body: await res.json() };
}

const finish = (fake: ReturnType<typeof fakeService>) =>
  fake.calls.find((c) => c.fn === "maintenance_finish_v1")?.args;

Deno.test("only the database job's secret starts a job", async () => {
  const fake = fakeService({ claim: [] });
  assertEquals((await run(fake, {})).status, 401);
  assertEquals(
    (await run(fake, { [MAINTENANCE_SECRET_HEADER]: "guess" })).status,
    401,
  );
  assertEquals(fake.calls, []);
});

Deno.test("an unknown job is refused", async () => {
  const fake = fakeService({ claim: [] });
  assertEquals(
    (await run(
      fake,
      { [MAINTENANCE_SECRET_HEADER]: SECRET },
      "drop-everything",
    )).status,
    400,
  );
  assertEquals(fake.calls, []);
});

Deno.test("in report mode nothing is removed: every candidate is named in the record", async () => {
  const fake = fakeService({
    claim: [{ lease_token: "l1", mode: "report", candidates: files(3) }],
  });
  assertEquals(
    (await run(fake, { [MAINTENANCE_SECRET_HEADER]: SECRET })).status,
    200,
  );
  assertEquals(fake.removals, []);
  const args = finish(fake)!;
  assertEquals(args.p_job, "invoice-originals-sweep");
  assertEquals(args.p_lease_token, "l1");
  assertEquals(args.p_counts, { candidates: 3, removed: 0 });
  assertEquals(
    args.p_failures,
    files(3).map((f) => ({ item: f.name, reason: "report_only" })),
  );
});

Deno.test("with removal on, the files go through the Storage API in batches", async () => {
  const n = REMOVE_BATCH + 50;
  const fake = fakeService({
    claim: [{ lease_token: "l1", mode: "remove", candidates: files(n) }],
  });
  assertEquals(
    (await run(fake, { [MAINTENANCE_SECRET_HEADER]: SECRET })).status,
    200,
  );
  assertEquals(fake.removals.map((r) => [r[0], r.length - 1]), [[
    "invoice-originals",
    REMOVE_BATCH,
  ], ["invoice-originals", 50]]);
  assertEquals(finish(fake)!.p_counts, { candidates: n, removed: n });
  assertEquals(finish(fake)!.p_failures, []);
});

Deno.test("a file that was not removed, or a batch the store refused, is named and left", async () => {
  const names = files(3).map((f) => f.name);
  const partly = fakeService({
    claim: [{ lease_token: "l1", mode: "remove", candidates: files(3) }],
    remove: (paths) => ({
      data: paths.slice(1).map((name) => ({ name })),
      error: null,
    }),
  });
  await run(partly, { [MAINTENANCE_SECRET_HEADER]: SECRET });
  assertEquals(finish(partly)!.p_counts, { candidates: 3, removed: 2 });
  assertEquals(finish(partly)!.p_failures, [{
    item: names[0],
    reason: "not_removed",
  }]);

  const refused = fakeService({
    claim: [{ lease_token: "l1", mode: "remove", candidates: files(3) }],
    remove: () => ({ data: null, error: { message: "denied" } }),
  });
  await run(refused, { [MAINTENANCE_SECRET_HEADER]: SECRET });
  assertEquals(finish(refused)!.p_counts, { candidates: 3, removed: 0 });
  assertEquals(
    finish(refused)!.p_failures,
    names.map((item) => ({ item, reason: "remove_failed" })),
  );
});

Deno.test("while another run holds the lease, nothing is read, removed or recorded", async () => {
  const fake = fakeService({ claim: [] });
  const { status, body } = await run(fake, {
    [MAINTENANCE_SECRET_HEADER]: SECRET,
  });
  assertEquals(status, 200);
  assertEquals(body.skipped, "leased");
  assertEquals(fake.removals, []);
  assertEquals(finish(fake), undefined);
});

// #4412 -- an uncaught error is the envelope: a code and the request id, never the error's own words.
Deno.test("#4412 maintenance: a thrown error answers the envelope and no internal message", async () => {
  const saved = console.error;
  console.error = () => {};
  try {
    const answer = await serve({
      service: () => {
        throw new Error("service role key sb_secret_xyz is wrong");
      },
      env: (n) => (n === "MAINTENANCE_SECRET" ? SECRET : undefined),
      now: () => 1_800_000_000_000,
    })(
      new Request("http://x/maintenance", {
        method: "POST",
        headers: { [MAINTENANCE_SECRET_HEADER]: SECRET, "x-request-id": "r-mnt" },
        body: JSON.stringify({ job: "invoice-originals-sweep" }),
      }),
    );
    assertEquals(answer.status, 500);
    const text = await answer.text();
    assertEquals(JSON.parse(text), { error: "internal_error", request_id: "r-mnt" });
    assertEquals(/secret|sb_|wrong/i.test(text), false);
  } finally {
    console.error = saved;
  }
});
