// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4126 -- capturing a PayPal order the payer approved: one helper for the
// webhook (CHECKOUT.ORDER.APPROVED) and the reconciliation (an approved order
// whose notification never came), so both make the same checks and the same
// one capture.
//
// #1638 -- an approved order is captured only when it is this intent's: its
// custom id is the intent's id (or, for an order made before #3917, its
// reference), its amount and currency the intent's. #1555 -- approval moves
// no money; the capture does, under one request id per order, so a
// redelivery, a retry or the other path gets the FIRST capture. PayPal saying
// the order is already captured is answered by reading the order.
import { toMinor } from "../_shared/money.ts";

type Row = Record<string, unknown>;
export type Money = { value?: string; currency_code?: string } | undefined;

/** The intent an approved order is checked against. */
export type CapturedIntent = {
  id: string;
  reference: string;
  amount_cents: number;
  currency: string;
};

export type CaptureOutcome =
  /** The money moved: [capture] is the completed capture. */
  | { kind: "captured"; id: string; amount: Money; raw: Row }
  /** The capture exists, the money has not moved yet (PENDING and friends). */
  | { kind: "pending" }
  /** PayPal refused or could not be reached; [stage] says where. */
  | {
    kind: "failed";
    stage: "capture" | "read" | "network";
    status: number | null;
    detail: string;
  };

/** Whether [money] is the intent's amount in its currency. */
export function paypalMatches(intent: CapturedIntent, money: Money): boolean {
  const currency = (money?.currency_code ?? "").toUpperCase();
  if (currency !== intent.currency.toUpperCase()) return false;
  const cents = toMinor(money?.value, currency);
  return cents !== null && cents === intent.amount_cents;
}

/** Whether the approved [order] is [intent]'s, by its first purchase unit. */
export function approvedOrderMatches(
  intent: CapturedIntent,
  order: Row,
): boolean {
  const unit = ((order.purchase_units ?? []) as Row[])[0];
  return !!unit &&
    [intent.reference, intent.id].includes(String(unit.custom_id)) &&
    paypalMatches(intent, unit.amount as Money);
}

/** The first capture of an order body PayPal returned, if completed. */
export function completedCapture(
  order: Row,
): { id: string; amount: Money; raw: Row } | null {
  const units = (order.purchase_units ?? []) as Row[];
  const captures =
    ((units[0]?.payments as Row | undefined)?.captures ?? []) as Row[];
  const capture = captures.find((c) => c.status === "COMPLETED");
  return capture
    ? { id: String(capture.id), amount: capture.amount as Money, raw: capture }
    : null;
}

/** Captures [orderId] (already checked with approvedOrderMatches) at [base]
 * with [token]. */
export async function captureApprovedOrder(
  fetchFn: typeof fetch,
  base: string,
  token: string,
  orderId: string,
  signal?: AbortSignal,
): Promise<CaptureOutcome> {
  const settled = (body: Row): CaptureOutcome => {
    const capture = completedCapture(body);
    return capture ? { kind: "captured", ...capture } : { kind: "pending" };
  };
  try {
    const res = await fetchFn(
      `${base}/v2/checkout/orders/${encodeURIComponent(orderId)}/capture`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          "PayPal-Request-Id": `deskilo-capture-${orderId}`,
        },
        signal,
      },
    );
    if (res.ok) return settled((await res.json()) as Row);
    const detail = await res.text();
    if (!(res.status === 422 && detail.includes("ORDER_ALREADY_CAPTURED"))) {
      return { kind: "failed", stage: "capture", status: res.status, detail };
    }
    // Captured already (another path, another request id): READ the order
    // rather than capture again, and settle what it says.
    const orderRes = await fetchFn(
      `${base}/v2/checkout/orders/${encodeURIComponent(orderId)}`,
      {
        headers: { Authorization: `Bearer ${token}` },
        signal,
      },
    );
    if (!orderRes.ok) {
      await orderRes.body?.cancel();
      return {
        kind: "failed",
        stage: "read",
        status: orderRes.status,
        detail: "",
      };
    }
    return settled((await orderRes.json()) as Row);
  } catch (e) {
    return {
      kind: "failed",
      stage: "network",
      status: null,
      detail: String(e),
    };
  }
}
