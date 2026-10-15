// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the validated payment-order request. Parsing is pure: the
// workspace's currency is an argument, and what comes back is either a
// typed request or the exact refusal the handler answers with.

import { isProvider } from "./config.ts";
import type { Provider } from "./types.ts";

/** #2014 B — the client's request id: a UUID, or absent (legacy). */
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface PaymentOrderRequest {
  provider: Provider;
  memberId: string;
  amountCents: number;
  period: string;
  requestId: string | null;
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
  const period = body.period as string;
  const requestId = body.request_id == null ? null : String(body.request_id);
  if (
    !isProvider(provider) || !memberId ||
    !Number.isInteger(amountCents) || amountCents <= 0 || !period ||
    (requestId !== null && !UUID_RE.test(requestId))
  ) {
    return { ok: false, status: 400, body: { error: "invalid_request" } };
  }
  return { ok: true, request: { provider, memberId, amountCents, period, requestId } };
}
