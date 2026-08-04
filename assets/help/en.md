# User Guide

Everything a member, admin, or owner needs to use DesKilo.

> The screenshots in this guide show the app in French — every screen exists identically in all five languages (English, Français, Deutsch, Español, Italiano); switch in **Settings → Language**.

![](assets/help/images/settings-language.jpg)

## 1. Getting started

### Create an account

Open the app and sign up with your email, a password (8+ characters), and a display name. You can show or hide the password while typing with the eye button.

### Create a workspace — or join one

After signing in you land on the welcome screen with two paths:

- **Create a workspace** — you become its **owner**. Pick a name, country (drives the default currency), and time zone. You'll then draw your floor plan in the editor (§7).
- **Join a workspace** — type the **workspace ID** someone shared with you, or tap **Scan QR code** and point the camera at the invite QR pinned to your space's wall. You join with the role the invite carries (§2).

One account can belong to several workspaces; switch between them in **Settings → Profiles**, and **star one as your default** — that's the profile the app opens with. Everything in the app is scoped to the active workspace.

**Everything stays live.** Whatever anyone changes — a booking, a new member, a setting — is pushed to every connected device within seconds, including the one that made the change. No restart, no pull-to-refresh.

## 2. Roles & invitations

DesKilo has three additive roles, plus a device account:

| Role | Can |
|---|---|
| **Member** | Check in/out, reserve, submit expenses, see and manage their own events and ledger |
| **Admin** | Everything a member can, plus: act *for anybody* (reservations, payments, expenses — subject to confirmation, §6), approve expenses, issue kiosk badges |
| **Owner** | Everything an admin can, plus: edit the physical workspace, define plans and prices, manage roles, kiosk devices, and workspace settings |
| **Co-owner** | *Active*: the owner's permissions right now, plus automatic succession. *Passive*: a successor-in-waiting with no extra permissions today |
| **Kiosk** | A wall-mounted tablet account (§9) — shows the plan only; real members act through it with a badge |

**Every invitation is bound to a role.** On the owner's *Workspace ID & QR* screen there are two invites, each with its own QR code and code:

- **Member invite** — the workspace ID itself. Print it, pin it to the wall, share it freely: whoever scans or types it joins as a plain member.
- **Admin invite** — a **personal, single-use code**, minted by an owner for one specific person. It admits that one person as an admin, then expires (unused codes lapse after 14 days). Mint a new one per admin with *New admin code*.

**There is no owner invite — by design.** Ownership can only be granted by an existing owner, in *Members & plans*. A workspace always keeps at least one owner. Promoting or demoting an **admin** goes through the validation flow (§6) — it applies once the workspace's validators confirm.

**Co-owners keep the workspace alive.** The owner appoints any member or admin as a co-owner (*Members & plans → the member → Co-ownership*), in one of two flavors: an **active** co-owner works with the owner's permissions immediately; a **passive** co-owner has no extra permissions until the day they are needed. Either way, succession is automatic: if the last owner leaves — exits, is removed, or their account disappears — the best co-owner (active before passive) **becomes owner instantly**, on the server, with no action required. The owner can also hand over deliberately at any time with *Promote to owner now*. One nuance: validation rules that demand the *owner's* sign-off (§6) always mean a literal owner, not an active co-owner.

The QR encodes a link that names the role it grants (`deskilo://join?role=…`). Tampering with the link changes nothing — the server derives the role from the code itself: the workspace ID always joins as a member, and a personal invitation joins in exactly the role it was minted with, once. A forwarded admin code that was already used — or expired — admits nobody.

**Inviting someone by message** (*Invite someone*): each WhatsApp/SMS/share send mints its own personal single-use code and builds a ready-made message in the invitee's language. The recipient can simply copy the whole message and paste it into the app's join field — the code is detected automatically.

## 3. The floor plan (Plan tab)

The plan shows the active level of your space: offices, desks, and seats, color-coded — **free**, **reserved**, **occupied**, **mine**, **blocked**. It opens **instantly from the last known data** and refreshes in the background — on flaky Wi-Fi you still see the most recent state instead of a blank screen. Occupied seats show who's there by first name, a **check badge** when they are checked in, and a **green dot** when they are online in the app right now.

The plan can look like your real space: the owner can put a **photo of the room as the level background** and place freely **resizable illustration images** (plants, sofas…) on the grid. A **desk transparency** slider in the workspace settings lets the photo show through the drawn desks.

Getting around:

- The canvas **auto-fits** your floor when it opens or when you rotate the device; **pinch to zoom** or use the **+ / −** buttons, drag the **scrollbars** along the edges, and tap the **fit** button to re-centre.
- Pick the floor from the **level menu** (a compact dropdown); the clock icon returns the time scroller to **now**.
- In **landscape**, the controls move into a side panel so the plan fills the screen — handy on tablets.

Booking from the plan:

- **Walk-up check-in**: tap a free seat → the sheet suggests *now* until the workspace default end → confirm. If someone reserved that seat later, your end time is capped and you're told.
- **Check-in on a reservation**: checking in means *you are there* — the window opens **15 minutes before** your start and closes when the reservation ends. Outside it the check-in button is disabled and tells you when it opens; browsing a future time never offers a live check-in. Admins can check in a member standing at their seat (while *booking for others* is on).
- **Check-out**: manual — or, when the owner enables **auto check-in/out**, forgotten reservations complete themselves at day's end: never-touched bookings count as attended from their start to their end, and forgotten check-outs close at the reservation's own end.
- **Whole spaces**: **double-tap** a desk, a room, or an empty stretch of floor to act on the **whole table, office or level** — the same sheet as scanning its QR card (§4), with the same period picker and repetition options as a seat.
- **Time scroller**: pick a from→to window (or Morning / Afternoon / Full day, depending on the workspace granularity) to see occupancy at any future moment.
- Seats can carry **accessories** (monitor, standing desk…), some with a per-half-day supplement that shows up on your statement.
- Bookings count against your **monthly days** (§8) — the app blocks or bills you past your plan, depending on what the owner configured for you.

## 4. Reservations (Reserve hub)

Open the **Reserve** hub (center button). A date strip picks the day; the window chips pick the time; then four views:

- **Plan** — the floor plan filtered to your chosen window; tap a free seat to book it.
- **Day** — every seat as a timeline row for the selected day; tap a free stretch to book, tap your own block to see its details.
- **Week** — a seat × day grid for the whole ISO week; find a free half-day at a glance and tap it to book.
- **Month** — an availability calendar: free desks per day across all floors; tap a day to drop into its Day view.

**One place at a time**: you can hold only one active reservation per time window — booking or checking in somewhere else while one is running is refused, and checking in closes any earlier check-in whose booking already ended. Admins and owners can **overrule**: tapping an occupied or reserved seat offers *Remove reservation (overrule)* — the reservation is removed and the member and all admins are notified through the events feed.

Reservations follow the workspace **granularity rule** — half-days, full days, real hours (exact from–to times with the half/full-day windows as shortcuts), or free start/end times on the owner's slot grid. Half and full days cover the workspace's configured **working hours** (default 8:00–17:00 with the half-day boundary at 12:00). They respect the **open weekdays** and **closure days**, and the booking rules (advance horizon, max duration, cancellation deadline). Repeating needs? Book a **series** (daily, weekdays, weekly) — closed days and conflicts are skipped and reported.

The **Calendar** tab shows your own bookings by month — your days are marked **red**, other members' **blue**, today is ringed — with a timeline view per day. In landscape both the calendar and the timeline use the split layout.

### Scan a space code

Every seat, desk, office and level can carry a printed **QR card** (§7). Tap the **scan button** in the Reserve hub, point the camera at the card — or type its code — and the app identifies the space and shows exactly what *you* may do there:

- **Seat card** — reserve or check in on that exact seat, on the spot (today's window: morning / afternoon / full day where the workspace uses half-days, otherwise from now for the next hours).
- **Desk card** — the desk's seats with their live state; pick a free one.
- **Office or level card** — if the owner made it reservable, the *Office & level reservations* feature is on **and** you hold the personal right (§7) — owners and admins always do — you can reserve or check into the **whole office or floor** — with the same period picker (morning / afternoon / full day, or free times) and **series** options as a seat; its price per half-day is shown and lands on your bill. Otherwise the sheet tells you why, and an office falls back to its seats.

**Conflicts protect both directions:** an office or level cannot be reserved while any seat inside is already booked in that window — and no seat can be booked while its office or level is reserved as a whole.

## 5. Members directory (Members tab)

See who's part of your community:

- Each member card shows their **photo** (or initial), **role**, **custom status** ("in Berlin till Friday…"), an **online / last-seen** indicator, and a **reservation chip**: checked-in seat, reserved now, or next upcoming reservation.
- Tap a member for their **detail sheet** — including their upcoming reservations.
- **Swipe** a member to message them on **WhatsApp**; the **group button** opens your community's WhatsApp group (set by the owner).
- Set your own photo, status, and phone visibility in **Settings**.
- Admins and owners additionally see each member's **email** under the name — plain members don't: member-to-member contact stays the opt-in WhatsApp number.

## 6. Events & confirmations (bell icon)

The events feed is the audit trail of your workspace: reservations created/changed/cancelled, payments recorded, expenses submitted, extra-days requests, role changes. Members see their own events; admins and owners see everyone's.

**The confirmation protocol:** whenever an admin does something *for somebody else* — books a seat for you, records your payment — it stays **pending until you confirm**. Pending items are pinned on top with accept/reject buttons and you get a notification. Actions you take on yourself never need confirmation.

**Validation quorum:** for money matters and role changes the owner defines *who* must approve and *how many* approvals are needed. **Nobody validates their own event** — only another person can; where no other validator exists, the request simply waits. Unanswered requests expire after 7 days — nothing costly is ever granted silently, and nothing is self-granted.

The owner tunes this per **domain** in **Settings → Validation rules**: payments, expenses, services, extra half-days, role changes, reservations, and adjustments each have their own rule (or inherit the default). A rule sets the number of required validations, *which* admins may validate (all, or named ones), and whether the owner must always sign off.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*Left: one rule per domain, inheriting from the default. Right: editing a rule — required validations, allowed validators, owner sign-off.*

## 7. For owners: the editor & settings

All administration lives under **Settings → Administration**. One rule to know: **a feature's settings entry only appears while that feature is enabled** — switch *Online payments* off in **Features** and its configuration screen disappears with it (and comes back when you re-enable it). The **Features** entry itself is always there, so you can always switch a module back on.

![](assets/help/images/settings-administration.jpg)

- **Editor** (app bar): draw your space on a grid — add levels, outline offices, place desks, stamp seats (with orientation, chair type, and amenities), block seats for maintenance. Add a **background photo** per level and **illustration images** you can move and resize. Deleting anything with future reservations makes you resolve them first.
- **Workspace ID & QR**: your role-bound invites (§2). You can replace the generated workspace ID with a memorable one (4–20 letters/digits), copy it, or share the QR as a PNG.
- **Availability**: open weekdays, closure days, the booking granularity — free start/end times, a minute grid (5/15/30/60), half-days, full days only, or real hours — and the **working hours** (day start, half-day boundary, day end; under real hours also how many hours bill as a half and a full day).
- **Features**: switch whole modules on or off per workspace — calendar, events, money, services, PDF export, series booking, booking for others, push, seat blocking by admins, accessory supplements, **online payments**, **invoicing**, **office & level reservations**, **kiosk mode**, **RFID/NFC badges**, **members directory**, **WhatsApp integration**, **space QR codes**, **co-owners**, **data export**, **auto check-in/out**. Switching a module off removes *all* of its screens and buttons for every member.

  The list is **hierarchical**: a feature that needs another sits indented under it with a *Requires…* note, and is greyed out while its parent is off — *Money* carries services, accessory supplements, online payments and invoicing; *Office & level reservations* carries the admin assignment right; *Kiosk mode* carries RFID/NFC badges; *Members directory* carries the WhatsApp integration. Switching a parent off takes its whole subtree out of the app; the child's stored choice comes back untouched when the parent returns.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

- **Members & plans**: tap a member to open their **management sheet** — add a service for them, set their subscription percentage, choose their **over-consumption policy** (§8), cap their **simultaneous reservations**, issue **badges** (§9), promote/demote admin, turn the account into a **kiosk device**, or pause the membership. Each row shows the member's **email** under the name.

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

*The management sheet, the subscription-percentage dialog, and the per-member reservation cap.*

- **Billing**: fee bands pricing the percentage subscriptions, overage rates, the subscription levels members may pick (with an optional free negotiated value) — and **day packages** (a number of days for a price) for members on the package policy.
- **Services** and **Accessories**: the catalogs behind §8 — owner-defined extras (lockers, printing…) and per-seat equipment with optional per-half-day supplements. Both are plain lists with a **+** button.

![](assets/help/images/billing-bands-levels-packages.jpg)

 

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

 

![](assets/help/images/accessories-catalog.jpg)

*Billing (bands, levels, day packages) · the Services catalog and its create form · the Accessories catalog. An admin adds a service consumption for a member from the member's management sheet:*

![](assets/help/images/member-add-service.jpg)

- **Workspace settings**: name, country/currency, time zone, payment instructions (IBAN, PayPal.me, Wero, Lydia, Wise), the WhatsApp group link, **desk transparency**, exports — and the **danger zone**: a full **workspace reset** (deletes bookings, money, and the floor plan; keeps configuration and members) guarded by a typed *"I agree"*.
- **Import/export**: the whole configuration travels as an **XML file** — back it up, template it, or migrate a self-hosted instance. A **configuration PDF** (members, plan, prices, features) can be generated too. An **Excel workbook** exports the live data itself — workspace, levels, desks, seats, members, reservations, check-ins/outs, payments, services and invoices, one tab each (*data export* feature). Every export lands in your device's **Downloads** folder.

### Space QR codes & whole-space reservations (owners)

Four steps turn "scan the code on the desk" into the daily booking flow (§4):

1. In the **editor**, mark an office or a level **Bookable as a whole** and give it a **price per half-day** (the office property sheet / the level menu).
2. Enable **Office & level reservations** in **Features** (off by default).
3. Grant each entitled member **"May reserve a whole office or level"** — owners and admins set it in the member's management sheet, never for themselves.
4. Print the cards: **Workspace settings → Space QR codes (PDF)** — one credit-card QR per **seat, desk, office and level**, ten per A4 page, saved to Downloads. Cut them out and stick each card on its space.

An office reservation covers **all the desks inside it**; a level reservation covers the whole floor. Both are only possible while nothing inside is booked — and they show up as their own lines on the member's bill.

### Co-owners (owners)

Make sure the community never depends on one account:

1. Open *Members & plans → the member → **Co-ownership*** and pick **active** (owner permissions now) or **passive** (successor-in-waiting).
2. Hand over at any time with ***Promote to owner now*** — the co-owner becomes a full owner alongside you.
3. If the last owner ever leaves the workspace, the best co-owner is **promoted automatically** on the server — active before passive. This safety net works even while the *Co-owners* feature toggle is off (the toggle only hides the appointment buttons).

### Setting up online payments (owners)

Each community collects to its **own** provider account; the app never keeps the secret keys on any device — they live on the server.

1. Open **Settings → Online payments** (owner only).
2. Pick a provider and paste its keys from that provider's dashboard:
   - **PayPal** — Client ID, Secret, Environment (start with *sandbox*), Webhook ID, Return URL (PayPal Developer → your REST app).
   - **Credit card (Stripe)** — Secret key, Webhook signing secret, Return URL (Stripe → API keys / Webhooks).
   - **Mollie** — API key, Return URL (offers iDEAL, Bancontact, cards…).
   - **Wero (via Mollie)** — the same Mollie API key, with Wero enabled in your Mollie account.
3. **Save** — a green *Configured* chip appears. Turn on the **Online payments** feature (Settings → Features), and members see **Pay online** on an outstanding bill. (The *Online payments* settings entry itself only shows while the feature is on.)

![](assets/help/images/payment-config-paypal-stripe.jpg)

 

![](assets/help/images/payment-config-mollie-wero.jpg)

A saved secret is never shown again — leave its field blank to keep it, type to replace it, **Remove** to clear the provider. Fees are the provider's (typically ~1.5–3% per payment, no monthly fee); DesKilo adds nothing, and the manual bank-transfer/IBAN route stays free.

If a payment doesn't start, turn on **Settings → Advanced → Developer mode** and open the **Developer** screen: the *payments* trace shows exactly which providers are configured and which fields are still missing.

![](assets/help/images/developer-payment-traces.jpg)

#### The provider dashboards, step by step

Keep **test and live environments strictly apart**: every provider has separate keys per mode, and the keys you paste into DesKilo must all belong to the same mode. In the URLs below, `<project-ref>` is your Supabase project reference (self-hosters use their own instance's URL).

**PayPal**

1. Sign in at [developer.paypal.com](https://developer.paypal.com) and open **Apps & Credentials**.
2. Flip the **Sandbox / Live** toggle — start in *sandbox*; switch to *live* only for production. DesKilo's *Environment* field must match the keys.
3. **Create a REST-API app** — this generates the **Client ID** and **Secret**.
4. In the app, add a **webhook**: URL `https://<project-ref>.supabase.co/functions/v1/paypal-webhook`, subscribed at least to *Payment capture completed* (plus *denied* / *order voided*). Copy the **Webhook ID**. In DesKilo the webhook is not optional — it is how a payment gets settled onto the bill.
5. Paste Client ID, Secret, Environment, Webhook ID, and your Return URL into **Settings → Online payments → PayPal**. Nothing is stored in the app or on any device — everything goes to the server.

**Stripe (credit cards & Cartes Bancaires)**

1. Sign in at [dashboard.stripe.com](https://dashboard.stripe.com) and open **Developers**.
2. The **Test mode / Live mode** toggle decides which keys you see. DesKilo needs only the **Secret key** — the checkout is created server-side, so the *publishable* key is not used.
3. Under **Settings → Payment methods**, enable the card networks you want. **Targeting France? Explicitly enable Cartes Bancaires** — French members often prefer CB over international Visa/Mastercard routing.
4. Under **Developers → Webhooks**, add the endpoint `https://<project-ref>.supabase.co/functions/v1/stripe-webhook` with the `checkout.session.completed` event, and copy the **Webhook signing secret**.
5. Paste the Secret key, the signing secret, and your Return URL into **Settings → Online payments → Credit card (Stripe)**.

**Mollie (iDEAL, Bancontact, Wero…)**

1. Sign in at [my.mollie.com](https://my.mollie.com) → **Developers → API keys** and copy the **Test** or **Live API key** (the mode is encoded in the key itself).
2. Under **Settings → Payment methods**, enable what your members should see: **iDEAL** (Netherlands), **Bancontact** (Belgium), cards — and **Wero**, the European Payments Initiative wallet for instant account-to-account payments in Germany, France, and Belgium (the successor to Paylib and giropay).
3. In DesKilo, **Mollie** and **Wero** are two provider cards sharing the same API key — a Wero payment is created as a Mollie payment with the Wero method. Configure whichever you want members to see.
4. Redirect and webhook URLs are set **automatically by DesKilo** on every payment (redirect = your Return URL, webhook = the `mollie-webhook` function) — nothing to configure in the Mollie dashboard.

#### More payment methods (outlook)

| Provider / method | Focus | How it fits DesKilo |
|---|---|---|
| **Apple Pay / Google Pay** | Mobile wallets, one-tap checkout | Enable them in your Stripe (or Mollie) dashboard — they appear on the hosted payment page automatically, with no DesKilo change and no extra base fee. |
| **Klarna** | Buy now, pay later | Same: switch it on in Stripe/Mollie and it shows up at checkout — relevant for larger amounts. |
| **Adyen** | Enterprise & omnichannel, one API for nearly every method | Not integrated — would be a new provider in DesKilo (contributions welcome). |
| **Braintree** | Mobile & web drop-in UI (PayPal-owned) | Not integrated — DesKilo's direct PayPal integration already covers that ground. |

### Setting up RFID / NFC badges (owners)

Physical cards let people check in with a tap — no phone needed.

1. Open **Settings → RFID / NFC badges** (owner only). Switch **Enable NFC badge check-in** on, and read the **device status** line — it distinguishes *ready*, *NFC turned off in Android settings*, and *no NFC hardware* (iPads have none).
2. Give each member a card: **Members & plans → the member → Badges → Register card**, then hold their card to the device. Any card with a readable chip works (MIFARE, NTAG…). Members can also do it **themselves**: **Settings → My badge** mints their printable QR badge and registers their own card — no admin needed.
3. Use them at a **kiosk** (§9): the member taps the card to reserve or check in. Revoke a lost card from the same Badges dialog; **swipe a revoked badge to the right to delete it** for good.

Badges belong to **one workspace** — the dialog names which one you're registering into, so register the card under the workspace whose kiosk will read it. The same physical card can serve you in several workspaces. A badge QR saved **as PDF** prints ten credit-card copies on one A4 page — spares included.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

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
- **Invoices**: where the workspace issues invoices (below), yours are always available under **Money → Invoices** — tap one to read it in the app (positions, balance, status), download the PDF, and in EU workspaces export the machine-readable e-invoice (XML).
- **Paying**: DesKilo tracks payments; outstanding bills show the workspace's **payment instructions** (IBAN copies with one tap, PayPal.me opens directly). Record a payment ("I paid") with its method, the **date the money moved** (defaults to today) and the **month it settles** (defaults to the running one, one step back for arrears, one forward for a prepayment) — the other side confirms. That month decides which bill and which invoice the credit lands on. If the workspace enabled **online payments** and its server is configured for it, a **Pay online** button lets the member pay the amount owed straight away — with **PayPal, a credit card (Stripe), Mollie, or Wero**, whichever the workspace enabled (several show a chooser).
- **Expenses**: bought coffee for the space? Submit the expense — another admin approves it (no self-approval) and it credits your next statement.
- **Services**: owner-defined extras (lockers, printing…) whose consumption lands on your statement after you confirm it.

### Invoicing (owners & billing admins)

*Owners issue invoices; admins too once the owner grants the **Admins issue invoices** delegation. The **Invoicing** feature sits under Money in the feature list (§7).*

An invoice in DesKilo is generated, never composed: its positions are **derived exclusively from the month's tracked data** — subscription, overage, supplements, services, packages — minus the month's payments and credits, so the bottom line **is the balance due**. Each document snapshots the workspace's and the member's postal addresses (set yours in **Settings → Address**; the workspace address is in the workspace settings) and is **digitally signed** at issue — it never changes afterwards. A **detailed annex** (the month's ledger and attendance) can be attached with one switch when issuing.

Issuers open **Money → Invoices** and land on a three-tab hub under a live summary strip:

- **To invoice** — every member whose previous month has billable data and no invoice yet, with what the month adds up to: issue per member (with a preview of the derived positions) or **Invoice all** in one sweep — which asks for confirmation first, naming the count, the month and the total. **One active invoice per member and month** — a month only becomes invoiceable again after its invoice was cancelled. The issue sheet opens on the **completed month** (the moment its numbers stop moving); pick the running month instead and it warns you, because that month can only be invoiced once.
- **Open** — issued invoices awaiting settlement, oldest first; anything waiting longer than 30 days turns red, in the card and in the summary strip. **Tap a card to read the invoice**; the buttons act on it: **Send a reminder** (records the reminder and shares the PDF with a message — the card shows *Reminded ×N*), **Mark as erroneous** (cancels the invoice for correction: it moves to the archive struck through, and a **replacement** re-derives the same month from the corrected data, referencing the original), and **Mark as paid**.
- **Archive** — closed invoices, paid or cancelled, filterable by member and month and sortable; the bar under the filters says how many invoices match and **Clear filters** brings the whole archive back. Each row carries its status, its month and its amount, with **Download PDF** right there. **Tap a row to open the invoice** — positions, balance, who it was billed to, where it stands, which invoice it replaces or was replaced by, the payment that closed it, the reminders sent, its signature — and every action it still allows, spelled out: share the PDF, export the **e-invoice (XML)**, remind, mark as paid, mark erroneous, issue a replacement.

**Marking as paid means matching a real payment.** The dialog lists the member's registered payments — recorded transfers and confirmed online payments — and you map the invoice to one of them; there is no amount to type. Paid **more**? Create a **credit note** for the excess (a credit on the member's ledger) or force-accept with a mandatory note. Paid **less**? Accept it with a mandatory note. Everyone with invoicing access is notified of paid invoices, and the owner can put an **Invoice payment** validation rule (§6) on them: the match then waits for the quorum — a reject reopens the invoice.

**A paid invoice is definitive.** Once matched it can never be cancelled, replaced or altered — corrections happen before payment, by cancelling the open invoice and issuing its replacement. A payment that did **not** cover the whole amount, accepted with a note, shows as **partially paid** rather than paid.

**Proforma.** Both hub tabs carry a proforma action: on **To invoice** it renders the month's derived positions as a quote — no number, no signature, stamped PROFORMA, and **nothing is issued**; on **Open** it re-renders the issued invoice as a payment request that cannot pass for the original. On the Open cards every action is an icon with a tooltip (cancel · proforma · reminder · mark as paid) — three labels side by side ran off the card.

**Stamps.** A cancelled invoice carries a large diagonal **ERRONEOUS** across every page of its PDF, in light grey over the content: it cannot be mistaken for a valid document on a desk or a photocopy. The same stamp says **PROFORMA** on a quote, and **COPY** on any invoice rendered by someone other than its issuer — the workspace holds the original.

**The register.** The list icon in the Invoices app bar opens a one-line-per-invoice ledger: **date · name · amount · status**, sorted by date (tap the Date header to flip the direction), with the sum at the foot, and a **year** picker once there is more than one.

**Handing the period to your accountant.** From the register, issuers export **SAF-T** — the OECD's *Standard Audit File for Tax*, the XML accounting software and tax administrations read. It covers exactly what the register shows, so picking 2026 gives you the 2026 file: the company as your own invoices state it, every customer, every invoice with its lines and totals, and the payments that settled them. Cancelled invoices stay in the file marked *annulled* — an audit file never deletes what happened. What it deliberately leaves out is the **chart of accounts**: DesKilo does not invent account numbers, because a wrong code has to be unbooked by hand. Your accountant maps the invoices onto their own accounts, which is their job and takes them a minute.

**France: the FEC.** A French workspace gets a second choice, the **FEC** (*Fichier des Écritures Comptables*) — the file an audit legally demands (art. L47 A-I du LPF). It is not XML: a tab-separated flat file of accounting **entries**, named `<SIREN>FEC<YYYYMMDD>.txt` as the arrêté requires, with the 18 mandated columns in their mandated order. Because it is made of entries it *cannot* avoid account numbers, so the export asks for them first — pre-filled with the *plan comptable général* (411 clients, 706 prestations, 512 banque) and yours to correct. Each invoice books its receivable against revenue at the **gross** amount, the credits it netted and the payment that settled it book as cash on their own dates, lettered with the invoice number. Cancelled invoices are absent: one voided before payment was never booked, so there is nothing to reverse. The *name* column follows the reader — an issuer scans member names, a member scans their own invoice numbers. Members see only what concerns them: issued, and never a cancelled one.

### Where the e-invoice has to go (EU)

The **e-invoice (XML)** action opens a sheet that answers this for the workspace's own country before handing the file over: which channel business customers expect it on, whether a platform sits in the path, and which channel public buyers use. Four models exist in the union:

- **Peppol** — an access point delivers the file to the customer; no government platform in between. Belgium's B2B mandate works exactly this way, and Peppol is how public buyers are reached across the EU (Directive 2014/55/EU makes every authority able to receive an EN 16931 invoice).
- **Accredited platforms** — France: you pick a *plateforme agréée* (the renamed PDP), it routes the invoice and reports the data to the tax administration. The public portal is a directory, not a mailbox. Public-sector invoices stay on **Chorus Pro**.
- **Clearance platforms** — Italy (**SdI**, FatturaPA), Poland (**KSeF**, FA(3)), Romania (**RO e-Factura** via the SPV, CIUS-RO): the platform receives the invoice *first* and passes it on; sending straight to the customer is not an option. Each mandates its own syntax, so the sheet warns that the EN 16931 file DesKilo exports is not the one they accept — use it for Peppol, public buyers and foreign customers, and let your platform or accountant convert.
- **No imposed channel** — Germany today: receiving has been mandatory since 2025 and issuing phases in, but an e-mail attachment is a legal e-invoice; XRechnung and ZUGFeRD are the expected syntaxes. Public sector: **OZG-RE / ZRE**, or Peppol.

**Factur-X — one file, both readers.** The e-invoice sheet offers **Factur-X (PDF)** first: an ordinary-looking invoice PDF with the machine-readable invoice *inside it* (the EN 16931 data as CII, which is what the format mandates). A human opens it and sees the invoice; a platform opens it and finds `factur-x.xml`. It is what most French and German small businesses actually exchange, and it needs no second file. The plain **XML** stays available underneath for platforms that ask for it bare.

**Sending it, without leaving the app.** The owner can register the workspace's platform in *Réglages de l'espace → Identité légale → **Plateforme de facturation électronique***: an upload URL and a token. Any platform that accepts an upload with a credential works — a *plateforme agréée*, a Peppol access point, a national platform. The token is stored server-side, never travels back to a phone, and the app can only tell you that one is set. Once configured, the e-invoice sheet leads with **Envoyer à la plateforme**: the Factur-X document goes straight out, and the invoice's detail sheet records when it left, what the platform answered and the id it gave back. Every attempt is logged — accepted, refused or undelivered — because a document that *may* have left is worse than one that failed.

DesKilo still transmits nothing on its own account: it produces the document and hands it to the platform you chose.

**Rehearsing without risk.** A workspace can additionally register **test endpoints** (the platform's UAT or a dev target) next to the production one. With the workspace's **developer mode** on (a workspace-wide setting only owners and admins can flip, under Settings → Advanced), sending offers the choice of environment, a test submission is marked as such on the invoice's transmission history, and the production endpoint is never used for a rehearsal — an unconfigured test environment simply refuses instead of falling back.

**Before the first export, fill in the legal identity.** In *Workspace settings → **Legal identity & e-invoicing*** the owner declares the **VAT regime** and the number the norm demands with it: outside the scope of VAT, a **company registration number** (SIREN, HRB, CIF…); VAT-exempt under a small-business scheme, a **VAT number** plus the reason no VAT is charged. Members add their **country** — and their VAT number if they invoice as a business — beside their address in *Settings → Address*. DesKilo checks all of this **before** producing the file and refuses with the missing item named, because an invoice a platform rejects is worse than no invoice. A **VAT-charging workspace** exports like any other, as long as it has set up its **VAT rates** (next section): with rates in place the invoice carries a real breakdown, and until then DesKilo refuses rather than declare a zero it does not believe.

Mandate calendars keep moving: check your own tax administration before the deadline that concerns you.

### VAT (owners)

**Prices in DesKilo include VAT.** What you type as a subscription price, a service price or a day-pack price is what the member pays. Turning VAT on does not change a single amount anyone owes — it says how much of that amount is tax. That is why a bill, a statement and a quota never move when you add rates, and why no total ever needs reconciling.

**Setting the rates.** *Workspace settings → Legal identity & e-invoicing → **VAT rates***. An empty list means VAT is off, which is how every workspace starts. **Use the usual rates** fills the list with your country's standard, intermediate and reduced rates as a first draft — a starting point, not tax advice: rates move, and which supply falls under which rate is a question for your accountant. One rate is the **default** (the star): subscriptions, overage, supplements and adjustments use it, and so does every service that has none of its own. Removing a rate never deletes it — one an invoice or a service still refers to is kept, deactivated, so nothing is silently re-taxed.

**Per-item rates.** A service (*Services*) and a day pack (*Billing → Packages*) each carry their own rate, picked in their editor; leave it on **Workspace default** and it follows the default rate. The VAT field only appears once the workspace has rates — a workspace that charges none never sees it.

**What it changes on a document.** An invoice issued after the rates exist carries the breakdown as issued: the positions table gains a rate column, and above the total the PDF shows the **net** and one line per rate. The invoice's own sheet in the app shows the same. The **e-invoice (XML)** carries what EN 16931 requires — one tax subtotal per rate, the tax-exclusive amounts, the seller's VAT number (BR-S-02) — in both UBL and CII, so a Factur-X document is valid for a VAT-charging seller too. **SAF-T** declares each rate in its tax table and books every line net with its tax beside it; the **FEC** books the receivable gross against revenue net plus a **collected VAT** account (445710 by default, and yours to change — in the export dialog, or once and for all in the legal-identity screen).

**An invoice already issued never changes.** It carries the rates, the identity and the amounts it was signed with — that is what makes it an invoice. Adding rates today does not put VAT on last month's document, and completing your legal identity today does not put your registration number on it either. If a document has to carry the new figures, mark it **erroneous** and issue a **replacement**: the correction chain is visible on both documents, which is exactly what an audit wants to see.

## 9. Kiosk mode (wall tablet)

Mount an Android tablet or iPad by the door and let people check in as they walk in:

1. The owner creates a normal account for the device, joins it to the workspace, and flags it as a **kiosk** in *Members & plans*.
2. **Kiosk mode never starts by itself.** On every app start the tablet asks *Start kiosk mode?* — confirm and the pad locks down: full-screen floor plan only, back button disabled, the app pins itself so nothing else can be opened; leaving kiosk mode means restarting the tablet. Choose *Not now* instead and the app opens normally — useful for setup. The kiosk designation itself can be reverted at any time: on the device under **Settings → Kiosk device**, or by the owner in *Members & plans*.
3. Each member carries a **badge** — minted by an admin (*Members & plans → Badges*) or by the member themselves (**Settings → My badge**, §7): a printable **QR badge** and/or their **RFID/NFC card**.
4. At the kiosk, tap a seat (or **This level**) → **Check in**, **Reserve**, or **Check out** → present the badge:
   - **Tap the RFID/NFC card.** While the card reader is armed the camera stays down; if NFC is off or absent, the sheet says so explicitly.
   - Or tap **Scan the QR badge** — the tablet reads the printed badge **with its own camera** (front camera by default, since a wall tablet's back lens faces the wall; switch in *Settings → Scan with the front camera*). A USB/Bluetooth wedge scanner or typing the code works too.
5. **Nothing happens without your say-so:** the kiosk identifies the badge, closes the readers, and shows a summary — *who* it recognized, *what* will happen, *where* and *when*. Only **Confirm** executes and refreshes the plan; **Reject** discards.

Your identity exists only for the moment of the operation: the credential is sent once to the server, the booking is made **in your name**, and nothing is stored on the tablet — you are "signed out" the instant it completes. (Per-operation Google sign-in is still on the roadmap; **iPads have no NFC**, so there the camera QR path is the way.)

## 10. Notifications

Check-in reminders, pending confirmations, expense decisions — and when an admin **removes one of your reservations** (overrule), you and the admins are notified. Delivery is local-first; server pushes arrive out of the box on Android, iPhone/iPad, the browser and macOS (Firebase Cloud Messaging) — *Settings → Advanced* shows whether push is active on this device. The app-icon badge shows your pending-confirmations count — on Android, iPhone/iPad, the macOS Dock, the Windows taskbar, and installed web apps. Pushed payloads never carry names or times; the app builds the notification text locally.

## 11. Privacy

Minimal data: name, email, plan, bookings, ledger. You control your photo, your status, whether your name shows on the floor plan, and whether your phone number is visible in the directory. Kiosk badges are stored only as hashes — a lost badge is revoked, not guessed. No tracking, no third-party analytics. Financial history is anonymized, not deleted, on account erasure (bookkeeping retention).

## 12. Platforms

Android (Google Play), iPhone/iPad, desktop — **macOS** (a DMG: drag DesKilo into Applications) and **Windows** (an MSI installer) built from every release — and the **browser**: the same app, nothing to install, at the address your workspace publishes. Your data follows your account, so a desk booked on a phone shows up in a browser tab a second later.

What the browser cannot do is what a page is not allowed to do: read an NFC badge, or scan a QR code with a camera the way the kiosk does. Everything else — plan, bookings, members, money, invoices, PDF downloads — is the same app. On first launch of the macOS DMG, right-click the app and choose *Open*: the build is not yet notarised by Apple, so a plain double-click gets a Gatekeeper warning.
