// SPDX-License-Identifier: AGPL-3.0-or-later
//
// paypal-webhook — verify_jwt OFF; authenticity from PayPal's own
// webhook-signature verification. Credentials are PER WORKSPACE: the
// event's order id resolves the payment_intents row → workspace →
// that workspace's PayPal config (table first, env fallback). Settlement
// goes through the service-role settle_online_payment RPC (idempotent).
//
// #1638 — approval is not money. The order the event names must be OUR
// intent's order, for the intent's amount, currency and reference, before
// we capture it; the capture is idempotent on PayPal's side
// (`PayPal-Request-Id` fixed per order); a capture that PayPal reports
// COMPLETED settles at once, and an order that is already captured is
// READ BACK rather than captured again. A malformed or foreign amount
// never settles: the RPC is only ever called with the provider's own
// amount, in the intent's currency.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { toMinor } from "../_shared/money.ts";
import { paypalApi } from "../_shared/providers.ts";

type Intent = {
  workspace_id: string;
  amount_cents: number;
  currency: string;
  reference: string;
  status: string;
};
type Money = { value?: string; currency_code?: string } | undefined;

async function paypalConfig(
  admin: SupabaseClient,
  workspaceId: string,
): Promise<Record<string, string>> {
  const { data } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", "paypal")
    .maybeSingle();
  const stored = (data?.config ?? {}) as Record<string, string>;
  return {
    client_id: stored.client_id ?? Deno.env.get("PAYPAL_CLIENT_ID") ?? "",
    secret: stored.secret ?? Deno.env.get("PAYPAL_SECRET") ?? "",
    env: stored.env ?? Deno.env.get("PAYPAL_ENV") ?? "sandbox",
    webhook_id: stored.webhook_id ?? Deno.env.get("PAYPAL_WEBHOOK_ID") ?? "",
  };
}

async function accessToken(cfg: Record<string, string>): Promise<string> {
  const auth = btoa(`${cfg.client_id}:${cfg.secret}`);
  const res = await fetch(`${paypalApi(cfg.env)}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) throw new Error(`paypal oauth ${res.status}`);
  return (await res.json()).access_token;
}

/** The amount in [money] is exactly the intent's, in the intent's currency. */
function matches(intent: Intent, money: Money): boolean {
  const currency = (money?.currency_code ?? "").toUpperCase();
  if (currency !== intent.currency.toUpperCase()) return false;
  const cents = toMinor(money?.value, currency);
  return cents !== null && cents === intent.amount_cents;
}

/** The first capture of an order body PayPal returned, if completed. */
function completedCapture(
  order: Record<string, unknown>,
): { id: string; amount: Money } | null {
  const units = (order.purchase_units ?? []) as Array<Record<string, unknown>>;
  const captures = ((units[0]?.payments as Record<string, unknown> | undefined)
    ?.captures ?? []) as Array<Record<string, unknown>>;
  const capture = captures.find((c) => c.status === "COMPLETED");
  return capture
    ? { id: String(capture.id), amount: capture.amount as Money }
    : null;
}

const respond = (body: string, status: number) => new Response(body, { status });

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return respond("method_not_allowed", 405);

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(await req.text());
  } catch {
    return respond("invalid_json", 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const resource = (event.resource ?? {}) as Record<string, unknown>;
  const orderId = String(
    ((resource.supplementary_data as Record<string, unknown> | undefined)
      ?.related_ids as Record<string, unknown> | undefined)?.order_id ??
      resource.id ?? "",
  );

  // Resolve the workspace from the intent, then load ITS PayPal config.
  const { data: intent } = await admin
    .from("payment_intents")
    .select("workspace_id, amount_cents, currency, reference, status")
    .eq("provider", "paypal")
    .eq("order_id", orderId)
    .maybeSingle<Intent>();
  if (!intent) {
    console.log("paypal webhook: unknown order, ignoring", orderId);
    return respond("ok", 200);
  }
  const cfg = await paypalConfig(admin, intent.workspace_id);
  if (!cfg.webhook_id || !cfg.client_id) {
    console.log("paypal webhook not configured for workspace", intent.workspace_id);
    return respond("not_configured", 200);
  }

  // Verify the transmission against PayPal before trusting anything. An
  // outage of the verifier is NOT a verification: 500, PayPal retries.
  let token: string;
  try {
    token = await accessToken(cfg);
    const verifyRes = await fetch(
      `${paypalApi(cfg.env)}/v1/notifications/verify-webhook-signature`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          transmission_id: req.headers.get("paypal-transmission-id"),
          transmission_time: req.headers.get("paypal-transmission-time"),
          cert_url: req.headers.get("paypal-cert-url"),
          auth_algo: req.headers.get("paypal-auth-algo"),
          transmission_sig: req.headers.get("paypal-transmission-sig"),
          webhook_id: cfg.webhook_id,
          webhook_event: event,
        }),
      },
    );
    if (!verifyRes.ok) throw new Error(`verify ${verifyRes.status}`);
    const verification = await verifyRes.json();
    if (verification.verification_status !== "SUCCESS") {
      console.error("paypal webhook verification FAILED", verification);
      return respond("verification_failed", 400);
    }
  } catch (e) {
    console.error("paypal webhook verification error", String(e));
    return respond("verification_error", 500);
  }

  const settle = async (captureId: string, amount: Money): Promise<Response> => {
    if (!matches(intent, amount)) {
      console.error("paypal capture does not match the intent", {
        orderId,
        amount,
        expected: [intent.amount_cents, intent.currency],
      });
      return respond("amount_mismatch", 500);
    }
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: "paypal",
      p_order_id: orderId,
      p_capture_id: captureId,
      p_amount_cents: intent.amount_cents,
    });
    if (error) {
      console.error("paypal settle failed", error.message);
      return respond("settle_failed", 500);
    }
    console.log("paypal capture settled", { orderId, capture: captureId });
    return respond("ok", 200);
  };

  const type = event.event_type as string;
  if (type === "PAYMENT.CAPTURE.COMPLETED") {
    return await settle(String(resource.id), resource.amount as Money);
  }
  if (type === "CHECKOUT.ORDER.APPROVED") {
    // #1555 — approval is the buyer saying yes; it moves no money. An
    // order created with `intent: "CAPTURE"` still has to be captured.
    //
    // #1638 — refuse a foreign or altered order BEFORE any capture: the
    // approved order must carry our reference, amount and currency.
    const unit = ((resource.purchase_units ?? []) as Array<Record<string, unknown>>)[0];
    if (!unit || unit.custom_id !== intent.reference || !matches(intent, unit.amount as Money)) {
      console.error("paypal approved order does not match the intent", { orderId });
      return respond("order_mismatch", 409);
    }
    if (intent.status === "captured") return respond("ok", 200);
    try {
      const res = await fetch(
        `${paypalApi(cfg.env)}/v2/checkout/orders/${orderId}/capture`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
            // One logical capture per order: a redelivery, a retry after a
            // lost reply or a concurrent worker all get the FIRST capture.
            "PayPal-Request-Id": `deskilo-capture-${orderId}`,
          },
        },
      );
      if (res.ok) {
        const capture = completedCapture(await res.json());
        if (!capture) {
          // PENDING and friends: the capture exists, the money has not
          // moved; PAYMENT.CAPTURE.COMPLETED settles it later.
          console.log("paypal capture not completed yet", orderId);
          return respond("ok", 200);
        }
        return await settle(capture.id, capture.amount);
      }
      const detail = await res.text();
      if (!(res.status === 422 && detail.includes("ORDER_ALREADY_CAPTURED"))) {
        console.error("paypal capture failed", res.status, detail);
        return respond("capture_failed", 500);
      }
      // Captured already (another path, another request id): READ the
      // order rather than capture again, and settle what it says.
      const orderRes = await fetch(
        `${paypalApi(cfg.env)}/v2/checkout/orders/${orderId}`,
        { headers: { Authorization: `Bearer ${token}` } },
      );
      if (!orderRes.ok) {
        console.error("paypal order read failed", orderRes.status);
        return respond("order_read_failed", 500);
      }
      const capture = completedCapture(await orderRes.json());
      if (!capture) return respond("ok", 200);
      return await settle(capture.id, capture.amount);
    } catch (e) {
      console.error("paypal capture error", String(e));
      return respond("capture_error", 500);
    }
  }
  if (type === "PAYMENT.CAPTURE.DENIED" || type === "CHECKOUT.ORDER.VOIDED") {
    // Only an intent still `created` becomes failed: a captured one keeps
    // its money (mark_payment_failed, 0045).
    await admin.rpc("mark_payment_failed", {
      p_provider: "paypal",
      p_order_id: orderId,
    });
    console.log("paypal payment marked failed", { orderId, type });
    return respond("ok", 200);
  }
  console.log("paypal webhook ignored event", type);
  return respond("ok", 200);
});
