# DesKilo Privacy Policy

*Last updated: 2026-07-22 · Contact: fdittgen@gmail.com*

DesKilo is a booking and community-ledger app for small self-organized
coworking spaces, published by Florian Dittgen (Germany). This policy
describes what the app processes and why. DesKilo is open source
(AGPL-3.0-or-later): everything below can be verified in the code at
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
device. Push notifications use Firebase Cloud Messaging; pushed
payloads carry no personal data (a generic kind only).

## Data controller & processors

Each coworking workspace is operated by its **owner** (your community),
who determines members, prices, and payment providers. The backend is
hosted on Supabase (Postgres, EU `eu-central-1`). If a workspace enables
online payments, the corresponding provider (PayPal, Stripe, or Mollie)
processes that payment under its own privacy policy.

## Retention & deletion

- You can leave a workspace at any time; the owner can pause or remove
  members.
- **Leaving one workspace.** Your bookings there are cancelled, the
  messages you sent are deleted, and your membership is marked exited —
  it keeps no personal data of its own. Your ledger rows and invoices
  stay, because they are the workspace's accounting records and the law
  requires the community to keep them.
- **Leaving your last workspace.** Your profile is cleared as well —
  name, WhatsApp number, status, address, VAT id and photo.
- So a member of two spaces who leaves one keeps their profile, because
  the other space still needs it. Their ledger rows in the space they
  left remain readable to that space's owner, under the same accounting
  retention as everyone else's.
- Badges can be revoked at any time; revoked hashes stop working
  immediately.

### What is kept, and for how long

| Data | Why it exists | Kept | When you erase |
|---|---|---|---|
| Profile — name, photo, WhatsApp, status, address, VAT id | to be a member of a space | while you are a member of any space | cleared when you leave your last one |
| Membership row | your role and standing in one space | for the life of the space | marked exited; keeps no personal data |
| Bookings | running the space | the workspace's configured booking-history limit | open ones cancelled; past ones kept as the space's occupancy record |
| Messages you sent | conversation | until you erase | deleted |
| Ledger entries | the space's accounts | the statutory accounting period of the workspace's country | kept |
| Invoices and credit notes | legal documents | the statutory accounting period of the workspace's country | kept, and immutable |
| Audit and decision trail | proving who approved what | the statutory period | kept |
| Badge hashes | opening the door | until revoked | revoked immediately |
| Diagnostic trace | fixing a fault you report | on your device only, 512 KiB, oldest discarded | delete the app, or clear it in Settings |
| Answers to the space's own questions, marked personal | a committee role, a joining date, an emergency contact the space asked for | while you are a member of that space | deleted |
| Answers marked NOT personal | the space's own operational data, such as a size for a group order | for the life of the space | kept |

A space can ask questions of its own beyond the fields above, and the
owner marks each one as personal or not when they define it. That single
mark decides everything: whether the answer travels in your data export,
whether it is deleted when you erase, and which row of this table it
falls under. The safe answer is the default — a new question is personal
until somebody deliberately says it is not.

A refusal from the server names the question and the rule it broke, never
the answer, so an answer cannot reach a log through an error message.

The statutory period is set by the country of the workspace, not of the
member — it is the community's bookkeeping obligation, not yours. In
France and Germany that is ten years for accounting records; the app
knows the workspace's country because it needs it for VAT.

Nothing in this table leaves the workspace's own database, and none of
it goes to an analytics service. There is no analytics service.

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
