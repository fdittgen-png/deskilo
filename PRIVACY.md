# DesKilo Privacy Policy

*Last updated: 2026-07-22 · Contact: fdittgen@gmail.com*

DesKilo is a booking and community-ledger app for small self-organized
coworking spaces, published by Florian Dittgen (Germany). This policy
describes what the app processes and why. DesKilo is open source
(0BSD): everything below can be verified in the code at
<https://github.com/fdittgen-png/deskilo>.

## Data we process

| Data | Purpose | Where |
|---|---|---|
| E-mail address, display name, password (hashed) | Your account (sign-in, password reset) | Supabase (EU region, eu-central-1) |
| Social sign-in identity (Google, Microsoft, Apple, or Facebook user id + e-mail), if you choose it | Alternative sign-in; linked to the same account | Supabase Auth |
| Workspace membership, role, subscription percentage | Running your coworking community | Supabase |
| Reservations and check-ins (seat/level, time) | Desk booking — the app's core function | Supabase |
| Ledger entries: subscription fees, usage, payments, expenses, services | The community's transparent member ledger | Supabase |
| Optional profile fields: photo, status text, WhatsApp number | Shown to members of YOUR workspaces only, each shareable at your choice | Supabase |
| Presence (last-seen timestamp) | "Online" dot in the member directory | Supabase |
| Badge credentials (kiosk QR / RFID card) | Wall-tablet check-in; stored **only as SHA-256 hashes** — the raw badge never persists server-side | Supabase |
| Online payment intents (amount, provider order id) | Settling a bill you chose to pay online | Supabase + your workspace's payment provider |

## What we do NOT do

- **No tracking, no analytics, no advertising.** The app contains no
  third-party tracking or analytics SDK, no ad SDK, and (in every
  flavor) no Firebase.
- **No sale or sharing of data.** Data never leaves the service except
  to a payment provider you explicitly pay through.
- **No payment card data.** Card/wallet details are entered on the
  payment provider's own pages (PayPal, Stripe, Mollie, Wero); DesKilo
  only records that a payment happened and its amount.
- **Diagnostics stay local.** The optional developer-mode trace log is
  stored on your device only and shared only if you export it
  yourself.

## Push notifications

On Google Play builds, notifications are generated locally on the
device. The F-Droid flavor can use UnifiedPush with a distributor you
choose; the push payload is a content-free "check pending items" ping.

## Data controller & processors

Each coworking workspace is operated by its **owner** (your community),
who determines members, prices, and payment providers. The backend is
hosted on Supabase (Postgres, EU `eu-central-1`). If a workspace enables
online payments, the corresponding provider (PayPal, Stripe, or Mollie)
processes that payment under its own privacy policy.

## Retention & deletion

- You can leave a workspace at any time; the owner can pause or remove
  members.
- On account deletion, personal profile data (name, e-mail, photo,
  phone) is removed; **financial ledger history is anonymized, not
  deleted**, to preserve the community's bookkeeping integrity.
- Badges can be revoked at any time; revoked hashes stop working
  immediately.

## Your rights (GDPR)

You have the right to access, rectify, export, and erase your personal
data, and to object to processing. Most of it is directly visible and
editable in the app (Settings, Profile). For anything else, contact
**fdittgen@gmail.com**. You may also lodge a complaint with your
supervisory authority.

## Children

DesKilo is a workplace tool intended for adults and is not directed at
children under 16.

## Changes

Changes to this policy are published here (the file's git history is
the change log).
