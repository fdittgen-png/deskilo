# Online payments — design & integration guide

Status: **implemented (migration 0045 + live Edge Functions).** The
provider calls, webhooks and settlement are fully coded and deployed;
money moves as soon as the operator supplies the provider secrets below.
Three providers ship: **PayPal** (Orders v2), **Stripe** (Checkout —
cards/SEPA), **Mollie** (iDEAL, Bancontact, cards…). Until secrets exist
the app's Pay-online flow shows an owner diagnostics dialog naming the
exact missing env vars (`{action:'config'}` probe).

---

## 1. The problem

Today a payment is only **recorded**: `record_payment` creates a pending
event, the counterparty confirms it, and a ledger credit is posted
(migration 0008/0019). Nothing is actually charged — the "how to pay"
card just shows an IBAN / PayPal.me link / Wero handle for the member to
pay out-of-band (`PaymentInstructions`).

We want a member to tap **Pay** and have the money genuinely move, with
the ledger credit posted automatically once the provider confirms the
capture.

## 2. Design principles

1. **The client never holds PSP secrets.** All provider calls happen in
   Supabase **Edge Functions** (Deno). The Flutter app only *starts* a
   payment and *opens a URL*. This is what keeps the F-Droid build clean —
   no proprietary payment SDK is linked into the app; it opens the
   provider's hosted approval page in a browser.
2. **The capture is the proof.** A provider-confirmed capture posts a
   **confirmed** ledger credit directly — it does not go through the
   two-person confirmation flow (that exists to vouch for *manual*
   claims; a PSP capture needs no human witness).
3. **Idempotent by capture id.** Webhooks retry; every settlement is keyed
   on the provider's capture id so a credit is posted at most once.
4. **Opt-in, per workspace.** The `onlinePayments` feature flag (off by
   default) gates the UI; the Edge Function stays inert until its secrets
   are set. Both must be true for a charge to be possible.

## 3. Architecture

```
 Flutter app                Edge Functions (Deno)            PayPal / PSP
 ───────────                ─────────────────────            ────────────
 tap "Pay online"
   │  createPaymentOrder()
   ├──────────────────────► create-payment-order
   │                          • OAuth (client_credentials)
   │                          • create order (amount, custom_id)
   │                          • insert payment_intents row
   │                          • return approve_url  ─────────► order created
   │ ◄── approve_url ─────────┘
   │
   │  open approve_url (external browser / in-app tab)
   ├───────────────────────────────────────────────────────► member pays
   │                                                             │ capture
 (member returns to app)                                         ▼
                            paypal-webhook  ◄──────── PAYMENT.CAPTURE.COMPLETED
                              • verify signature (PAYPAL_WEBHOOK_ID)
                              • read custom_id → member/period/amount
                              • settle_online_payment()  ──► ledger credit (confirmed)
```

- **`create-payment-order`** (`supabase/functions/create-payment-order`):
  app-facing. Auth via the member's Supabase JWT (default). Creates the
  provider order and returns `approve_url`.
- **`paypal-webhook`** (`supabase/functions/paypal-webhook`): PSP-facing.
  Deployed `--no-verify-jwt` (PayPal has no Supabase JWT); it verifies the
  PayPal **webhook signature** instead. Posts the ledger credit.
- **`settle_online_payment(...)`** — a new `SECURITY DEFINER` RPC (see §6),
  callable only with the **service-role** key (from the webhook). It
  inserts a confirmed `payment` ledger credit, idempotent on capture id.

## 4. PayPal flow (Orders v2)

1. **OAuth**: `POST {PAYPAL_API}/v1/oauth2/token`, grant
   `client_credentials`, Basic-auth `PAYPAL_CLIENT_ID:PAYPAL_SECRET`.
   `PAYPAL_API` = `https://api-m.sandbox.paypal.com` (sandbox) or
   `https://api-m.paypal.com` (live).
2. **Create order**: `POST /v2/checkout/orders`
   ```jsonc
   {
     "intent": "CAPTURE",
     "purchase_units": [{
       "amount": { "currency_code": "EUR", "value": "42.90" },
       "custom_id": "<workspace_id>:<member_id>:<period>"
     }]
   }
   ```
   Return the `rel: "approve"` HATEOAS link as `approve_url`. Persist a
   `payment_intents` row `(order_id, workspace_id, member_id, period,
   amount_cents, status='created')`.
3. **Member approves** in the browser; PayPal captures (intent CAPTURE
   auto-captures on approval, or capture explicitly via
   `POST /v2/checkout/orders/{id}/capture`).
4. **Webhook** `PAYMENT.CAPTURE.COMPLETED` → verify → `custom_id` gives the
   member/period, `resource.id` is the capture id, `resource.amount` the
   money → `settle_online_payment`.

Currency comes from the workspace (`workspaces.currency_code`); format
cents to major units with two decimals.

## 5. Other payment methods

| Method | Provider | Shape |
| --- | --- | --- |
| Card, SEPA Direct Debit | **Stripe** | `create-payment-intent` Edge Function → Stripe Checkout / PaymentSheet → `charge.succeeded` webhook → same `settle_online_payment`. |
| Twint, Bancontact, iDEAL, + PayPal + card + SEPA behind **one** API | **Mollie** | One `create-payment` call returns a `_links.checkout` URL; `payment.paid` webhook settles. Best fit if you want several EU methods without integrating each PSP. |
| Wero / Lydia | — | No broad merchant API at hobby scale; keep as **manual** `PaymentInstructions` (unchanged). |

The Edge-Function seam is provider-agnostic: `create-payment-order`
already returns an opaque `approve_url`, and every webhook funnels into the
same `settle_online_payment` RPC. Adding Stripe/Mollie is a new function +
a new webhook, no client change beyond a method picker.

## 6. Reconciliation (the settlement RPC)

New migration (not yet written — ship with the first live PSP):

```sql
create table public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  provider text not null,              -- 'paypal' | 'stripe' | 'mollie'
  order_id text not null,              -- provider order/intent id
  capture_id text,                     -- set on capture; unique when present
  period text not null,
  amount_cents int not null,
  status text not null default 'created', -- created | captured | failed
  created_at timestamptz not null default now(),
  unique (provider, capture_id)
);

-- called ONLY by the webhook with the service-role key
create function public.settle_online_payment(
  p_provider text, p_capture_id text, p_workspace_id uuid,
  p_member_id uuid, p_amount_cents int, p_period text
) returns void language plpgsql security definer set search_path = public as $$
begin
  -- idempotent: the unique (provider, capture_id) makes a retry a no-op
  insert into public.payment_intents
    (workspace_id, member_id, provider, order_id, capture_id, period,
     amount_cents, status)
  values (p_workspace_id, p_member_id, p_provider, p_capture_id, p_capture_id,
          p_period, p_amount_cents, 'captured')
  on conflict (provider, capture_id) do nothing;
  if not found then return; end if;   -- already settled

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (p_workspace_id, p_member_id, 'credit', 'payment', p_amount_cents,
          p_provider || ' online payment', p_period);
end;
$$;
revoke execute on function public.settle_online_payment(text,text,uuid,uuid,int,text)
  from public, anon, authenticated;   -- service role only
```

This reuses the existing `payment` ledger category, so the credit shows on
the bill's "Payments & credits" section with no UI change.

## 7. What the operator must supply

Nothing in the app — only server config:

1. A **PayPal business account** and a REST app (Developer Dashboard) →
   `client_id` + `secret`; a **webhook** subscribed to
   `PAYMENT.CAPTURE.COMPLETED` → `webhook_id`.
2. Set Edge-Function secrets:
   ```bash
   supabase secrets set \
     PAYPAL_CLIENT_ID=... PAYPAL_SECRET=... \
     PAYPAL_ENV=sandbox PAYPAL_WEBHOOK_ID=...
   ```
3. Deploy the functions:
   ```bash
   supabase functions deploy create-payment-order
   supabase functions deploy paypal-webhook --no-verify-jwt
   ```
4. Flip the workspace **Online payments** feature on (owner → Settings →
   Features).

Until step 2, `create-payment-order` returns `not_configured` and the app
shows *"Online payments aren't set up yet."* — no error, no charge.

## 8. What ships now (0043 scaffolding)

- Feature flag `onlinePayments` (default **off**).
- `MoneyRepository.createPaymentOrder(...)` → invokes the Edge Function;
  returns the approval `Uri`, or `null` when unconfigured.
- A **"Pay online with PayPal"** button on an outstanding bill (gated by
  the flag); it opens the approval URL, or explains that online payments
  aren't set up.
- Edge-Function stubs `create-payment-order` and `paypal-webhook` that are
  correct-by-construction inert: no secrets → no action.

The scaffolding is wired end-to-end but **cannot move money** until the
secrets and the `settle_online_payment` migration land.

## 9. Rollout checklist

- [x] `payment_intents` + `settle_online_payment` migration (0045).
- [x] PayPal Orders v2 implemented in `create-payment-order`.
- [x] Stripe Checkout Sessions + Mollie Payments implemented (same function, `provider` param; `{action:'config'}` lists what's configured).
- [x] Webhooks implemented + deployed: `paypal-webhook` (signature verification), `stripe-webhook` (HMAC verification + replay window), `mollie-webhook` (fetch-back verification) — all settle via the idempotent service-role RPC.
- [x] Undeployed/unconfigured states are diagnosable from the app: admins get a dialog naming the missing env vars; every attempt is traced under the `payments` domain (Developer screen).
- [ ] Operator: create the provider account(s) and `supabase secrets set` the vars in §7, incl. `PAYMENT_RETURN_URL`.
- [ ] Test in sandbox/test mode end-to-end (sandbox buyer, test capture, webhook replay → exactly one credit).
- [ ] Switch to live keys; enable the `onlinePayments` feature for a pilot workspace.
- [ ] Document refunds/disputes handling (out of scope for v1).
