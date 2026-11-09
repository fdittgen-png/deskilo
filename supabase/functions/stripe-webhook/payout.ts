// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 -- a Stripe payout reaches the books: `payout.paid` / `.failed` /
// `.canceled` records the payout and links the payments its balance
// transactions carry (`record_provider_payout_v1`, 0687), so the posting engine
// can move the clearing account to the bank (0698).
//
// A payout event names no checkout session, so the workspace is the one whose
// OWN webhook secret signed it (the same per-workspace secrets as a payment's
// event, tried in turn; an event only the installation's secret signs belongs
// to no workspace and is acknowledged unread). The payout's balance
// transactions are read with that workspace's key; their ids are the
// `provider_transaction_id` recorded with each payment's fee.
//
// spec: docs.stripe.com "Payout object" (`amount`, `currency`, `arrival_date`,
// `status`) and "List all balance transactions" (`payout`, `type`,
// `has_more`/`starting_after`) -- field names as documented, not verified
// against a live account.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

/** The payout statuses the books record, by event type. */
const STATUS: Record<string, string> = {
  "payout.paid": "paid",
  "payout.failed": "failed",
  "payout.canceled": "canceled",
};

/** The most pages of a payout's balance transactions read: a payout of more
 * than 100 x this many payments is not recorded in one event. */
export const MAX_PAYOUT_PAGES = 20;

export interface PayoutDeps {
  admin: () => SupabaseClient;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
}

type Row = Record<string, unknown>;

/** Whether [type] is a payout event the books record. */
export const isPayoutEvent = (type: unknown): boolean =>
  typeof type === "string" && type in STATUS;

/** The day (UTC) of a Stripe epoch-seconds timestamp, or null. */
function dayOf(epochSeconds: unknown): string | null {
  return typeof epochSeconds === "number" && Number.isFinite(epochSeconds)
    ? new Date(epochSeconds * 1000).toISOString().slice(0, 10)
    : null;
}

/** The ids of every balance transaction the payout carried. A refused key
 * (4xx but 429) is permanent: null, the payout stays unrecorded. Throws on a
 * transient failure so Stripe redelivers. */
async function carriedTransactions(
  deps: PayoutDeps,
  key: string,
  payoutId: string,
): Promise<string[] | null> {
  const ids: string[] = [];
  let after = "";
  for (let page = 0; page < MAX_PAYOUT_PAGES; page++) {
    const url = `https://api.stripe.com/v1/balance_transactions?payout=${encodeURIComponent(payoutId)}&limit=100` +
      (after ? `&starting_after=${encodeURIComponent(after)}` : "");
    const res = await deps.fetch(url, { headers: { Authorization: `Bearer ${key}` } });
    if (res.status >= 400 && res.status < 500 && res.status !== 429) {
      console.error("stripe payout read refused", { status: res.status });
      return null;
    }
    if (!res.ok) throw new Error(`stripe payout read ${res.status}`);
    const body = (await res.json()) as Row;
    const data = (body.data ?? []) as Row[];
    for (const t of data) {
      if (typeof t.id === "string" && t.type !== "payout") ids.push(t.id);
    }
    if (body.has_more !== true || data.length === 0) return ids;
    after = String(data[data.length - 1].id);
  }
  throw new Error("stripe payout has more payments than one event reads");
}

/** Records the payout of [event]. [verify] says whether a secret signed the
 * event. Answers like the rest of the webhook: 2xx handled or not ours, 5xx
 * retry. */
export async function handlePayout(
  event: Row,
  verify: (secret: string) => Promise<boolean>,
  deps: PayoutDeps,
): Promise<Response> {
  const admin = deps.admin();
  const { data, error } = await admin
    .from("payment_credentials")
    .select("workspace_id, config")
    .eq("provider", "stripe");
  if (error) {
    console.error("stripe payout: credential lookup failed");
    return new Response("not_ready", { status: 500 });
  }
  let workspaceId = "";
  let key = "";
  for (const row of (data ?? []) as Array<{ workspace_id: string; config: Row | null }>) {
    const config = (row.config ?? {}) as Record<string, string>;
    if (config.webhook_secret && (await verify(config.webhook_secret))) {
      workspaceId = row.workspace_id;
      key = config.secret_key ?? "";
      break;
    }
  }
  if (!workspaceId) {
    // Not signed by any workspace's own secret: another account's event, or
    // the installation's secret, which names no workspace. Never an error for
    // Stripe to retry; nothing is recorded.
    console.log("stripe payout: no workspace signed it, ignoring");
    return new Response("ok", { status: 200 });
  }
  const payout = ((event.data as Row | undefined)?.object ?? {}) as Row;
  const payoutId = typeof payout.id === "string" ? payout.id : "";
  const status = STATUS[String(event.type)];
  const amount = payout.amount;
  const currency = String(payout.currency ?? "").toUpperCase();
  if (!payoutId || !Number.isSafeInteger(amount) || !currency) {
    console.error("stripe payout: malformed payout, ignoring");
    return new Response("ok", { status: 200 });
  }
  if (!key) {
    console.log("stripe payout: no API key for the workspace, ignoring");
    return new Response("ok", { status: 200 });
  }
  let transactions: string[] | null = [];
  try {
    // A failed or canceled payout carried nothing to the bank: no list needed.
    if (status === "paid") transactions = await carriedTransactions(deps, key, payoutId);
  } catch (e) {
    console.error("stripe payout read failed", String(e));
    return new Response("payout_read_failed", { status: 500 });
  }
  if (transactions === null) return new Response("ok", { status: 200 });
  const recorded = await admin.rpc("record_provider_payout_v1", {
    p_workspace_id: workspaceId,
    p_provider: "stripe",
    p_payout_id: payoutId,
    p_amount_cents: amount,
    p_currency: currency,
    p_arrival_date: dayOf(payout.arrival_date),
    p_status: status,
    p_transaction_ids: transactions,
  });
  if (recorded.error) {
    console.error("stripe payout record failed", recorded.error.message);
    return new Response("payout_record_failed", { status: 500 });
  }
  const answer = (recorded.data ?? {}) as Row;
  if (answer.reconciled === false) {
    // The nets of the payments linked do not add up to the payout: said, never
    // adjusted (the books keep both sides as they are).
    console.warn("stripe payout does not reconcile with its payments", {
      payout: payoutId,
      net: answer.net_cents,
      amount,
    });
  }
  return new Response("ok", { status: 200 });
}
