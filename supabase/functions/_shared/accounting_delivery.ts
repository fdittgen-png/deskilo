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
//   4. The create: an answer acknowledges (with the remote id), unless the
//      target made the document something else (its own tax, its own
//      total) or reports a document this one collides with: both are a
//      conflict. A refusal fails (with the target's words); no answer is a
//      conflict, resolved on the next run by step 3 and never by a second
//      create.
//   5. A target that creates a draft and posts it as its own operation
//      (#2374, Business Central): the draft's identity is recorded `sent`
//      first, then it is posted. Only the posted document acknowledges. A
//      refused post leaves the delivery `sent` with its draft, never
//      acknowledged; a post with no answer is a conflict, and the next run
//      reads the same remote document back: posted, it acknowledges; still
//      the same draft (the version the delivery holds), it is posted again;
//      a draft changed since it was delivered is a conflict, never posted.
//
// Pure: the store and the adapter are parameters (accounting_delivery_test.ts).

/** The most of a target's words a delivery or a connection keeps
 * (`accounting_connections.status_detail` holds 500). */
export const DETAIL_LENGTH = 500;

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
  /** How it differs when it does not match, in the target's terms. */
  difference?: string;
}

/** The delivery row as `record_accounting_delivery` answers it. */
export interface DeliveryRow {
  status: DeliveryStatus;
  idempotency_key: string;
  remote_id: string;
  outcome: "created" | "existing" | "unchanged" | "updated" | "conflict";
  /** The target's words or the kit's reason of a conflict or a failure. */
  error?: string;
  /** The remote document's version the delivery holds (an ETag), '' when
   * none was recorded. */
  remote_version?: string;
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
  | {
    ok: false;
    unknown: boolean;
    detail: string;
    /** The target holds something this delivery would collide with: a
     * person resolves it, nothing is created. */
    conflict?: boolean;
  };

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
  /** A target whose create makes a draft (`state: "draft"`): posts that
   * draft, as it was read at [draft]'s version, and answers the posted
   * document. Never creates. */
  post?(draft: RemoteDocument): Promise<CreateOutcome>;
}

export type DeliveryResult =
  | { status: "blocked"; missing: string[] }
  | { status: "unchanged" | "acknowledged" | "conflict" | "failed"; row: DeliveryRow }
  /** A draft the target holds and refused to post: the target's words. */
  | { status: "sent"; row: DeliveryRow; detail: string };

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
  // A delivery prepared before (by an earlier run, or by one running now)
  // may have been sent already: it is read back before any create.
  const readFirst = unknown || prepared.outcome === "existing";
  if (missing.length > 0) {
    await store.record(job, unknown ? "conflict" : "failed", undefined, `unmapped: ${missing.join(", ")}`);
    return { status: "blocked", missing };
  }
  const key = prepared.idempotency_key;
  if (readFirst) {
    const found = await adapter.readback(key, job);
    if (typeof found === "string") {
      const row = await store.record(job, "conflict", undefined, `readback failed: ${found}`);
      return { status: "conflict", row };
    }
    if (found.length === 1 && found[0].matches && found[0].state === "draft" && adapter.post) {
      const held = prepared.remote_version ?? "";
      if (held && found[0].version !== held) {
        const row = await store.record(
          job,
          "conflict",
          undefined,
          `the target's draft ${found[0].id} changed since it was delivered (version ${held}, now ${found[0].version || "none"})`,
        );
        return { status: "conflict", row };
      }
      return postDraft(job, store, adapter.post.bind(adapter), found[0]);
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
          : `the target's document ${found[0].id} differs from this one${
            found[0].difference ? `: ${found[0].difference}` : ""
          }`,
      );
      return { status: "conflict", row };
    }
  }
  await store.record(job, "sent");
  const created = await adapter.create(key, job, maps);
  if (created.ok && !created.remote.matches) {
    // Created, but the target made it something else (its own tax, its own
    // total): never acknowledged, a person compares the two.
    const row = await store.record(
      job,
      "conflict",
      undefined,
      `the target's document ${created.remote.id} differs from this one${
        created.remote.difference ? `: ${created.remote.difference}` : ""
      }`,
    );
    return { status: "conflict", row };
  }
  if (created.ok && created.remote.state === "draft" && adapter.post) {
    await store.record(job, "sent", created.remote);
    return postDraft(job, store, adapter.post.bind(adapter), created.remote);
  }
  if (created.ok) {
    const row = await store.record(job, "acknowledged", created.remote);
    return { status: row.status === "conflict" ? "conflict" : "acknowledged", row };
  }
  if (created.conflict) {
    const row = await store.record(job, "conflict", undefined, created.detail);
    return { status: "conflict", row };
  }
  if (created.unknown) {
    const row = await store.record(job, "conflict", undefined, `no answer after send: ${created.detail}`);
    return { status: "conflict", row };
  }
  const row = await store.record(job, "failed", undefined, created.detail);
  return { status: "failed", row };
}

/** Step 5: posts [draft], whose identity is recorded. */
async function postDraft(
  job: DeliveryJob,
  store: DeliveryStore,
  post: (draft: RemoteDocument) => Promise<CreateOutcome>,
  draft: RemoteDocument,
): Promise<DeliveryResult> {
  const posted = await post(draft);
  if (posted.ok && posted.remote.matches && posted.remote.state !== "draft") {
    const row = await store.record(job, "acknowledged", posted.remote);
    return { status: row.status === "conflict" ? "conflict" : "acknowledged", row };
  }
  if (posted.ok) {
    const row = await store.record(
      job,
      "conflict",
      undefined,
      `the target's document ${posted.remote.id} differs from this one after posting${
        posted.remote.difference ? `: ${posted.remote.difference}` : ""
      }`,
    );
    return { status: "conflict", row };
  }
  if (posted.conflict) {
    const row = await store.record(job, "conflict", undefined, posted.detail);
    return { status: "conflict", row };
  }
  if (posted.unknown) {
    const row = await store.record(job, "conflict", undefined, `no answer after post: ${posted.detail}`);
    return { status: "conflict", row };
  }
  // Refused: the draft stays the delivery's, and the next run posts it.
  const row = await store.record(job, "sent", draft);
  return { status: "sent", row, detail: `not posted: ${posted.detail}` };
}

/** The delivery log refused a record: nothing more is sent for it. [code]
 * is the database's (23514: the document was acknowledged with another
 * content and needs a correction, not a second delivery). */
export class DeliveryNotRecorded extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = "DeliveryNotRecorded";
  }
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
      if (failed) {
        const e = failed as { code?: unknown; message?: unknown };
        throw new DeliveryNotRecorded(String(e.code ?? ""), String(e.message ?? JSON.stringify(failed)));
      }
      return data as DeliveryRow;
    },
  };
}
