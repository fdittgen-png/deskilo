// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4126 -- what a provider says of an order left open, read with the
// business's own credentials, as a decision the reconciliation applies
// through the notifications' own paths: settle (exactly once), end, or leave
// while the provider still calls it pending. Anything else is "unreadable"
// with a reason word, and the attempt is left as it is: an attempt is never
// ended on silence.
import { mollieApi, paypalApi } from "../_shared/providers.ts";
import {
  paypalFeeOf,
  type ProviderFee,
  stripeFeeOf,
} from "../_shared/provider_settlement.ts";
import {
  approvedOrderMatches,
  captureApprovedOrder,
  paypalMatches,
} from "../_shared/paypal_capture.ts";
import { toMinor } from "../_shared/money.ts";
import { mismatch, reversalOf } from "../_shared/mollie_payment_rules.ts";

type Row = Record<string, unknown>;

/** An attempt as the claim hands it over. */
export type OpenIntent = {
  id: string;
  provider: string;
  order_id: string;
  amount_cents: number;
  currency: string;
  reference: string;
  /** A PayPal order past its longest lifetime: ended if PayPal no longer
   * knows it (payment_paypal_gone_after). */
  gone_may_end?: boolean;
  /** What this job last saw of the order (PayPal's status word) and under
   * which credentials (a fingerprint of the client id). */
  seen_state?: string | null;
  seen_client?: string | null;
  /** An approval is captured by the job only inside the provider's
   * lifetime (payment_open_lifetime). */
  may_capture?: boolean;
};

/** The reason words the record keeps (payment_reconciliation_finish_v1). */
export type UnreadableReason =
  | "unreachable"
  | "refused"
  | "not_configured"
  | "unknown_order"
  | "mismatch"
  | "unexpected_answer"
  | "record_failed"
  | "approved_not_captured";

export type Decision =
  /** [fee]: what the provider kept of it, recorded as the notification would. */
  | {
    kind: "settle";
    captureId: string;
    fee?: ProviderFee | null;
    feeFailed?: boolean;
  }
  | { kind: "end" }
  | { kind: "left" }
  | { kind: "unreadable"; reason: UnreadableReason };

export type ReadDeps = {
  fetch: typeof fetch;
  env: (name: string) => string | undefined;
  /** Whether this installation takes test payments (#3905). */
  allowTest: boolean;
  /** The longest one call to a provider may take. */
  timeoutMs: number;
  /** Told what the provider said of the order, and under which credentials. */
  observe?: (seen: { state: string; client: string }) => void;
  /** Whether the attempt is still open now: read just before a capture. */
  stillOpen?: () => Promise<boolean>;
};

/** A fingerprint of the credentials an order was read under: the client id
 * and its environment, never the secret. */
export async function clientFingerprint(
  clientId: string,
  env: string,
): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${clientId}|${env}`),
  );
  return [...new Uint8Array(digest)].slice(0, 16).map((b) =>
    b.toString(16).padStart(2, "0")
  ).join("");
}

const unreadable = (reason: UnreadableReason): Decision => ({
  kind: "unreadable",
  reason,
});

/** What an HTTP answer that is not a success means for the record. */
export function failureOf(status: number): Decision {
  if (status === 401 || status === 403) return unreadable("refused");
  if (status === 404) return unreadable("unknown_order");
  if (status === 408 || status === 429 || status >= 500) {
    return unreadable("unreachable");
  }
  return unreadable("unexpected_answer");
}

async function getJson(
  deps: ReadDeps,
  url: string,
  init: RequestInit,
): Promise<{ ok: true; body: Row } | { ok: false; decision: Decision }> {
  let res: Response;
  try {
    res = await deps.fetch(url, {
      ...init,
      signal: AbortSignal.timeout(deps.timeoutMs),
    });
  } catch {
    return { ok: false, decision: unreadable("unreachable") };
  }
  if (!res.ok) {
    await res.body?.cancel();
    return { ok: false, decision: failureOf(res.status) };
  }
  try {
    return { ok: true, body: (await res.json()) as Row };
  } catch {
    return { ok: false, decision: unreadable("unexpected_answer") };
  }
}

/** Stripe: the Checkout Session. Complete and paid settles; expired ends;
 * open, or complete with a payment still on its way, is left. */
export async function readStripe(
  intent: OpenIntent,
  cfg: Row,
  deps: ReadDeps,
): Promise<Decision> {
  const key = String(cfg.secret_key ?? deps.env("STRIPE_SECRET_KEY") ?? "");
  if (!key) return unreadable("not_configured");
  const base = deps.env("STRIPE_API_BASE") ?? "https://api.stripe.com";
  const read = await getJson(
    deps,
    `${base}/v1/checkout/sessions/${encodeURIComponent(intent.order_id)}`,
    {
      headers: { Authorization: `Bearer ${key}` },
    },
  );
  if (!read.ok) return read.decision;
  const session = read.body;
  if (session.id !== intent.order_id) return unreadable("unexpected_answer");
  if (session.livemode === false && !deps.allowTest) return { kind: "left" };
  if (session.status === "expired") return { kind: "end" };
  if (session.status !== "complete") return { kind: "left" };
  const paid = session.payment_status === "paid" ||
    session.payment_status === "no_payment_required";
  const piId = typeof session.payment_intent === "string"
    ? session.payment_intent
    : "";
  if (!piId) {
    // A session without a payment: nothing was charged, nothing to read.
    return paid
      ? settleStripe(intent, session, session.id as string)
      : { kind: "left" };
  }
  // The payment behind the session: a delayed method that failed, or money
  // that went back, shows only there.
  const pi = await getJson(
    deps,
    `${base}/v1/payment_intents/${
      encodeURIComponent(piId)
    }?expand[]=latest_charge.balance_transaction`,
    { headers: { Authorization: `Bearer ${key}` } },
  );
  if (!pi.ok) return pi.decision;
  const payment = pi.body;
  if (!paid) {
    return payment.status === "canceled" ||
        payment.status === "requires_payment_method"
      ? { kind: "end" }
      : { kind: "left" };
  }
  const charge = (payment.latest_charge ?? {}) as Row;
  if (
    charge.refunded === true || Number(charge.amount_refunded ?? 0) > 0 ||
    charge.disputed === true
  ) {
    // Paid, then refunded or disputed: for a person to look at, never a
    // plain payment.
    return unreadable("unexpected_answer");
  }
  const decided = settleStripe(intent, session, piId);
  return decided.kind === "settle"
    ? { ...decided, fee: stripeFeeOf(charge.balance_transaction) }
    : decided;
}

function settleStripe(
  intent: OpenIntent,
  session: Row,
  captureId: string,
): Decision {
  if (
    Number(session.amount_total) !== intent.amount_cents ||
    String(session.currency ?? "").toUpperCase() !==
      intent.currency.toUpperCase()
  ) {
    return unreadable("mismatch");
  }
  return { kind: "settle", captureId };
}

/** Mollie (and Wero through Mollie): the payment. Paid and matching settles;
 * failed, canceled or expired ends; open, pending or authorized is left. */
export async function readMollie(
  intent: OpenIntent,
  cfg: Row,
  deps: ReadDeps,
): Promise<Decision> {
  const key = String(cfg.api_key ?? deps.env("MOLLIE_API_KEY") ?? "");
  if (!key) return unreadable("not_configured");
  const read = await getJson(
    deps,
    `${mollieApi()}/v2/payments/${encodeURIComponent(intent.order_id)}`,
    {
      headers: { Authorization: `Bearer ${key}` },
    },
  );
  if (!read.ok) return read.decision;
  const payment = read.body;
  if (payment.id !== intent.order_id) return unreadable("unexpected_answer");
  const status = String(payment.status ?? "");
  if (["failed", "canceled", "expired"].includes(status)) {
    return { kind: "end" };
  }
  if (status !== "paid") return { kind: "left" };
  if (mismatch({ ...intent, workspace_id: "" }, payment, key, deps.allowTest)) {
    return unreadable("mismatch");
  }
  // A payment already charged back or refunded is for a person to look at.
  if (reversalOf(payment)) return unreadable("unexpected_answer");
  return { kind: "settle", captureId: intent.order_id };
}

/** PayPal: the order. Completed with a completed capture of the attempt's
 * amount settles; voided ends; created, approved or waiting on the payer is
 * left. */
export async function readPaypal(
  intent: OpenIntent,
  cfg: Row,
  deps: ReadDeps,
): Promise<Decision> {
  const clientId = String(cfg.client_id ?? deps.env("PAYPAL_CLIENT_ID") ?? "");
  const secret = String(cfg.secret ?? deps.env("PAYPAL_SECRET") ?? "");
  const env = String(cfg.env ?? deps.env("PAYPAL_ENV") ?? "sandbox");
  if (!clientId || !secret) return unreadable("not_configured");
  if (env !== "live" && !deps.allowTest) return { kind: "left" };
  let token: string;
  try {
    const res = await deps.fetch(`${paypalApi(env)}/v1/oauth2/token`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${clientId}:${secret}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials",
      signal: AbortSignal.timeout(deps.timeoutMs),
    });
    if (!res.ok) {
      await res.body?.cancel();
      return failureOf(res.status);
    }
    token = String(((await res.json()) as Row).access_token ?? "");
  } catch {
    return unreadable("unreachable");
  }
  if (!token) return unreadable("unexpected_answer");
  const read = await getJson(
    deps,
    `${paypalApi(env)}/v2/checkout/orders/${
      encodeURIComponent(intent.order_id)
    }`,
    {
      headers: { Authorization: `Bearer ${token}` },
    },
  );
  if (!read.ok) {
    // PayPal has no "expired" status: an order past its lifetime answers
    // not-found. A known order PayPal no longer knows, past the longest
    // lifetime an account may have, was never paid by now: it ends.
    // Ended only when this job SAW the order created or approved under the
    // same credentials: a change of credentials or of sandbox and live makes
    // every order answer not-found, and one of them may have been paid.
    if (
      read.decision.kind === "unreadable" &&
      read.decision.reason === "unknown_order" && intent.gone_may_end &&
      (intent.seen_state === "CREATED" || intent.seen_state === "APPROVED") &&
      intent.seen_client === await clientFingerprint(clientId, env)
    ) {
      return { kind: "end" };
    }
    return read.decision;
  }
  const order = read.body;
  if (order.id !== intent.order_id) return unreadable("unexpected_answer");
  deps.observe?.({
    state: String(order.status ?? ""),
    client: await clientFingerprint(clientId, env),
  });
  if (order.status === "VOIDED") return { kind: "end" };
  if (order.status === "APPROVED") {
    // The payer said yes and the notification that would have captured it
    // never came: the same checks and the same one capture as the webhook.
    if (!approvedOrderMatches(intent, order)) return unreadable("mismatch");
    // An old approval is a person's to look at: the payer may have paid the
    // same bill another way since.
    if (!intent.may_capture) return unreadable("approved_not_captured");
    // Still open now: a notification or another way of paying may have
    // closed it since the claim.
    if (deps.stillOpen && !(await deps.stillOpen())) return { kind: "left" };
    const captured = await captureApprovedOrder(
      deps.fetch,
      paypalApi(env),
      token,
      intent.order_id,
      AbortSignal.timeout(deps.timeoutMs),
    );
    if (captured.kind === "pending") return { kind: "left" };
    if (captured.kind === "failed") {
      return captured.status === null
        ? unreadable("unreachable")
        : failureOf(captured.status);
    }
    if (!paypalMatches(intent, captured.amount)) return unreadable("mismatch");
    return {
      kind: "settle",
      captureId: captured.id,
      fee: paypalFeeOf(captured.raw),
    };
  }
  if (order.status !== "COMPLETED") return { kind: "left" };
  const unit = ((order.purchase_units ?? []) as Row[])[0];
  const captures =
    ((unit?.payments as Row | undefined)?.captures ?? []) as Row[];
  const capture = captures.find((c) => c.status === "COMPLETED");
  if (!capture) return { kind: "left" };
  const amount = (capture.amount ?? {}) as Row;
  const currency = String(amount.currency_code ?? "").toUpperCase();
  if (
    currency !== intent.currency.toUpperCase() ||
    toMinor(amount.value as string | undefined, currency) !==
      intent.amount_cents
  ) {
    return unreadable("mismatch");
  }
  return {
    kind: "settle",
    captureId: String(capture.id),
    fee: paypalFeeOf(capture),
  };
}

/** The reader of [provider]; null for one the reconciliation does not ask. */
export function readerOf(
  provider: string,
):
  | ((intent: OpenIntent, cfg: Row, deps: ReadDeps) => Promise<Decision>)
  | null {
  switch (provider) {
    case "stripe":
      return readStripe;
    case "mollie":
    case "wero":
      return readMollie;
    case "paypal":
      return readPaypal;
    default:
      return null;
  }
}
