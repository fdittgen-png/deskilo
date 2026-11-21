# DesKilo Privacy Policy

*Last updated: 2026-11-21 · Contact: fdittgen@gmail.com*

DesKilo is a booking and community-ledger app for small self-organized
coworking spaces, published by Florian Dittgen (Germany). This policy
describes what the app processes and why. DesKilo is open source
(AGPL-3.0-or-later): everything below can be verified in the code at
<https://github.com/fdittgen-png/deskilo>.

## Data we process

| Data | Purpose | Where |
|---|---|---|
| E-mail address, display name, password (hashed) | Your account (sign-in, password reset) | the database host named in the installation's privacy notice |
| Social sign-in identity (Google, Microsoft, Apple, or Facebook user id + e-mail), if you choose it | Alternative sign-in; linked to the same account | Supabase Auth |
| Workspace membership, role, subscription percentage | Running your coworking community | Supabase |
| Reservations and check-ins (seat/level, time) | Desk booking — the app's core function | Supabase |
| Ledger entries: subscription fees, usage, payments, expenses, services | The community's transparent member ledger | Supabase |
| Optional profile fields: photo, status text, profession and bio, WhatsApp number, e-mail | Each item has its own default audience, which you change under *Who sees me*: name and photo are shown to people who share a space with you; profession and bio, WhatsApp, e-mail and presence to nobody until you choose. Nothing is public unless you choose it, and WhatsApp, e-mail and presence never go wider than your own spaces | Supabase |
| Presence (last-seen timestamp, "in the space today") | "Online" dot in the member directory, to the audience you pick | Supabase |
| Public profile: name, profession, bio | Readable by anyone with the link, signed in or not — only after you publish it; off by default, withdrawn at any time. Never your contact details, presence or spaces | Supabase |
| Conversations: person to person, groups, messages to a space's hosts | Readable only by the people in the conversation (for a message to a space: its owners and the admins who agreed to be its public contacts, named before you write); see Messages below | the server the conversation lives on |
| Push token (this device's address) | Delivering push notifications, where the operator set push up and it is on for this device | Supabase + the push service (Firebase Cloud Messaging) |
| Badge credentials (kiosk QR / RFID card) | Wall-tablet check-in; stored **only as SHA-256 hashes** — the raw badge never persists server-side | Supabase |
| Online payment intents (amount, provider order id) | Settling a bill you chose to pay online | Supabase + your workspace's payment provider |

## What we do NOT do

- **No tracking, no analytics, no advertising.** The app contains no
  third-party tracking or analytics SDK and no ad SDK. Firebase is used
  only to deliver push notifications, and only where the operator of the
  installation configures it (see below); it is a delivery channel, not
  analytics.
- **No sale of data.** Data reaches only the recipients named in the
  installation's and your space's privacy notice — for example the
  database host, push delivery, a payment provider you pay through, or
  an e-invoicing destination a space enables.
- **No payment card data.** Card/wallet details are entered on the
  payment provider's own pages (PayPal, Stripe, Mollie, Wero); DesKilo
  only records that a payment happened and its amount.
- **Diagnostics stay local.** The optional developer-mode trace log is
  stored on your device only and shared only if you export it
  yourself.

## Messages

- **Only participants open a conversation in the application**: the two
  of you, the members of a group or, for a message to a space, the hosts
  named before you write. Being a space's owner or admin does not, by
  itself, give anyone the right to open your conversations: account
  messages are reachable only through server functions that check you
  take part, and a space's direct and group messages only by their
  participants. The *operator* is a different role from a space's owner or
  admin: it is whoever runs the server the conversation is stored on (a
  community that self-hosts is its own operator).
- **Not end-to-end encrypted.** A message is stored on that server in a
  form its operator can read, and the operator can technically reach the
  database. This is an access rule, not encryption: it limits what the
  application shows, not what the operator can technically do.
- **Across spaces and servers.** Writing to someone on another server,
  or asking to join a space there, connects you to that server first
  and asks you before anything is sent; that conversation is then
  stored on that server, under its operator.

## Assistants and agents

Only the flows below exist in the code today. Each is optional and off
until a person turns it on.

- **An external assistant you connect (MCP).** In *Connect an assistant*
  you approve a named assistant (a client such as Claude or ChatGPT) for
  the workspaces and the kinds of action you choose. It then calls the
  installation's published connector endpoint as you, with a delegated
  token that is limited to those workspaces and actions and to what your
  own permissions allow; a workspace's owner can also set a ceiling on
  which fields an assistant may be told. Some actions are only prepared
  and wait for your confirmation in the app. You can revoke the
  assistant at any time; revoking stops future requests.
- **What leaves Deskilo, and where it goes.** What the assistant reads or
  does with your approval (for example your bookings, balances and the
  names its answers contain) is sent to that assistant and is processed
  by the company that provides it, under that provider's own terms,
  retention and location, which Deskilo does not control and cannot
  state. Self-hosting Deskilo does not make that processing local.
  Revoking access does not delete what the assistant already received.
- **Browser tools on the web app.** Where a workspace has the feature on
  and you switch it on for this device, the web app offers tools to an
  agent running in your browser. They act with your signed-in page,
  through the app's own commands, with the same refusals as the screens;
  a write that needs a decision opens the app's confirmation. Mobile and
  desktop builds offer no such tools.
- **The public setup page.** Its agent tools edit a draft kept in that
  page in your browser; nothing is sent to a Deskilo server by editing
  it.
- **Notices.** An installation or a workspace can state, in its privacy
  notice, the recipients, purposes and regions of the flows it actually
  configured. Where a provider's retention or processing location is not
  stated, it is unknown to Deskilo; do not read silence as an assurance.

## Push notifications

Push is an outbound flow, and optional. It works only where the
operator of the installation has set it up and the space uses it. When
it is on for a device, that device's address (its push token) and each
notification go to Firebase Cloud Messaging, which passes notifications
for Apple devices on to Apple. The text is generic ("You have a new
message", "Someone needs your confirmation") — no names, no times, no
message text; the details are read in the app. Switching *Push
notifications on this device* off in Settings → Privacy & data stops
it for that device, and the app keeps working. A build prepared for
F-Droid has no push transport and no Google services.

## Data controller & processors

Each coworking workspace is operated by its **owner** (your community),
who determines members, prices, and payment providers. DesKilo can be
installed by anyone on their own Supabase project, in a region they
choose, so the region and any transfer outside the EU depend on the
installation: the app shows the installation's privacy notice, and the
space's own notice where it has one, with each recipient's role,
purpose, legal basis, region and transfer mechanism. Where the operator
has not recorded one of these, the notice says `unknown` rather than
guessing. Acknowledging a notice is not consent: each acknowledgment is
kept with the version it named, and a new version opts nobody in. If a workspace enables
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
| A business's birth record, when it was added to an organisation from its head | where it came from, what was carried, which of the head's owners were added and whether its prices are still to be named | for the life of the business | kept; it names people by account only, as the membership row does |
| Diagnostic trace | fixing a fault you report | on your device only, 512 KiB, oldest discarded | delete the app, or clear it in Settings |
| Answers to the space's own questions | a committee role, an emergency contact, a size for a group order — whatever the space asked | while you are a member of that space | deleted |
| Answers kept under a retention hold | only a question the owner documented a legal obligation for, such as a statutory member register | the period the hold states, readable only by whoever manages personal data in that space | kept until the hold expires, then deleted |

A space can ask questions of its own beyond the fields above. Every
answer is stored against your membership, so every answer is personal
data about you, whatever the owner ticked when they defined the
question: it travels in your data export and it is deleted when you
erase. The owner's "personal data" switch no longer exempts anything.
The only exception is a retention hold the owner documents for one
question — the legal basis in words and a period in days. An answer
under a hold survives your erasure stamped with that basis and its
expiry, only someone who manages personal data in that space can read
it, and it is deleted when the hold expires. A switch set to "not
personal" never creates a hold.

A refusal from the server names the question and the rule it broke, never
the answer, so an answer cannot reach a log through an error message.

The statutory period is set by the country of the workspace, not of the
member — it is the community's bookkeeping obligation, not yours. In
France and Germany that is ten years for accounting records; the app
knows the workspace's country because it needs it for VAT.

The table describes how long the database keeps each item. It is not a
promise that nothing ever leaves the workspace's database: data leaves it
when someone with the right exports it (your personal-data export, a
workspace export, an accounting export), through an integration the
operator or a space configured (a payment provider, an e-invoicing
destination, push delivery) and, if you connect one, to an assistant (see
*Assistants and agents* below). None of it goes to an analytics service.
There is no analytics service.

## Your rights (GDPR)

You have the right to access, rectify, export, and erase your personal
data, and to object to processing. Most of it is directly visible and
editable in the app (Settings, Profile). For anything else, contact
**fdittgen@gmail.com**. You may also lodge a complaint with your
supervisory authority.

Each space is the controller of what you did in it, and a request to a
space is recorded with the day it was received. It is answered within one
calendar month — the same date the following month, or that month's last
day when it has no such date — counted in the space's own time zone. A
space may extend that by two further months only by telling you why
within the first month; the original date stays on the record. You can
file a request after you have left a space, and no optional setting or
suspended feature closes that route; a space can also record a request
you made by letter or in person.

When a request is completed it says, store by store, what was removed,
corrected, restricted, kept (with the legal basis and how long) and what
is outside this installation. Your data export says the same about
itself: it covers one space on one installation, not another
installation, your devices' caches or the operator's backups. Before you
erase, the app can show what will go and what stays — invoices and the
ledger stay as accounting evidence, your answers to the space's
questions go — and the membership row that keeps those records together
is pseudonymous, not anonymous.

## Children

DesKilo is a workplace tool intended for adults and is not directed at
children under 16.

## Changes

Changes to this policy are published here (the file's git history is
the change log).
