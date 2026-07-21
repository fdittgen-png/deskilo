# User Guide

Everything a member, admin, or owner needs to use DesKilo. *Autres langues : [Français](Guide-utilisateur) · [Deutsch](Benutzerhandbuch) · [Español](Guia-de-usuario) · [Italiano](Guida-utente).*

> The screenshots in this guide show the app in French — every screen exists identically in all five languages (English, Français, Deutsch, Español, Italiano); switch in **Settings → Language**.
>
> <img src="images/settings-language.jpg" width="200">

## 1. Getting started

### Create an account

Open the app and sign up with your email, a password (8+ characters), and a display name. You can show or hide the password while typing with the eye button.

### Create a workspace — or join one

After signing in you land on the welcome screen with two paths:

- **Create a workspace** — you become its **owner**. Pick a name, country (drives the default currency), and time zone. You'll then draw your floor plan in the editor (§7).
- **Join a workspace** — type the **workspace ID** someone shared with you, or tap **Scan QR code** and point the camera at the invite QR pinned to your space's wall. You join with the role the invite carries (§2).

One account can belong to several workspaces; switch between them in **Settings → Profiles**. Everything in the app is scoped to the active workspace.

## 2. Roles & invitations

DesKilo has three additive roles, plus a device account:

| Role | Can |
|---|---|
| **Member** | Check in/out, reserve, submit expenses, see and manage their own events and ledger |
| **Admin** | Everything a member can, plus: act *for anybody* (reservations, payments, expenses — subject to confirmation, §6), approve expenses, issue kiosk badges |
| **Owner** | Everything an admin can, plus: edit the physical workspace, define plans and prices, manage roles, kiosk devices, and workspace settings |
| **Kiosk** | A wall-mounted tablet account (§9) — shows the plan only; real members act through it with a badge |

**Every invitation is bound to a role.** On the owner's *Workspace ID & QR* screen there are two invites, each with its own QR code and code:

- **Member invite** — the workspace ID itself. Print it, pin it to the wall, share it freely: whoever scans or types it joins as a plain member.
- **Admin invite** — a separate secret code, visible to owners only. Share it only with people who should manage the workspace: whoever uses it joins as an admin.

**There is no owner invite — by design.** Ownership can only be granted by an existing owner, in *Members & plans*. A workspace always keeps at least one owner: the app refuses to demote or remove the last one. Promoting or demoting an **admin** goes through the validation flow (§6) — it applies once the workspace's validators confirm.

The QR encodes a link that names the role it grants (`deskilo://join?role=…`). Tampering with the link changes nothing — the server derives the role from the secret code itself.

## 3. The floor plan (Plan tab)

The plan shows the active level of your space: offices, desks, and seats, color-coded — **free**, **reserved**, **occupied**, **mine**, **blocked**. Occupied seats show who's there by first name, a **check badge** when they are checked in, and a **green dot** when they are online in the app right now.

The plan can look like your real space: the owner can put a **photo of the room as the level background** and place freely **resizable illustration images** (plants, sofas…) on the grid. A **desk transparency** slider in the workspace settings lets the photo show through the drawn desks.

Getting around:

- The canvas **auto-fits** your floor when it opens or when you rotate the device; **pinch to zoom** or use the **+ / −** buttons, drag the **scrollbars** along the edges, and tap the **fit** button to re-centre.
- Pick the floor from the **level menu** (a compact dropdown); the clock icon returns the time scroller to **now**.
- In **landscape**, the controls move into a side panel so the plan fills the screen — handy on tablets.

Booking from the plan:

- **Walk-up check-in**: tap a free seat → the sheet suggests *now* until the workspace default end → confirm. If someone reserved that seat later, your end time is capped and you're told.
- **Check-in on a reservation**: your reservation opens a check-in window. Check in from the plan or the reminder notification. No-shows are **auto-released** after the configured delay.
- **Check-out**: manual, or automatic at the reservation end / closing time.
- **Time scroller**: pick a from→to window (or Morning / Afternoon / Full day, depending on the workspace granularity) to see occupancy at any future moment.
- Seats can carry **accessories** (monitor, standing desk…), some with a per-half-day supplement that shows up on your statement.
- Bookings count against your **monthly days** (§8) — the app blocks or bills you past your plan, depending on what the owner configured for you.

## 4. Reservations (Reserve hub)

Open the **Reserve** hub (center button). A date strip picks the day; the window chips pick the time; then four views:

- **Plan** — the floor plan filtered to your chosen window; tap a free seat to book it.
- **Day** — every seat as a timeline row for the selected day; tap a free stretch to book, tap your own block to see its details.
- **Week** — a seat × day grid for the whole ISO week; find a free half-day at a glance and tap it to book.
- **Month** — an availability calendar: free desks per day across all floors; tap a day to drop into its Day view.

Reservations follow the workspace **granularity rule** — half-days, full days, or free start/end times on the owner's slot grid. They respect the **open weekdays** and **closure days**, and the booking rules (advance horizon, max duration, cancellation deadline). Repeating needs? Book a **series** (daily, weekdays, weekly) — closed days and conflicts are skipped and reported.

The **Calendar** tab shows your own bookings by month — your days are marked **red**, other members' **blue**, today is ringed — with a timeline view per day. In landscape both the calendar and the timeline use the split layout.

## 5. Members directory (Members tab)

See who's part of your community:

- Each member card shows their **photo** (or initial), **role**, **custom status** ("in Berlin till Friday…"), an **online / last-seen** indicator, and a **reservation chip**: checked-in seat, reserved now, or next upcoming reservation.
- Tap a member for their **detail sheet** — including their upcoming reservations.
- **Swipe** a member to message them on **WhatsApp**; the **group button** opens your community's WhatsApp group (set by the owner).
- Set your own photo, status, and phone visibility in **Settings**.

## 6. Events & confirmations (bell icon)

The events feed is the audit trail of your workspace: reservations created/changed/cancelled, payments recorded, expenses submitted, extra-days requests, role changes. Members see their own events; admins and owners see everyone's.

**The confirmation protocol:** whenever an admin does something *for somebody else* — books a seat for you, records your payment — it stays **pending until you confirm**. Pending items are pinned on top with accept/reject buttons and you get a notification. Actions you take on yourself never need confirmation.

**Validation quorum:** for money matters and role changes the owner defines *who* must approve and *how many* approvals are needed. Unanswered requests expire after 7 days — nothing costly is ever granted silently.

The owner tunes this per **domain** in **Settings → Validation rules**: payments, expenses, services, extra half-days, role changes, reservations, and adjustments each have their own rule (or inherit the default). A rule sets the number of required validations, *which* admins may validate (all, or named ones), and whether the owner must always sign off.

<p><img src="images/validation-rules.jpg" width="240"> <img src="images/validation-rule-edit.jpg" width="240"></p>

*Left: one rule per domain, inheriting from the default. Right: editing a rule — required validations, allowed validators, owner sign-off.*

## 7. For owners: the editor & settings

All administration lives under **Settings → Administration**. One rule to know: **a feature's settings entry only appears while that feature is enabled** — switch *Online payments* off in **Features** and its configuration screen disappears with it (and comes back when you re-enable it). The **Features** entry itself is always there, so you can always switch a module back on.

<p><img src="images/settings-administration.jpg" width="240"></p>

- **Editor** (app bar): draw your space on a grid — add levels, outline offices, place desks, stamp seats (with orientation, chair type, and amenities), block seats for maintenance. Add a **background photo** per level and **illustration images** you can move and resize. Deleting anything with future reservations makes you resolve them first.
- **Workspace ID & QR**: your role-bound invites (§2). You can replace the generated workspace ID with a memorable one (4–20 letters/digits), copy it, or share the QR as a PNG.
- **Availability**: open weekdays, closure days, and the booking granularity — free start/end times, a minute grid (5/15/30/60), half-days, or full days only.
- **Features**: switch whole modules on or off per workspace — calendar, events, money, services, PDF export, series booking, booking for others, push, seat blocking by admins, accessory supplements, **online payments**, **RFID/NFC badges**. Switching a module off removes *all* of its screens and buttons for every member.

<p><img src="images/workspace-id-qr.jpg" width="220"> <img src="images/availability-granularity.jpg" width="220"> <img src="images/features-toggles-1.jpg" width="220"> <img src="images/features-toggles-2.jpg" width="220"></p>

- **Members & plans**: tap a member to open their **management sheet** — add a service for them, set their subscription percentage, choose their **over-consumption policy** (§8), cap their **simultaneous reservations**, issue **badges** (§9), promote/demote admin, turn the account into a **kiosk device**, or pause the membership.

<p><img src="images/member-management-sheet.jpg" width="220"> <img src="images/member-subscription.jpg" width="220"> <img src="images/member-reservation-limit.jpg" width="220"></p>

*The management sheet, the subscription-percentage dialog, and the per-member reservation cap.*

- **Billing**: fee bands pricing the percentage subscriptions, overage rates, the subscription levels members may pick (with an optional free negotiated value) — and **day packages** (a number of days for a price) for members on the package policy.
- **Services** and **Accessories**: the catalogs behind §8 — owner-defined extras (lockers, printing…) and per-seat equipment with optional per-half-day supplements. Both are plain lists with a **+** button.

<p><img src="images/billing-bands-levels-packages.jpg" width="220"> <img src="images/services-catalog.jpg" width="220"> <img src="images/services-new-service.jpg" width="220"> <img src="images/accessories-catalog.jpg" width="220"></p>

*Billing (bands, levels, day packages) · the Services catalog and its create form · the Accessories catalog. An admin adds a service consumption for a member from the member's management sheet:*

<p><img src="images/member-add-service.jpg" width="220"></p>

- **Workspace settings**: name, country/currency, time zone, payment instructions (IBAN, PayPal.me, Wero, Lydia, Wise), the WhatsApp group link, **desk transparency**, exports — and the **danger zone**: a full **workspace reset** (deletes bookings, money, and the floor plan; keeps configuration and members) guarded by a typed *"I agree"*.
- **Import/export**: the whole configuration travels as an **XML file** — back it up, template it, or migrate a self-hosted instance. A **configuration PDF** (members, plan, prices, features) can be generated too. Files are saved **locally on your device**.

### Setting up online payments (owners)

Each community collects to its **own** provider account; the app never keeps the secret keys on any device — they live on the server.

1. Open **Settings → Online payments** (owner only).
2. Pick a provider and paste its keys from that provider's dashboard:
   - **PayPal** — Client ID, Secret, Environment (start with *sandbox*), Webhook ID, Return URL (PayPal Developer → your REST app).
   - **Credit card (Stripe)** — Secret key, Webhook signing secret, Return URL (Stripe → API keys / Webhooks).
   - **Mollie** — API key, Return URL (offers iDEAL, Bancontact, cards…).
   - **Wero (via Mollie)** — the same Mollie API key, with Wero enabled in your Mollie account.
3. **Save** — a green *Configured* chip appears. Turn on the **Online payments** feature (Settings → Features), and members see **Pay online** on an outstanding bill. (The *Online payments* settings entry itself only shows while the feature is on.)

<p><img src="images/payment-config-paypal-stripe.jpg" width="240"> <img src="images/payment-config-mollie-wero.jpg" width="240"></p>

A saved secret is never shown again — leave its field blank to keep it, type to replace it, **Remove** to clear the provider. Fees are the provider's (typically ~1.5–3% per payment, no monthly fee); DesKilo adds nothing, and the manual bank-transfer/IBAN route stays free.

If a payment doesn't start, turn on **Settings → Advanced → Developer mode** and open the **Developer** screen: the *payments* trace shows exactly which providers are configured and which fields are still missing.

<p><img src="images/developer-payment-traces.jpg" width="240"></p>

### Setting up RFID / NFC badges (owners)

Physical cards let people check in with a tap — no phone needed.

1. Open **Settings → RFID / NFC badges** (owner only). Switch **Enable NFC badge check-in** on, and read the **device status** line — you need an **Android** device with NFC on (iPads have no NFC).
2. Give each member a card: **Members & plans → the member → Badges → Register card**, then hold their card to the device. Any card with a readable chip works (MIFARE, NTAG…).
3. Use them at a **kiosk** (§9): the member taps the card to reserve or check in. Revoke a lost card from the same Badges dialog.

<p><img src="images/nfc-config.jpg" width="240"> <img src="images/member-badges-dialog.jpg" width="240"></p>

*The NFC configuration screen (workspace toggle + this device's NFC status) and a member's Badges dialog: revoke, register a card, or issue a new QR badge.*

## 8. Money (Money tab)

Your ledger answers *what do I owe, what am I owed* — and *how much can I still book*:

- **This month** — the card on top of your bill: how many **days** your subscription includes this month, how many you've **used**, how many are **left**, with a progress bar. A booked morning counts as 0.5 days. The monthly entitlement follows the workspace's open days and your percentage.
- **When your days run out**, what happens is the owner's per-member choice:
  - **Blocked** (default) — no more bookings; ask an admin, or request **extra half-days** right from the Money tab (validators approve; approved days still bill at the overage rate).
  - **Pay-as-you-go** — you can keep booking; each extra day bills at your fee band's overage rate (shown on the card).
  - **Packages** — tap **Buy a package** and pick one of the owner's day packs; your days increase immediately and the price lands on this month's bill.
- **Charges**: monthly subscription (a percentage plan), overage, service consumption, accessory supplements, day packages.
- **Credits**: approved expenses, recorded payments, adjustments.
- **Statements**: monthly, with **settled / outstanding** status, exportable as a **PDF bill** saved locally.
- **Paying**: DesKilo tracks payments; outstanding bills show the workspace's **payment instructions** (IBAN copies with one tap, PayPal.me opens directly). Record a payment ("I paid") with its method — the other side confirms. If the workspace enabled **online payments** and its server is configured for it, a **Pay online** button lets the member pay the amount owed straight away — with **PayPal, a credit card (Stripe), Mollie, or Wero**, whichever the workspace enabled (several show a chooser).
- **Expenses**: bought coffee for the space? Submit the expense — another admin approves it (no self-approval) and it credits your next statement.
- **Services**: owner-defined extras (lockers, printing…) whose consumption lands on your statement after you confirm it.

## 9. Kiosk mode (wall tablet)

Mount an Android tablet or iPad by the door and let people check in as they walk in:

1. The owner creates a normal account for the device, joins it to the workspace, and flags it as a **kiosk** in *Members & plans*. From then on that account is locked to a full-screen live floor plan — no other screens, nothing else to touch.
2. The owner (or an admin) gives each member a **badge**, in *Members & plans → a member → Badges*. Two kinds:
   - **QR code** — shown **exactly once**; tap **Save as PDF** to print a badge card, or save the QR on the member's phone.
   - **RFID/NFC card** — tap **Register card** and hold the member's physical card to the device (Android with NFC). Set it up in *Settings → RFID / NFC badges* (§7).
   Either badge is revocable at any time.
3. At the kiosk, tap a seat → **Check in**, **Reserve**, or **Check out** → present the badge: **tap the RFID/NFC card**, scan the QR with a USB/Bluetooth barcode scanner, or type the code.

Your identity exists only for the moment of the operation: the credential is sent once to the server, the booking is made **in your name**, and nothing is stored on the tablet — you are "signed out" the instant it completes. (Camera QR scanning and per-operation Google/Facebook sign-in are still on the roadmap; **iPads have no NFC**, so there the QR path is the way.)

## 10. Notifications

Check-in reminders, no-show releases, pending confirmations, expense decisions. Delivery is local-first; on Android the F-Droid flavor uses **UnifiedPush** (e.g. ntfy) instead of Google services — no Firebase anywhere.

## 11. Privacy

Minimal data: name, email, plan, bookings, ledger. You control your photo, your status, whether your name shows on the floor plan, and whether your phone number is visible in the directory. Kiosk badges are stored only as hashes — a lost badge is revoked, not guessed. No tracking, no third-party analytics. Financial history is anonymized, not deleted, on account erasure (bookkeeping retention).

## 12. Platforms

Android (Google Play and F-Droid), iPhone/iPad, and desktop — macOS, and Windows with an **MSI installer** built from every release. Your data follows your account.
