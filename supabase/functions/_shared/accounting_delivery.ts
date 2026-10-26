// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The delivery state machine every accounting adapter runs one document
// through. The adapter knows its vendor (how to read a document back,
// how to create one); this module knows the order, which is the
// guarantee:
//
//   1. The delivery is prepared: `record_accounting_delivery` stores the
//      stable identity and its idempotency key BEFORE anything is sent. An
//      acknowledged delivery with the same digest ends here: a re-run is a
//      no-op and creates no remote id.
//   2. Every mapping key the payload needs is looked up. One missing
//      blocks the delivery with the key named; nothing is sent and no
//      default code is ever put in its place.
//   3. A delivery whose last send has no known outcome (`sent`,
//      `conflict`) is read back by its idempotency key first. Exactly one
//      matching remote document acknowledges it; a remote document that
//      disagrees, or more than one, is a conflict for a person to resolve.
//      Only when nothing is found is the document created again.
//   4. The create: an answer acknowledges (with the remote id), a refusal
//      fails (with the target's words), no answer is a conflict, resolved
//      on the next run by step 3 and never by a second create.
//
// Pure: the store and the adapter are parameters (accounting_delivery_test.ts).

export type MapKind = "account" | "tax" | "party" | "item";

/** One mapping of a connection: a key of the app, named on the target. */
export interface AccountingMap {
  kind: MapKind;
  key: string;
  remoteId: string;
  remoteCode: string;
}

/** A mapping key a payload needs. */
export interface MapNeed {
  kind: MapKind;
  key: string;
}

/** One document event to deliver to one connection. */
export interface DeliveryJob {
  connectionId: string;
  documentKind: string;
  documentId: string;
  /** YYYY-MM-DD: the event's day, part of the identity. */
  eventDate: string;
  documentNumber: string;
  periodFrom: string;
  periodTo: string;
  /** The sha256 of the payload the adapter builds, lowercase hex. */
  payloadSha256: string;
  needs: MapNeed[];
}

export type DeliveryStatus =
  | "generated"
  | "sent"
  | "acknowledged"
  | "conflict"
  | "failed";

/** A remote document as a target answers it. */
export interface RemoteDocument {
  id: string;
  number?: string;
  version?: string;
  state?: "draft" | "posted";
  /** Whether the remote content is the payload's (amount, number, lines). */
  matches: boolean;
}

/** The delivery row as `record_accounting_delivery` answers it. */
export interface DeliveryRow {
  status: DeliveryStatus;
  idempotency_key: string;
  remote_id: string;
  outcome: "created" | "existing" | "unchanged" | "updated" | "conflict";
}

export interface DeliveryStore {
  record(
    job: DeliveryJob,
    status: DeliveryStatus,
    remote?: RemoteDocument,
    error?: string,
  ): Promise<DeliveryRow>;
}

export type CreateOutcome =
  | { ok: true; remote: RemoteDocument }
  | { ok: false; unknown: boolean; detail: string };

export interface RemoteAdapter {
  /** The remote documents that carry [idempotencyKey] (or the target's
   * natural key for it); a string when the target could not be asked. */
  readback(
    idempotencyKey: string,
    job: DeliveryJob,
  ): Promise<RemoteDocument[] | string>;
  create(
    idempotencyKey: string,
    job: DeliveryJob,
    maps: AccountingMap[],
  ): Promise<CreateOutcome>;
}

export type DeliveryResult =
  | { status: "blocked"; missing: string[] }
  | { status: "unchanged" | "acknowledged" | "conflict" | "failed"; row: DeliveryRow };

/** The needs of [needs] no mapping of [maps] answers, as `kind key`. */
export function missingMappings(
  needs: MapNeed[],
  maps: AccountingMap[],
): string[] {
  const held = new Set(
    maps
      .filter((m) => m.remoteId !== "" || m.remoteCode !== "")
      .map((m) => `${m.kind} ${m.key}`),
  );
  return [...new Set(needs.map((n) => `${n.kind} ${n.key}`))]
    .filter((n) => !held.has(n))
    .sort();
}

export async function deliver(
  job: DeliveryJob,
  maps: AccountingMap[],
  store: DeliveryStore,
  adapter: RemoteAdapter,
): Promise<DeliveryResult> {
  const prepared = await store.record(job, "generated");
  if (prepared.outcome === "unchanged") {
    return { status: "unchanged", row: prepared };
  }
  const missing = missingMappings(job.needs, maps);
  // A send whose outcome is unknown stays a conflict while it is blocked:
  // recording it failed would let the next run create without a readback.
  const unknown = prepared.status === "sent" || prepared.status === "conflict";
  if (missing.length > 0) {
    await store.record(job, unknown ? "conflict" : "failed", undefined, `unmapped: ${missing.join(", ")}`);
    return { status: "blocked", missing };
  }
  const key = prepared.idempotency_key;
  if (unknown) {
    const found = await adapter.readback(key, job);
    if (typeof found === "string") {
      const row = await store.record(job, "conflict", undefined, `readback failed: ${found}`);
      return { status: "conflict", row };
    }
    if (found.length === 1 && found[0].matches) {
      const row = await store.record(job, "acknowledged", found[0]);
      return { status: row.status === "conflict" ? "conflict" : "acknowledged", row };
    }
    if (found.length > 0) {
      const row = await store.record(
        job,
        "conflict",
        undefined,
        found.length > 1
          ? `the target holds ${found.length} documents for this delivery`
          : `the target's document ${found[0].id} differs from this one`,
      );
      return { status: "conflict", row };
    }
  }
  await store.record(job, "sent");
  const created = await adapter.create(key, job, maps);
  if (created.ok) {
    const row = await store.record(job, "acknowledged", created.remote);
    return { status: row.status === "conflict" ? "conflict" : "acknowledged", row };
  }
  if (created.unknown) {
    const row = await store.record(job, "conflict", undefined, `no answer after send: ${created.detail}`);
    return { status: "conflict", row };
  }
  const row = await store.record(job, "failed", undefined, created.detail);
  return { status: "failed", row };
}

/** What the store asks of a Supabase client with the service role. */
export type ServiceDb = {
  rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: unknown }>;
};

/** The store over `record_accounting_delivery`. A refused record throws:
 * a delivery that cannot be recorded is never sent. */
export function databaseStore(db: ServiceDb): DeliveryStore {
  return {
    async record(job, status, remote, error) {
      const { data, error: failed } = await db.rpc("record_accounting_delivery", {
        p_connection_id: job.connectionId,
        p_document_kind: job.documentKind,
        p_document_id: job.documentId,
        p_event_date: job.eventDate,
        p_document_number: job.documentNumber,
        p_period_from: job.periodFrom,
        p_period_to: job.periodTo,
        p_payload_sha256: job.payloadSha256,
        p_status: status,
        p_remote: remote
          ? { id: remote.id, number: remote.number ?? "", version: remote.version ?? "", state: remote.state ?? "" }
          : {},
        p_error: error ?? "",
      });
      if (failed) throw new Error(`the delivery was not recorded: ${JSON.stringify(failed)}`);
      return data as DeliveryRow;
    },
  };
}
