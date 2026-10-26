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
    if (next === "acknowledged" && remote) row.remote_id = remote.id;
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
  assertEquals(target.readbacks, 0, "a refused create left nothing to read back");
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
