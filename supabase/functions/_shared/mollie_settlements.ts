// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- reading a Mollie account's settlements, shared by the on-demand
// fetch (mollie-settlements) and the schedule (settlement-poll).
//
// A read is bounded: at most `maxPages` pages of 50 from a cursor, each call
// under `callTimeoutMs`. Mollie lists settlements newest first and continues
// a list through `_links.next` (`from=<id>`, docs.mollie.com "Pagination");
// only that cursor is kept, never the provider's whole URL, so a stored
// continuation cannot point a later read anywhere else.
//
// The counts are what the recorder DECIDED (`record_provider_settlement_v1`,
// 0720): new, unchanged, refused (kept for review) -- never the number of
// calls. An open or pending settlement is not recorded yet (`pending`); one
// that cannot be read is `rejected`. A failure stops the read where it
// happened: the continuation is the cursor of the page that failed, so the
// pages already recorded stay recorded and the failed one is read again.
//
// spec: docs.mollie.com "List settlements" -- field names as documented, not
// verified against a live account.

import { toMinor } from "./money.ts";

/** One page of the list, as Mollie pages it. */
export const PAGE_SIZE = 50;

type Row = Record<string, unknown>;

export type Cost = {
  period: string;
  method: string;
  description: string;
  cost_count: number;
  amount_net_cents: number;
  currency: string;
};

export type Settlement = {
  id: string;
  cents: number;
  currency: string;
  arrival: string | null;
  status: "paid" | "failed";
  costs: Array<Cost>;
};

/** What `record_provider_settlement_v1` takes of one Mollie settlement, or
 * null when it is not a paid or failed one (open, pending) or malformed.
 * Each cost keeps the currency Mollie gave it (the settlement's when it
 * names none); one in another currency is refused by the recorder and kept
 * for review, never relabelled here. */
export function settlementOf(s: Row): Settlement | null {
  const status = s.status === "paidout" ? "paid" : s.status === "failed" ? "failed" : null;
  const amount = (s.amount ?? {}) as Row;
  const currency = String(amount.currency ?? "").toUpperCase();
  const cents = toMinor(amount.value as string | undefined, currency);
  const id = typeof s.id === "string" ? s.id : "";
  if (!status || !id || !currency || cents === null) return null;
  const settledAt = typeof s.settledAt === "string" ? s.settledAt : "";
  const costs: Array<Cost> = [];
  for (const [year, months] of Object.entries((s.periods ?? {}) as Row)) {
    for (const [month, period] of Object.entries((months ?? {}) as Row)) {
      for (const c of ((period as Row).costs ?? []) as Row[]) {
        const net = (c.amountNet ?? {}) as Row;
        const costCurrency = String(net.currency ?? currency).toUpperCase();
        const cost = toMinor(net.value as string | undefined, costCurrency);
        if (cost === null || !Number.isInteger(c.count)) return null;
        costs.push({
          period: `${year}-${month}`,
          method: typeof c.method === "string" ? c.method : "",
          description: typeof c.description === "string" ? c.description : "",
          cost_count: c.count as number,
          amount_net_cents: cost,
          currency: costCurrency,
        });
      }
    }
  }
  return { id, cents, currency, arrival: /^\d{4}-\d{2}-\d{2}/.test(settledAt) ? settledAt.slice(0, 10) : null, status, costs };
}

/** Not paid out or failed yet: Mollie is still collecting it. */
const NOT_YET = new Set(["open", "pending"]);

/** What the recorder answered for one settlement. */
export type Recorded =
  | { outcome: "new" | "unchanged" }
  | { outcome: "refused"; reason: string }
  | { error: string };

/** Why a read stopped before its end. `refused`: Mollie answered 4xx (not
 * 429), permanent until someone changes the key. `unreachable`: the
 * network, a timeout, 429 or 5xx, retried. `record_failed`: the database
 * did not answer the recorder, retried. */
export type ScanFailure = {
  kind: "refused" | "unreachable" | "record_failed";
  status?: number;
  settlement?: string;
};

export type ScanResult = {
  new: number;
  unchanged: number;
  pending: number;
  rejected: number;
  refused: Array<{ settlement: string; reason: string }>;
  pages: number;
  /** The list was read to its end, or (with `stopWhenKnown`) to a page the
   * recorder already held whole. */
  complete: boolean;
  /** Where the next read starts: the cursor of the page not read yet, or of
   * the page that failed; null when complete. */
  continuation: string | null;
  failure: ScanFailure | null;
};

export type ScanOptions = {
  fetch: typeof fetch;
  base: string;
  key: string;
  /** The cursor to start at; null reads from the newest. */
  from: string | null;
  maxPages: number;
  callTimeoutMs: number;
  /** Stop at a page whose every settlement the recorder already held
   * unchanged: the older ones were read before. Off for a first full read. */
  stopWhenKnown: boolean;
  record: (one: Settlement) => Promise<Recorded>;
};

/** The `from` cursor of Mollie's next link, or null at the end. */
export function cursorOf(next: unknown): string | null {
  const href = ((next ?? {}) as Row).href;
  if (typeof href !== "string" || !href) return null;
  try {
    return new URL(href).searchParams.get("from");
  } catch {
    return null;
  }
}

const pageUrl = (base: string, from: string | null) =>
  `${base}/v2/settlements?limit=${PAGE_SIZE}` + (from ? `&from=${encodeURIComponent(from)}` : "");

/** Reads settlements from `from`, at most `maxPages` pages, recording each
 * paid or failed one. Never throws: a failure is in the result. */
export async function scanSettlements(o: ScanOptions): Promise<ScanResult> {
  const r: ScanResult = {
    new: 0,
    unchanged: 0,
    pending: 0,
    rejected: 0,
    refused: [],
    pages: 0,
    complete: false,
    continuation: o.from,
    failure: null,
  };
  let from = o.from;
  while (r.pages < o.maxPages) {
    let res: Response;
    let list: Row;
    try {
      res = await o.fetch(pageUrl(o.base, from), {
        headers: { Authorization: `Bearer ${o.key}` },
        signal: AbortSignal.timeout(o.callTimeoutMs),
      });
      if (res.status >= 400 && res.status < 500 && res.status !== 429) {
        console.error("mollie settlements refused", { status: res.status });
        r.failure = { kind: "refused", status: res.status };
        return r;
      }
      if (!res.ok) {
        r.failure = { kind: "unreachable", status: res.status };
        return r;
      }
      list = (await res.json()) as Row;
    } catch (e) {
      console.error("mollie settlements read failed", String(e));
      r.failure = { kind: "unreachable" };
      return r;
    }
    const settlements = ((list._embedded as Row | undefined)?.settlements ?? []) as Row[];
    let known = settlements.length > 0;
    for (const s of settlements) {
      const one = settlementOf(s);
      if (!one) {
        known = false;
        if (NOT_YET.has(String(s.status))) r.pending++;
        else r.rejected++;
        continue;
      }
      const recorded = await o.record(one);
      if ("error" in recorded) {
        console.error("mollie settlement record failed", recorded.error);
        r.failure = { kind: "record_failed", settlement: one.id };
        return r;
      }
      if (recorded.outcome === "unchanged") {
        r.unchanged++;
      } else {
        known = false;
        if (recorded.outcome === "refused") r.refused.push({ settlement: one.id, reason: recorded.reason });
        else r.new++;
      }
    }
    r.pages++;
    from = cursorOf((list._links as Row | undefined)?.next);
    r.continuation = from;
    if (!from || (o.stopWhenKnown && known)) {
      r.complete = true;
      r.continuation = null;
      return r;
    }
  }
  return r;
}

/** The recorder, through a database client with the service role. */
export function recorderOf(
  db: { rpc: (fn: string, args: Row) => PromiseLike<{ data: unknown; error: unknown }> },
  workspaceId: string,
): (one: Settlement) => Promise<Recorded> {
  return async (one) => {
    const recorded = await db.rpc("record_provider_settlement_v1", {
      p_workspace_id: workspaceId,
      p_provider: "mollie",
      p_settlement_id: one.id,
      p_amount_cents: one.cents,
      p_currency: one.currency,
      p_arrival_date: one.arrival,
      p_status: one.status,
      p_costs: one.costs,
    });
    if (recorded.error) return { error: String((recorded.error as Row).message ?? recorded.error) };
    const answer = (recorded.data ?? {}) as Row;
    if (answer.outcome === "unchanged") return { outcome: "unchanged" };
    if (answer.outcome === "refused") return { outcome: "refused", reason: String(answer.reason ?? "") };
    return { outcome: "new" };
  };
}
