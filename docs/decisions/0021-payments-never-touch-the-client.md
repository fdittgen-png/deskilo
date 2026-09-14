# ADR 0021 — Payments never use a client SDK

**Status:** accepted · **Date:** 2026-09-13

## Context

DesKilo takes money through PayPal, Stripe and Mollie. The usual
integration drops each provider's mobile SDK into the app, lets it
collect the card, and trusts the callback it fires.

`docs/design/payments-integration.md` describes what this project does
instead. It has never been recorded as a decision, so the reasoning was
only in one head.

## Decision

**No payment provider SDK ships in the app.** The flow is:

```
app → RPC: create a payment intent
    → edge function → provider API (secret key, server side)
    → browser hands the member to the provider's own page
provider → webhook → edge function → signature check → RPC → ledger
```

The app never sees a card number, never holds a secret key, and never
learns that a payment succeeded from the device that made it.

## Consequences

**Good.** The F-Droid build stays free of proprietary blobs (ADR 0003
and 0012 depend on this). PCI scope is the provider's. A modified client
cannot claim a payment: money reaches the ledger only through a webhook
whose signature verified, and only once — `0205:48` guards the replay.
Adding a fourth provider is an edge function, not an app release.

**Costly.** The member leaves the app to pay, which is a worse checkout
than an embedded sheet. Webhook delivery is asynchronous, so the app
shows "waiting for the provider" for a few seconds it cannot shorten.
Testing needs the provider's sandbox rather than a mock in the app.

**Accepted.** A coworking community's money is not worth a smoother
checkout, and the F-Droid promise is not negotiable.
