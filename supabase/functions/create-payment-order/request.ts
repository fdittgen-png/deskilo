// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the validated payment-order request. Parsing is pure: the
// workspace's currency is an argument, and what comes back is either a
// typed request or the exact refusal the handler answers with.

import { isProvider } from "./config.ts";
import type { Provider } from "./types.ts";

/** #2014 B — the client's request id: a UUID, or absent (legacy). */
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** #3556 — the most invoices one payment names (a month's documents of
 * one business; the database refuses a claim it cannot settle). */
export const MAX_CLAIMED_INVOICES = 100;

export interface PaymentOrderRequest {
  provider: Provider;
  memberId: string;
  amountCents: number;
  period: string;
  requestId: string | null;
  /** #3556 — the invoices this payment pays (its claim); null without. */
  invoiceIds: string[] | null;
  /** #4165 — a payment of standalone invoices: no month, a claim and a
   * request id required, opened by `open_standalone_payment_intent_v1`. */
  standalone: boolean;
}

export type ParsedRequest =
  | { ok: true; request: PaymentOrderRequest }
  | { ok: false; status: 400; body: Record<string, unknown> };

export function parsePaymentOrderRequest(
  body: Record<string, unknown>,
  workspaceCurrency: string,
): ParsedRequest {
  // #1138 — the currency is the WORKSPACE's, never the body's. A client
  // that names a cheaper currency would be charged in it and credited in
  // the workspace's; the ledger is currency-blind by design. A body that
  // disagrees is refused rather than corrected, so the mismatch is seen.
  const bodyCurrency = body.currency == null ? null : String(body.currency).toUpperCase();
  if (bodyCurrency && bodyCurrency !== workspaceCurrency) {
    return {
      ok: false,
      status: 400,
      body: { error: "currency_mismatch", workspace: workspaceCurrency, sent: bodyCurrency },
    };
  }
  const provider = body.provider;
  const memberId = body.member_id as string;
  const amountCents = body.amount_cents as number;
  const standalone = body.standalone === true;
  // #4165 — a standalone payment has no month: the database dates it.
  const period = standalone ? "" : body.period as string;
  const requestId = body.request_id == null ? null : String(body.request_id);
  // #3556 — absent: a payment of the account, as before. Present: a
  // non-empty list of invoice ids; the database checks whose and which.
  const rawIds = body.invoice_ids;
  const invoiceIds = rawIds == null ? null : rawIds;
  const idsValid = invoiceIds === null || (
    Array.isArray(invoiceIds) && invoiceIds.length > 0 &&
    invoiceIds.length <= MAX_CLAIMED_INVOICES &&
    invoiceIds.every((id) => typeof id === "string" && UUID_RE.test(id))
  );
  if (
    !isProvider(provider) || !memberId ||
    !Number.isInteger(amountCents) || amountCents <= 0 || (!standalone && !period) ||
    (requestId !== null && !UUID_RE.test(requestId)) || !idsValid ||
    (standalone && (requestId === null || invoiceIds === null))
  ) {
    return { ok: false, status: 400, body: { error: "invalid_request" } };
  }
  return {
    ok: true,
    request: {
      provider,
      memberId,
      amountCents,
      period,
      requestId,
      invoiceIds: invoiceIds as string[] | null,
      standalone,
    },
  };
}
