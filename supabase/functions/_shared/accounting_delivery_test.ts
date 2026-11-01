// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The delivery state machine against a store that keeps the rules of
// `record_accounting_delivery` (one row per identity, the idempotency key
// stored first, an acknowledged digest is a no-op, a disagreeing remote id
// is a conflict) and a target that can time out after it created.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  type AccountingMap,
  databaseStore,
  deliver,
  type DeliveryJob,
  type DeliveryRow,
  type DeliveryStatus,
  type DeliveryStore,
  missingMappings,
  type RemoteAdapter,
  type RemoteDocument,
} from "./accounting_delivery.ts";

const job = (over: Partial<DeliveryJob> = {}): DeliveryJob => ({
  connectionId: "c-1",
  documentKind: "invoice",
  documentId: "d-1",
  eventDate: "2026-03-02",
  documentNumber: "F-2026-0007",
  periodFrom: "2026-01-01",
  periodTo: "2026-12-31",
  payloadSha256: "a".repeat(64),
  needs: [
    { kind: "tax", key: "VAT|FR|taxed|20|2014" },
    { kind: "account", key: "revenue:standard" },
  ],
  ...over,
});

const maps: AccountingMap[] = [
  { kind: "tax", key: "VAT|FR|taxed|20|2014", remoteId: "", remoteCode: "FR_200" },
  { kind: "account", key: "revenue:standard", remoteId: "706", remoteCode: "706000" },
];

/** The store's rows by identity, with the SQL function's transitions. */
class MemoryStore implements DeliveryStore {
  rows = new Map<string, DeliveryRow & { sha: string; error: string }>();

  record(j: DeliveryJob, status: DeliveryStatus, remote?: RemoteDocument, error = "") {
    const identity = `${j.connectionId}:${j.documentKind}:${j.documentId}:${j.eventDate}`;
    const held = this.rows.get(identity);
    if (!held) {
      const row = {
        status: status === "acknowledged" ? "sent" as const : status,
        idempotency_key: `key-${identity}`,
        remote_id: "",
        outcome: "created" as const,
        sha: j.payloadSha256,
        error,
      };
      this.rows.set(identity, row);
      if (status !== "acknowledged") return Promise.resolve({ ...row });
    }
    const row = this.rows.get(identity)!;
    if (row.status === "acknowledged") {
      if (row.sha === j.payloadSha256 && (!remote || remote.id === row.remote_id)) {
        return Promise.resolve({ ...row, outcome: "unchanged" as const });
      }
      if (row.sha !== j.payloadSha256) return Promise.reject(new Error("needs a correction"));
    }
    if (status === "generated") return Promise.resolve({ ...row, outcome: "existing" as const });
    let next = status;
    let outcome: DeliveryRow["outcome"] = "updated";
    if (remote && row.remote_id && remote.id !== row.remote_id) {
      next = "conflict";
      outcome = "conflict";
    }
    row.status = next;
    row.error = next === "conflict" || next === "failed" ? error : "";
    if (next !== "conflict" && remote) {
      if (next === "acknowledged" || remote.state === "draft") row.remote_id = remote.id;
      if (remote.version) row.remote_version = remote.version;
    }
    return Promise.resolve({ ...row, outcome });
  }
}

/** A target holding documents by idempotency key. [timeoutAfterCreate]
 * makes the next create land remotely and answer nothing. */
class FakeTarget implements RemoteAdapter {
  held = new Map<string, RemoteDocument[]>();
  creates = 0;
  readbacks = 0;
  timeoutAfterCreate = false;
  refuse = "";
  next = 1;

  readback(key: string) {
    this.readbacks++;
    return Promise.resolve(this.held.get(key) ?? []);
  }

  create(key: string) {
    this.creates++;
    if (this.refuse) return Promise.resolve({ ok: false as const, unknown: false, detail: this.refuse });
    const doc = { id: `R-${this.next++}`, number: "F-2026-0007", matches: true };
    this.held.set(key, [...(this.held.get(key) ?? []), doc]);
    if (this.timeoutAfterCreate) {
      this.timeoutAfterCreate = false;
      return Promise.resolve({ ok: false as const, unknown: true, detail: "timeout" });
    }
    return Promise.resolve({ ok: true as const, remote: doc });
  }
}

Deno.test("a document is created once; a re-run is a no-op with no new remote id", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  const first = await deliver(job(), maps, store, target);
  assertEquals(first.status, "acknowledged");
  const again = await deliver(job(), maps, store, target);
  assertEquals(again.status, "unchanged");
  assertEquals(target.creates, 1);
  assertEquals(target.held.get("key-c-1:invoice:d-1:2026-03-02")!.length, 1);
});

Deno.test("a timeout after send is resolved by readback, never by a second create", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  target.timeoutAfterCreate = true;
  const lost = await deliver(job(), maps, store, target);
  assertEquals(lost.status, "conflict");
  const retried = await deliver(job(), maps, store, target);
  assertEquals(retried.status, "acknowledged");
  assertEquals(target.creates, 1, "the retry read back instead of creating");
  assertEquals(target.readbacks, 1);
  assertEquals(target.held.get("key-c-1:invoice:d-1:2026-03-02")!.map((d) => d.id), ["R-1"]);
});

Deno.test("a readback that disagrees leaves a conflict and creates nothing", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  target.timeoutAfterCreate = true;
  await deliver(job(), maps, store, target);
  target.held.set("key-c-1:invoice:d-1:2026-03-02", [{ id: "R-1", matches: false }]);
  const retried = await deliver(job(), maps, store, target);
  assertEquals(retried.status, "conflict");
  assertEquals(target.creates, 1);
  const row = [...store.rows.values()][0];
  assertEquals(row.status, "conflict");
  assertEquals(row.error, "the target's document R-1 differs from this one");
});

Deno.test("two remote documents for one delivery are a conflict", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  target.timeoutAfterCreate = true;
  await deliver(job(), maps, store, target);
  target.held.set("key-c-1:invoice:d-1:2026-03-02", [
    { id: "R-1", matches: true },
    { id: "R-2", matches: true },
  ]);
  assertEquals((await deliver(job(), maps, store, target)).status, "conflict");
  assertEquals(target.creates, 1);
});

Deno.test("an unmapped tax key blocks with the key named and sends nothing", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  const result = await deliver(
    job({ needs: [{ kind: "tax", key: "VAT|FR|taxed|5.5|2014" }] }),
    maps,
    store,
    target,
  );
  assertEquals(result, { status: "blocked", missing: ["tax VAT|FR|taxed|5.5|2014"] });
  assertEquals(target.creates + target.readbacks, 0);
  const row = [...store.rows.values()][0];
  assertEquals(row.status, "failed");
  assertEquals(row.error, "unmapped: tax VAT|FR|taxed|5.5|2014");
});

Deno.test("a blocked delivery whose send had no answer stays a conflict", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  target.timeoutAfterCreate = true;
  await deliver(job(), maps, store, target);
  await deliver(job(), [], store, target);
  assertEquals([...store.rows.values()][0].status, "conflict");
  assertEquals(target.readbacks, 0);
});

Deno.test("a refusal fails with the target's words; the next run creates again", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  target.refuse = "422 invalid vat_rate";
  assertEquals((await deliver(job(), maps, store, target)).status, "failed");
  assertEquals([...store.rows.values()][0].error, "422 invalid vat_rate");
  target.refuse = "";
  assertEquals((await deliver(job(), maps, store, target)).status, "acknowledged");
  // Prepared before, it is read back first (another run may have sent it);
  // nothing is found, so it is created once.
  assertEquals(target.readbacks, 1);
  assertEquals(target.creates, 2);
});

Deno.test("an acknowledged document with another content is refused, not created", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  await deliver(job(), maps, store, target);
  await assertRejects(() => deliver(job({ payloadSha256: "b".repeat(64) }), maps, store, target));
  assertEquals(target.creates, 1);
});

Deno.test("a mapping without a remote id or code does not count", () => {
  assertEquals(
    missingMappings(
      [{ kind: "party", key: "member:1" }, { kind: "party", key: "member:1" }],
      [{ kind: "party", key: "member:1", remoteId: "", remoteCode: "" }],
    ),
    ["party member:1"],
  );
});

Deno.test("the database store sends every field and throws on a refusal", async () => {
  const calls: Record<string, unknown>[] = [];
  const ok = databaseStore({
    rpc: (fn, args) => {
      calls.push({ fn, ...args });
      return Promise.resolve({ data: { status: "sent", idempotency_key: "k", remote_id: "", outcome: "created" }, error: null });
    },
  });
  await ok.record(job(), "acknowledged", { id: "R-9", number: "N", matches: true });
  assertEquals(calls[0].fn, "record_accounting_delivery");
  assertEquals(calls[0].p_status, "acknowledged");
  assertEquals(calls[0].p_remote, { id: "R-9", number: "N", version: "", state: "" });
  const refused = databaseStore({ rpc: () => Promise.resolve({ data: null, error: { code: "23514" } }) });
  await assertRejects(() => refused.record(job(), "sent"));
});

Deno.test("a create the target made something else, or that collides, is a conflict and never acknowledged", async () => {
  const differs: RemoteAdapter = {
    readback: () => Promise.resolve([]),
    create: () =>
      Promise.resolve({ ok: true as const, remote: { id: "R-9", matches: false, difference: "tax 14.99" } }),
  };
  const a = new MemoryStore();
  assertEquals((await deliver(job(), maps, a, differs)).status, "conflict");
  assertEquals([...a.rows.values()][0].error, "the target's document R-9 differs from this one: tax 14.99");
  const collides: RemoteAdapter = {
    readback: () => Promise.resolve([]),
    create: () => Promise.resolve({ ok: false as const, unknown: false, conflict: true, detail: "holds F-1 (7)" }),
  };
  const b = new MemoryStore();
  assertEquals((await deliver(job(), maps, b, collides)).status, "conflict");
  assertEquals([...b.rows.values()][0].error, "holds F-1 (7)");
});

Deno.test("a delivery prepared by another run is read back before any create", async () => {
  const store = new MemoryStore();
  const target = new FakeTarget();
  // Another run prepared it and sent it, and is still waiting for its answer.
  await store.record(job(), "generated");
  target.held.set([...store.rows.values()][0].idempotency_key, [{ id: "R-1", matches: true }]);
  assertEquals((await deliver(job(), maps, store, target)).status, "acknowledged");
  assertEquals(target.creates, 0);
});

Deno.test("a delivery another run is still sending stops: no readback, no create, no record", async () => {
  const records: DeliveryStatus[] = [];
  const store: DeliveryStore = {
    record: (_j, status) => {
      records.push(status);
      return Promise.resolve({ status: "sent", idempotency_key: "k", remote_id: "", outcome: "in_flight" });
    },
  };
  const target = new FakeTarget();
  const result = await deliver(job(), maps, store, target);
  assertEquals(result.status, "in_flight");
  assertEquals(records, ["generated"]);
  assertEquals([target.readbacks, target.creates], [0, 0]);
});

Deno.test("the database store tells the log how long a run may take", async () => {
  const calls: Record<string, unknown>[] = [];
  const row = { status: "sent", idempotency_key: "k", remote_id: "", outcome: "created" };
  const db = { rpc: (_fn: string, args: Record<string, unknown>) => (calls.push(args), Promise.resolve({ data: row, error: null })) };
  await databaseStore(db, { inFlightSeconds: 400 }).record(job(), "generated");
  await databaseStore(db).record(job(), "generated");
  assertEquals(calls[0].p_in_flight_seconds, 400);
  assertEquals(calls[1].p_in_flight_seconds, 0);
});

/** A target that creates drafts and posts them as their own operation
 * (#2374). [postAnswer] decides the next post: done, refused, or done with
 * no answer. */
class DraftTarget implements RemoteAdapter {
  held: RemoteDocument[] = [];
  creates = 0;
  posts = 0;
  postAnswer: "posted" | "refused" | "lost" = "posted";

  readback() {
    return Promise.resolve(this.held.map((d) => ({ ...d })));
  }

  create() {
    this.creates++;
    const draft: RemoteDocument = { id: "R-1", version: "v1", state: "draft", matches: true };
    this.held = [draft];
    return Promise.resolve({ ok: true as const, remote: { ...draft } });
  }

  post(draft: RemoteDocument) {
    this.posts++;
    if (this.postAnswer === "refused") {
      return Promise.resolve({ ok: false as const, unknown: false, detail: "403 posting is not permitted" });
    }
    const posted: RemoteDocument = { ...draft, number: "103001", version: "v2", state: "posted" };
    this.held = [posted];
    if (this.postAnswer === "lost") return Promise.resolve({ ok: false as const, unknown: true, detail: "timeout" });
    return Promise.resolve({ ok: true as const, remote: posted });
  }
}

Deno.test("a draft is recorded before it is posted, and only the posted document acknowledges", async () => {
  const store = new MemoryStore();
  const target = new DraftTarget();
  const result = await deliver(job(), maps, store, target);
  assertEquals(result.status, "acknowledged");
  assertEquals([target.creates, target.posts], [1, 1]);
  const row = [...store.rows.values()][0];
  assertEquals([row.status, row.remote_id, row.remote_version], ["acknowledged", "R-1", "v2"]);
});

Deno.test("a refused post leaves the draft sent, never acknowledged; the next run posts the same draft", async () => {
  const store = new MemoryStore();
  const target = new DraftTarget();
  target.postAnswer = "refused";
  const refused = await deliver(job(), maps, store, target);
  assertEquals(refused.status, "sent");
  assertEquals(refused.status === "sent" && refused.detail, "not posted: 403 posting is not permitted");
  assertEquals([...store.rows.values()][0].status, "sent");
  target.postAnswer = "posted";
  assertEquals((await deliver(job(), maps, store, target)).status, "acknowledged");
  assertEquals([target.creates, target.posts], [1, 2]);
});

Deno.test("a post with no answer is read back: posted, it acknowledges, and nothing is posted or created again", async () => {
  const store = new MemoryStore();
  const target = new DraftTarget();
  target.postAnswer = "lost";
  const lost = await deliver(job(), maps, store, target);
  assertEquals(lost.status, "conflict");
  assertEquals([...store.rows.values()][0].error, "no answer after post: timeout");
  assertEquals((await deliver(job(), maps, store, target)).status, "acknowledged");
  assertEquals([target.creates, target.posts], [1, 1]);
});

Deno.test("a draft changed in the target since it was delivered is a conflict, never posted", async () => {
  const store = new MemoryStore();
  const target = new DraftTarget();
  target.postAnswer = "refused";
  await deliver(job(), maps, store, target);
  target.held = [{ ...target.held[0], version: "v9" }];
  target.postAnswer = "posted";
  const stale = await deliver(job(), maps, store, target);
  assertEquals(stale.status, "conflict");
  assertEquals(
    [...store.rows.values()][0].error,
    "the target's draft R-1 changed since it was delivered (version v1, now v9)",
  );
  assertEquals(target.posts, 1);
});
