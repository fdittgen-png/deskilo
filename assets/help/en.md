# User Guide

Everything a member, admin, or owner needs to use DesKilo.

> The screenshots in this guide show the app in French — every screen exists identically in all five languages (English, Français, Deutsch, Español, Italiano); switch in **Settings → Language**.

![](assets/help/images/settings-language.jpg)

## 1. Getting started

### Create an account

Open the app and sign up with your email, a password (8+ characters), and a display name — or **continue with Google**. You can show or hide the password while typing with the eye button, and *Forgot password?* sends a reset link. A Google sign-in can later be attached to an existing email account under **Settings → Linked accounts**.

### Create a workspace — or join one

After signing in you land on the welcome screen with two paths:

- **Create a workspace** — you become its **owner**. Pick a name, country (drives the default currency), and time zone. You'll then draw your floor plan in the editor (§8).
- **Join a workspace** — type the **workspace ID** someone shared with you, or tap **Scan QR code** and point the camera at the invite QR pinned to your space's wall. You join with the role the invite carries (§2).

### Profiles — one account, several spaces

One account can belong to several workspaces. **Settings → Profiles** lists them all: each row shows the space's name, **your role there** (Member, Admin, Owner) and its workspace ID. The **check mark** marks the profile you are currently in; the **star** marks your **default** — the profile the app opens with, on every device and even after a reinstall (the choice is stored with your account). Tap a row to switch, **+ Add a profile** to join yet another space. Everything in the app is scoped to the active workspace.

### Finding your way around

The app has five destinations along the bottom: **Plan** (§3), **Calendar** (§5), the big central **Reserve** button (§4), **Members** (§6) and **Finances** (§9). Two icons live in every header: the **bell** opens the events & confirmations feed (§7, with a badge counting what awaits you) and the **gear** opens **Settings** (§12). On phones held sideways and on tablets, most screens switch to a **split layout** — controls in a side panel, content filling the rest.

**Everything stays live.** Whatever anyone changes — a booking, a new member, a setting — is pushed to every connected device within seconds, including the one that made the change. No restart, no pull-to-refresh.

## 2. Roles & invitations

DesKilo has three additive roles, plus a device account:

| Role | Can |
|---|---|
| **Member** | Check in/out, reserve, submit expenses, see and manage their own events and ledger |
| **Admin** | Everything a member can, plus: act *for anybody* (reservations, payments, expenses — subject to confirmation, §7), approve expenses, issue kiosk badges |
| **Owner** | Everything an admin can, plus: edit the physical workspace, define plans and prices, manage roles, kiosk devices, and workspace settings |
| **Co-owner** | *Active*: the owner's permissions right now, plus automatic succession. *Passive*: a successor-in-waiting with no extra permissions today |
| **Kiosk** | A wall-mounted tablet account (§10) — shows the plan only; real members act through it with a badge |

Which role may do what is not carved in stone: the owner tunes it in the **Role management** matrix (§8).

**Every invitation is bound to a role.** On the owner's *Workspace ID & QR* screen two tabs hold two invites, each with its own QR code and code:

- **Member invite** — the workspace ID itself, shown under the workspace's name. Print it, pin it to the wall, share it freely: whoever scans or types it joins as a plain member. Buttons: **Copy ID**, **Share as PNG**, **Change the workspace ID** (replace the generated ID with a memorable one, 4–20 letters/digits) and **Invite someone**.
- **Admin invite** — a **personal, single-use code**, minted by an owner for one specific person. The screen says it plainly: *this code admits ONE person as an admin, then expires* (unused codes lapse after 14 days). Hand it only to the person it is meant for; mint a new one per admin with **New admin code**.
- **Invitations speak the invitee's language** — the invite sheet writes the message in the language you pick (five available), defaulting to the **workspace language** set in *Workspace settings*. The owner can also customize the invitation text **per language** there, with placeholders like `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; a language left empty uses the built-in translated message.

**There is no owner invite — by design** (the screen's footer reminds you). Ownership can only be granted by an existing owner, in *Members & plans*. A workspace always keeps at least one owner. Promoting or demoting an **admin** goes through the validation flow (§7) — it applies once the workspace's validators confirm.

**Co-owners keep the workspace alive.** The owner appoints any member or admin as a co-owner (*Members & plans → the member → Co-ownership*), in one of two flavors: an **active** co-owner works with the owner's permissions immediately; a **passive** co-owner has no extra permissions until the day they are needed. Either way, succession is automatic: if the last owner leaves — exits, is removed, or their account disappears — the best co-owner (active before passive) **becomes owner instantly**, on the server, with no action required. The owner can also hand over deliberately at any time with *Promote to owner now*. One nuance: validation rules that demand the *owner's* sign-off (§7) always mean a literal owner, not an active co-owner.

The QR encodes a link that names the role it grants (`deskilo://join?role=…`). Tampering with the link changes nothing — the server derives the role from the code itself: the workspace ID always joins as a member, and a personal invitation joins in exactly the role it was minted with, once. A forwarded admin code that was already used — or expired — admits nobody.

**Inviting someone by message** (*Invite someone*): each WhatsApp/SMS/share send mints its own personal single-use code and builds a ready-made message in the invitee's language. The recipient can simply copy the whole message and paste it into the app's join field — the code is detected automatically.

## 3. The floor plan (Plan tab)

The plan shows the active level of your space: offices, desks, and seats, color-coded — **free**, **reserved**, **occupied**, **mine**, **blocked**. It opens **instantly from the last known data** and refreshes in the background — on flaky Wi-Fi you still see the most recent state instead of a blank screen. Occupied seats show who's there by first name, a **check badge** when they are checked in, and a **green dot** when they are online in the app right now. When a **whole table, room or floor** is reserved, the space itself says so — a coloured wash, a strong border, and a **lock chip with the occupant's name** in the middle (a checked-in glyph once they're there); the room's label reads *Bureau 2 · Florian*. Every user sees it, on the plan, in the Reserve hub and on the kiosk.

The plan can look like your real space: the owner can put a **photo of the room as the level background** and place freely **resizable illustration images** (plants, sofas…) on the grid. A **desk transparency** slider in the workspace settings lets the photo show through the drawn desks.

Getting around:

- Along the top: a **map / list** toggle (the list shows the same seats as rows), the **date chip** (tap to browse another day) and three **day-part chips** — morning, afternoon, full day — filtering what the plan shows.
- The canvas **auto-fits** your floor when it opens or when you rotate the device; **pinch to zoom** or use the **+ / −** buttons, drag the **scrollbars** along the edges, and tap the **fit** button to re-centre.
- Pick the floor from the **level rail** on the right (1, 2, …); its **layers icon** acts on the whole level (below). In **landscape**, the controls move into a side panel so the plan fills the screen — handy on tablets.

Booking from the plan:

- **Walk-up check-in**: tap a free seat → the sheet suggests *now* until the workspace default end → confirm. If someone reserved that seat later, your end time is capped and you're told.
- **Check-in on a reservation**: checking in means *you are there* — the window opens **15 minutes before** your start and closes when the reservation ends. Outside it the check-in button is disabled and tells you when it opens; browsing a future time never offers a live check-in. Admins can check in a member standing at their seat (while *booking for others* is on).
- **Check-out**: manual — or, when the owner enables **auto check-in/out**, forgotten reservations complete themselves at day's end: never-touched bookings count as attended from their start to their end, and forgotten check-outs close at the reservation's own end.
- **Whole spaces**: **double-tap** a desk, a room, or an empty stretch of floor — or tap the **layers icon** on the level rail — to act on the **whole table, office or level**: the sheet names the level, shows the period (e.g. *Thu, Aug 6 10:13 → 12:00*), lets admins pick **For the member** (yourself or someone else) and confirms with **Reserve the level**. Same period picker and repetition options as a seat.
- **Time scroller**: pick a from→to window (or Morning / Afternoon / Full day, depending on the workspace granularity) to see occupancy at any future moment.
- Seats can carry **accessories** (monitor, standing desk…), some with a per-half-day supplement that shows up on your statement.
- Bookings count against your **monthly days** (§9) — the app blocks or bills you past your plan, depending on what the owner configured for you.

## 4. Reservations (Reserve hub)

Open the **Reserve** hub (center button). Along the top: the four **view buttons**, the **date chip**, the **QR scan** button (below, §4a), the **day-part chips** (morning / afternoon / full day) and the **floor chips** (*All floors*, or one per level). Then four views:

- **Plan** — the floor plan filtered to your chosen window; tap a free seat to book it.
- **Day** — every seat as a timeline row for the selected day (08:00 → 17:00 or your workspace's hours, the red line marking *now*); tap a free stretch to book, tap your own block to see its details.
- **Week** — a seat × day grid for the whole ISO week, a day strip (*Mon 3 … Sun 9*) on top; each cell holds the day's half-day slots with the occupant's initial. Find a free half-day at a glance and tap it to book.
- **Month** — an availability calendar: every day shows its **free-desk count** (e.g. *10/12*); tap a day to drop into its Day view.

**One place at a time**: you can hold only one active reservation per time window — booking or checking in somewhere else while one is running is refused, and checking in closes any earlier check-in whose booking already ended. Admins and owners can **overrule**: tapping an occupied or reserved seat offers *Remove reservation (overrule)* — the reservation is removed and the member and all admins are notified through the events feed.

Reservations follow the workspace **granularity rule** (§8 Availability) — half-days, full days, real hours (exact from–to times with the half/full-day windows as shortcuts), or free start/end times on the owner's slot grid. Half and full days cover the workspace's configured **working hours** (default 8:00–17:00 with the half-day boundary at 12:00). They respect the **open weekdays** and **closure days**, and the booking rules (advance horizon, max duration, cancellation deadline). Repeating needs? Book a **series** (daily, weekdays, weekly) — closed days and conflicts are skipped and reported.

**Deleting a past or checked-in booking is a request, not an action.** A booking whose start has passed — or where you already checked in — cannot be cancelled directly: the sheet offers **Request deletion** instead. An owner or admin decides the one question that matters for billing: was the check-in simply forgotten (the booking stays on the record), or was it never used (it is removed)? The request appears on the Events feed with your optional reason; future untouched bookings keep the normal one-tap cancel.

### 4a. Scan a space code

Every seat, desk, office and level can carry a printed **QR card** (§8). Tap the **scan button** in the Reserve hub, point the camera at the card — or type its code — and the app identifies the space and shows exactly what *you* may do there:

- **Seat card** — reserve or check in on that exact seat, on the spot (today's window: morning / afternoon / full day where the workspace uses half-days, otherwise from now for the next hours).
- **Desk card** — the desk's seats with their live state; pick a free one.
- **Office or level card** — if the owner made it reservable, the *Office & level reservations* feature is on **and** you hold the personal right (§8) — owners and admins always do — you can reserve or check into the **whole office or floor** — with the same period picker (morning / afternoon / full day, or free times) and **series** options as a seat; its price per half-day is shown and lands on your bill. Otherwise the sheet tells you why, and an office falls back to its seats.

**Conflicts protect both directions:** an office or level cannot be reserved while any seat inside is already booked in that window — and no seat can be booked while its office or level is reserved as a whole.

## 5. Calendar (Calendar tab)

The month at a glance, with two scopes and two shapes:

- **Mine / Everyone** — your own bookings, or the whole community's. The dots under a day tell you at a glance: **red** = you have a booking, **blue** = other members do, **both dots** = both. Today is ringed.
- The **shape toggle** beside it switches the lower half between a **week grid** (seats × days, like the Reserve hub) and an **agenda list** (each reservation as a card: time window, member, space).
- The **floor chips** (*All floors* / per level) filter both shapes.
- Tap a day in the month grid to load it below. In landscape the calendar and the detail use the split layout.

## 6. Members directory (Members tab)

See who's part of your community:

- Each member card shows their **photo** (or initial), **role chip** (Admin, Owner), **custom status** ("in Berlin till Friday…"), an **online / last-seen** indicator (*Online*, *10 min*, *2 d*) and a **reservation chip**: checked-in seat, *Reserved now*, or next upcoming reservation.
- Tap a member for their **detail sheet** — role, presence, their **upcoming reservations**, and **Messages**.
- **Messages**: a per-member **conversation thread** (up to 500 characters per message) — open it from the member's sheet or their directory profile, read the whole exchange as chat bubbles and send from the same place. Every message is delivered as a push and a notification with your name and text. In *Settings*, once you share a WhatsApp number, you can also opt to **receive your messages on WhatsApp**: the text arrives as the messenger reads it, each reservation/space reference as a tappable web link, plus a DesKilo link that **opens the app directly on the conversation**. The full text is always readable under **Events → Messages**, for the recipient and the sender (the push itself carries no content, by privacy design). Admins get a **Notify all admins** megaphone in the header that reaches every admin including the owner. Toggleable via the *Member notifications* feature. While composing, two chips let you **link a reservation or live check-in — yours or any other member's** — or **a space** (seat, table, room or level) — the reference shows as a tappable link on both sides: a reservation link opens that reservation, a space link opens the space’s booking sheet, perfect for discussing a future booking.
- The **message icon** on a card messages that member on **WhatsApp** (if they shared their number); the **group button** opens your community's WhatsApp group (set by the owner).
- Set your own photo, status, and phone visibility in **Settings** (§12).
- Admins and owners additionally see each member's **email** under the name — plain members don't: member-to-member contact stays the opt-in WhatsApp number.

## 7. Events & confirmations (bell icon)

The events feed is the audit trail of your workspace: reservations created/changed/cancelled, payments recorded, invoices paid, expenses submitted, extra-days requests, role changes, deletion requests. Members see their own events; admins and owners see everyone's. **Filter chips** (All · Reservation · Payment · Expense · …) narrow the list; each row carries its status icon — an **hourglass** while pending, a **green check** once confirmed — and money events show *who validated them and when* right on the row.

**Waiting for your confirmation:** whenever an admin does something *for somebody else* — books a seat for you, records your payment, demotes an admin — it stays **pending until confirmed**. Pending items are pinned on top with a red ✕ and a green **Accept** button, and you get a notification. Actions you take on yourself never need confirmation.

**Messages:** the bell also collects your member notifications (§6) — received and sent, newest first. The list shows only the **first 64 characters**; **tap a message** (or **swipe right**) to open the **conversation** with that member — the complete exchange as chat bubbles, emojis and reference links live (a reservation link opens that reservation, a space link opens the booking sheet — each with a *Show on plan* jump), with the composer right below; a broadcast opens as a single full message instead. **Swipe left** to delete a message (a long-press on a bubble deletes from the thread too) — deleting always **asks for confirmation** first (a received all-admins broadcast can't be deleted — it would vanish for every admin).  **Unread messages are bold with a dot**; the **Unread** chip — or the badge toggle at the top of the bell screen, which sets everything else aside — filters the list to them, and a message counts as read when you open its **conversation** — glancing at the inbox is not reading. Your own messages carry a small check next to the time: **grey = delivered**, **blue = read** by the recipient (a broadcast to all admins stays grey — it has many readers). Unread messages count on the bell and on the app icon until you open this screen.

**Validation quorum:** for money matters and role changes the owner defines *who* must approve and *how many* approvals are needed. **Nobody validates their own event** — only another person can; where no other validator exists, the request simply waits. Unanswered requests expire after 7 days — nothing costly is ever granted silently, and nothing is self-granted.

The owner tunes this per **domain** in **Settings → Validation rules** — one card per event type, each inheriting from the **default rule** until edited: *Default rule, Payment, Expense, Service, Extra half-days, Reservation deletion, Role change, New member, Reservation, Whole-space reservations, Invoice payment, Adjustment* — and the invoice **write-off** requests ride the same framework. A rule sets the number of required validations, *which* admins may validate (all, or named ones), and whether the owner must always sign off.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*Left: one rule per domain, inheriting from the default. Right: editing a rule — required validations, allowed validators, owner sign-off.*

## 8. For owners: the editor & settings

All administration lives under **Settings → Administration** — *Coworking space* (the workspace settings), *Members & plans*, *Role management*, *Billing & reports* (the invoicing hub with the report editor and reminder rules in its header), *Accessories*, *Availability*, *Features*, and the feature-gated entries (Online payments, RFID/NFC badges…). One rule to know: **a feature's settings entry only appears while that feature is enabled** — switch *Online payments* off in **Features** and its configuration screen disappears with it (and comes back when you re-enable it). The **Features** entry itself is always there, so you can always switch a module back on.

![](assets/help/images/settings-administration.jpg)

### The space editor

Open the **editor** from the Plan tab's app bar (crossed tools icon). The **Space editor** screen lists your floors — drag to reorder, the **layers icon** marks a level *Bookable as a whole*, the **⋮ menu** renames or deletes, **+ Add a floor** extends the building. Open a floor to draw it on the grid with the bottom toolbar — **Select · Office · Table · Seat · Image · Erase**:

- An **office** gets a name, an optional *Bookable as a whole* switch and a **price per half-day**.
- A **table** gets a name and the same whole-table option.
- A **seat** gets a name, a **seating direction** (↑ → ↓ ←), an optional **chair type**, its **accessories** (each may carry a per-half-day supplement) and a **Blocked (maintenance)** switch.
- **Image** places a resizable illustration; the photo icon in the app bar sets the level's **background photo**.
- Deleting anything with future reservations makes you resolve them first.

### Workspace ID & QR

Your role-bound invites (§2): member invite = the workspace ID (replace it with a memorable one, copy it, share the QR as PNG), admin invite = single-use personal codes.

### Availability

- **Open weekdays** — chips Mon…Sun.
- **Booking granularity** — one of: *free time range*, *5 / 15 / 30 / 60-minute slots*, *half-days (morning & afternoon)*, *full days only*, or *real hours* (exact from–to, with half/full-day shortcuts).
- **Working hours** — day start, half-day boundary, day end (default 08:00 / 12:00 / 17:00). Half-day and full-day slots everywhere — reservations, check-in and billing — follow these hours; under *real hours* you also set how many hours bill as a half and a full day.
- **Closure days** — dated exceptions, added with **+**.

### Features

Switch whole modules on or off per workspace — each toggle carries its description right on the screen: calendar tab, events tab, finances tab, services, accessory supplements, online payments, invoices, admins issue invoices, PDF export, series booking, booking for others, push notifications, admins may block seats, table/desk & level reservations, admins may assign levels, kiosk mode, RFID/NFC badges, members directory, WhatsApp integration, space QR codes, co-owners, auto check-in/out, data export (Excel), working hours, invoice PDF template, member notifications, document library, payment reminders (dunning), member reports, booking deletion requests, role management. Switching a module off removes *all* of its screens and buttons for every member.

The list is **hierarchical**: a feature that needs another sits indented under it with a *Requires…* note, and is greyed out while its parent is off — *Finances* carries services, supplements, online payments and invoicing; *Invoices* carries the admin delegation, the PDF template and the payment reminders; *Kiosk mode* carries RFID/NFC badges; *Members directory* carries the WhatsApp integration. Switching a parent off takes its whole subtree out of the app; the child's stored choice comes back untouched when the parent returns.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

### Members & plans

Tap a member to open their **management sheet** — every per-member action in one place: **Send the financial agreement** (§11d), **Messages**, **Add a service** (service, quantity, billing month → *submit for confirmation*), **Subscription** (their percentage), **When the days run out** (the over-consumption policy, §9), **Reservation limit** (simultaneous bookings cap), **May reserve a whole table, desk or level**, **Badges** (§10), **Name admin** (validated, §7), **Co-ownership**, **Turn into a kiosk**, and **Pause the membership**. Each row shows the member's **email** under the name.

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

### Billing

- **Fee tiers** — the price ladder behind percentage subscriptions: each tier says *from X %*, *up to Y %*, the monthly **fee** and the per-extra-half-day **overage rate**. **+ Add a tier** extends the ladder.
- **Subscription levels** — which percentages members may pick (chips: 25 % · 50 % · 75 % · 100 %, plus your own values), and an optional **negotiated free value** switch.
- **Day packages** — a number of days for a price (name · days · price), each with its own enable toggle; members on the *packages* policy buy them when their days run out.

### Services and Accessories

The catalogs behind §9 — owner-defined extras (lockers, printing…, each with a price and optional VAT rate) and per-seat equipment with optional per-half-day supplements. Both are plain lists with a **+** button.

![](assets/help/images/billing-bands-levels-packages.jpg)

 

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

 

![](assets/help/images/accessories-catalog.jpg)

### Workspace settings (Coworking space)

The workspace's own screen, top to bottom:

- **Identity** — name, country, currency (proposed from the country, editable), time zone, **workspace language** (invitations default to it; *sender's app language* is an option) and the postal **address** printed on invoices.
- **Payments & billing** — the **payment instructions** members see on an unpaid bill (IBAN, PayPal.me link, Wero phone number, Lydia, Wisetag, payment reference hint — leave a field empty to hide it), and **Legal identity & e-invoicing** (§11a).
- **WhatsApp group** — the community group link shown in the directory.
- **Invitation message** — the per-language invitation templates (§2).
- **Table transparency** — the slider that lets a background photo show through drawn desks.
- **Invoice PDF template** and **Reminder rules** — shortcuts to the report editor and the dunning configuration (§11).
- **Exports** — *Export the space (XML)* (settings + floor plan, no personal data — back it up, template it, migrate an instance), *Export the configuration (PDF)* (a full snapshot: settings, members, plan), *Workspace report* (everything about the space through the report engine's « workspace » template), *Space QR codes (PDF)* (one credit-card QR per seat, desk, office and level, ten per A4), *Export the data (Excel)* (one workbook: reservations, payments, invoices, members, plan — one tab each), *Import the space (XML)* (restores settings and floor plan; replaces the current plan). Every export lands in your device's **Downloads** folder.
- **The setup questionnaire** — <https://fdittgen-png.github.io/deskilo/setup.html>: a standalone page (Mac, PC or phone; answers save automatically in the browser) that walks a new owner through **every subject with predefined choices** — identity (country incl. Norway, currency, timezone), availability and granularity, the floor plan, all feature toggles (including VAT declarations), billing tiers and subscription levels, day packs, services and accessories, payment instructions, **legal identity and VAT** (organization type, regime, the country's usual rates — Switzerland's 3.8 % accommodation rate, Norway, the Canadian provinces, with the honest US sales-tax note —, invoice mentions, reminder rules), the role → permission matrix, the validation rule, and the members to invite. **Export the XML** and the app imports settings, accessories and floor plan directly (*Import the space (XML)*); the file's `<setup>` section carries everything else to finish the configuration. The page can also **reload** a previously exported file to continue editing.
- **Danger zone** — **Reset the workspace**: deletes all reservations, the accounting and the floor plan; keeps settings and members. Guarded by a typed confirmation.

### Space QR codes & whole-space reservations

Four steps turn "scan the code on the desk" into the daily booking flow (§4a):

1. In the **editor**, mark an office or a level **Bookable as a whole** and give it a **price per half-day** — the office property sheet, or for a level the **layers icon right on its row**.
2. Enable **Office & level reservations** in **Features** (off by default).
3. Grant each entitled member **"May reserve a whole office or level"** — owners and admins set it in the member's management sheet, never for themselves.
4. Print the cards: **Workspace settings → Space QR codes (PDF)** — cut them out and stick each card on its space.

An office reservation covers **all the desks inside it**; a level reservation covers the whole floor. Both are only possible while nothing inside is booked — and they show up as their own lines on the member's bill.

### Co-owners

Make sure the community never depends on one account:

1. Open *Members & plans → the member → **Co-ownership*** and pick **active** (owner permissions now) or **passive** (successor-in-waiting).
2. Hand over at any time with ***Promote to owner now*** — the co-owner becomes a full owner alongside you.
3. If the last owner ever leaves the workspace, the best co-owner is **promoted automatically** on the server — active before passive. This safety net works even while the *Co-owners* feature toggle is off (the toggle only hides the appointment buttons).

### Role management

One central matrix decides **which role holds which permission** — manage roles, manage members, validation policies, workspace settings, issue invoices & match payments, view finances, documents, services, approve expenses. Open it under *Settings → Administration → Role management* (its feature flag must be on):

- The **owner always holds every permission** — the row is locked.
- Whoever holds *Manage roles & permissions* edits the other rows. A **co-owner** starts with everything ("co-owner can have less" — the owner removes what they want); an **admin** starts with today's admin abilities; a **member** with none.
- Everyone else with any permission sees the matrix **read-only**, their own role highlighted.
- An untouched matrix means the defaults — nothing changes until the owner edits it. The legacy *admin invoicing* feature flag keeps granting invoicing to admins for compatibility. The server enforces the same matrix in the invoicing RPCs (`has_permission`), so the UI and the database can never disagree.

### Setting up online payments

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

### Setting up RFID / NFC badges

Physical cards let people check in with a tap — no phone needed.

1. Open **Settings → RFID / NFC badges** (owner only). Switch **Enable NFC badge check-in** on, and read the **device status** line — it distinguishes *ready*, *NFC turned off in Android settings*, and *no NFC hardware* (iPads have none).
2. Give each member a card: **Members & plans → the member → Badges → Register a card**, then hold their card to the device. Any card with a readable chip works (MIFARE, NTAG…). Members can also do it **themselves**: **Settings → My badge** mints their printable QR badge and registers their own card — no admin needed.
3. Use them at a **kiosk** (§10): the member taps the card to reserve or check in. Revoke a lost card from the same Badges dialog; **swipe a revoked badge to the right to delete it** for good (after a confirmation).

Badges belong to **one workspace** — the dialog names which one you're registering into, so register the card under the workspace whose kiosk will read it. The same physical card can serve you in several workspaces. A badge QR saved **as PDF** prints ten credit-card copies on one A4 page — spares included.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

## 9. Money (Finances tab)

Your ledger answers *what do I owe, what am I owed* — and *how much can I still book*. In portrait the month's bill scrolls above the action buttons; in landscape the actions move into a side panel and the bill fills the rest. The **‹ month ›** header browses any month; the **PDF button** exports the visible bill (§ below).

**The bill, card by card:**

- **This month** — how many **days** your subscription includes this month, how many you've **used**, how many are **left**, with a progress bar. A booked morning counts as 0.5 days. The monthly entitlement follows the workspace's open days and your percentage — the subscription card beneath spells it out (*3 of 42 half-days used, 21 open days*).
- **Consumed services** — each service consumption with the services total.
- **Day packages** — packs bought this month.
- **Pending items** — everything still *awaiting validation* (expenses, service consumptions…), in its own amber-rimmed card: these amounts are not yet on the bill.
- **Payments & credits** — recorded payments, approved expense reimbursements, credit notes, adjustments.
- **Invoice card** — once the month is invoiced: number, state chip, total, what's paid, what remains (§9a).
- **Your account** — your real cross-month position, when there is one (§9a).
- **Balance** — settled / outstanding, and below it the **payment instructions** and **Pay online** when something is owed.

**When your days run out**, what happens is the owner's per-member choice:

- **Blocked** (default) — no more bookings; ask an admin, or request **extra half-days** right from the Finances tab (validators approve; approved days still bill at the overage rate).
- **Pay-as-you-go** — you can keep booking; each extra day bills at your fee tier's overage rate (shown on the card).
- **Packages** — tap **Buy a package** and pick one of the owner's day packs; your days increase immediately and the price lands on this month's bill.

**The actions, grouped by meaning:**

- **Pay** — **Record a payment** ("I paid") with its method, the **date the money moved** (defaults to today) and the **month it settles** (defaults to the running one, one step back for arrears, one forward for a prepayment) — the other side confirms. That month decides which bill and which invoice the credit lands on. **Pay online** (when enabled) pays the amount owed straight away — with **PayPal, a credit card (Stripe), Mollie, or Wero**, whichever the workspace enabled (several show a chooser).
- **Requests** — **Submit an expense** (bought coffee for the space? another admin approves it — no self-approval — and it credits your statement), **Request extra half-days**, **Add a consumption** (owner-defined services — lockers, printing… — you confirm what you consumed).
- **Documents** — **Invoices** (yours are always readable here: positions, balance, status — and for issuers the invoicing hub, §11), the **financial agreement** and the **monthly payments report**, self-service (§11).

### 9a. Once the month is invoiced, the invoice decides

- Your bill shows an **invoice card** — number, state, total, what's paid, what remains — and the month reads **settled** as soon as the invoice is paid, its remainder cancelled, or its credit note refunded, even when the settling payment was recorded in a later month. A **partially paid** invoice keeps the month outstanding at exactly the **remaining** amount (that's also what *Pay online* charges). A **credit note** month shows what the workspace owes you back — nothing to pay on your side.
- **Your account** — when you hold spare credit (an avoir, or payments left over from a past month), the Finances tab shows your real cross-month position above the bill: **credit on account**, every **open invoice** with its remaining amount, refunds the workspace owes, and the resulting **net position**. Your credit can settle open invoices — the workspace applies it when matching payments (imputation). Months before your membership began owe nothing and never read outstanding.

### 9b. Quick view, save, share — every report

Every report in the app — the bill, invoices, proformas, credit notes, your self-service documents — offers the same three actions: **Quick view** (see the rendered document on screen before any PDF exists), **Download PDF** (save locally) and **Share PDF** (hand it to any app — WhatsApp, mail, …).

**Reports speak the reader's language:** your documents print in *your* app language when the workspace provides it, falling back to the workspace language (§11 templates per language).

## 10. Kiosk mode (wall tablet)

Mount an Android tablet or iPad by the door and let people check in as they walk in:

1. The owner creates a normal account for the device, joins it to the workspace, and flags it as a **kiosk** in *Members & plans*.
2. **Kiosk mode never starts by itself.** On every app start the tablet asks *Start kiosk mode?* — confirm and the pad locks down: full-screen floor plan only, back button disabled, the app pins itself so nothing else can be opened; leaving kiosk mode means restarting the tablet. Choose *Not now* instead and the app opens normally — useful for setup. The kiosk designation itself can be reverted at any time: on the device under **Settings → Kiosk device**, or by the owner in *Members & plans*.
3. Each member carries a **badge** — minted by an admin (*Members & plans → Badges*) or by the member themselves (**Settings → My badge**, §8): a printable **QR badge** and/or their **RFID/NFC card**.
4. At the kiosk, tap a seat (or **This level**) — **ONE sheet** opens with everything on it: **Check in** already selected (one tap switches to **Reserve** or **Check out**), the **period already derived from the workspace settings**, and the **badge reader live** at the bottom. Under half-days, the part of the day you are standing in is preselected (Morning / Afternoon / Day chips to change it — a running window starts *now*, past ones are disabled, after hours a single *Rest of the day* remains); under timed granularities, From/To pickers snapped to the slot grid, a check-in's start pinned to *now*. The sheet **names the rule it follows** — the granularity and today's working-hours windows — so what it offers is exactly what the settings allow; on a **closed day** the kiosk says so up front with a banner instead of failing at the end. Reserving a window that has already begun also offers **Check in right away?** (on by default): one badge presentation books the reservation *already checked in*. Then present the badge:
   - **Tap the RFID/NFC card.** While the card reader is armed the camera stays down; if NFC is off or absent, the sheet says so explicitly.
   - Or tap **Scan the QR badge** — the tablet reads the printed badge **with its own camera** (front camera by default, since a wall tablet's back lens faces the wall; switch in *Settings → Scan with the front camera*). A USB/Bluetooth wedge scanner or typing the code works too.
5. **The badge IS the confirmation:** it executes immediately, and a **self-dismissing receipt** shows *who* was recognized, *what* happened, *where* and *until when* — then the wall is clean for the next member. The happy path is two gestures: tap your seat, present your badge.

Your identity exists only for the moment of the operation: the credential is sent once to the server, the booking is made **in your name**, and nothing is stored on the tablet — you are "signed out" the instant it completes. (Per-operation Google sign-in is still on the roadmap; **iPads have no NFC**, so there the camera QR path is the way.)

## 11. Invoicing (owners & billing admins)

*Owners issue invoices; admins too once they hold the **issue invoices** permission (Role management, §8 — or the legacy **Admins issue invoices** feature delegation). The **Invoices** feature sits under Finances in the feature list.*

An invoice in DesKilo is generated, never composed: its positions are **derived exclusively from the month's tracked data** — subscription, overage, supplements, services, packages — minus the month's payments and credits, so the bottom line **is the balance due**. Each document snapshots the workspace's and the member's postal addresses (set yours in **Settings → Address**; the workspace address is in the workspace settings) and is **digitally signed** at issue — it never changes afterwards. A **detailed annex** (the month's ledger and attendance) can be attached with one switch when issuing.

Issuers open **Finances → Invoices** and land on a three-tab hub under a live summary strip (*N to invoice · N open · X outstanding · N to refund · Y*):

- **To invoice** — every member whose previous month has billable data and no invoice yet, with what the month adds up to: issue per member (with a preview of the derived positions) or **Invoice all** in one sweep — which asks for confirmation first, naming the count, the month and the total. The **New invoice** button opens the same sheet for any member and month — member picker, ‹ month ›, the derived positions, the balance, the **detailed annex** switch and **Issue the invoice** (a green *Invoice issued.* snack confirms). **One active invoice per member and month** — a month only becomes invoiceable again after its invoice was cancelled. The issue sheet opens on the **completed month** (the moment its numbers stop moving); pick the running month instead and it warns you, because that month can only be invoiced once.
- **Open** — issued invoices awaiting settlement, oldest first; anything waiting longer than 30 days turns red, in the card and in the summary strip. Every action is an icon with a tooltip (cancel · proforma · reminder · mark as paid). **Tap a card to read the invoice.** **Send a reminder** records the reminder and shares the PDF with a message — the card shows *Reminded ×N*. **Mark as erroneous** cancels the invoice for correction (an explicit dialog warns the action is irreversible): it moves to the archive struck through, and a **replacement** re-derives the same month from the corrected data, referencing the original. **Mark as paid** matches a real payment (below). **A partial payment does not close an invoice**: it stays on Open, badged *Partially paid* with the remaining amount, until the outstanding remainder is explicitly **cancelled through the validation framework** — an admin/owner requests the write-off (with a reason), the validators confirm, and only then does the invoice move to the archive as *Partially paid · remainder cancelled*. **A NEGATIVE invoice is a credit note (avoir)** — the month's credits exceeded its charges, so the WORKSPACE owes the member: its PDF is titled *Credit note*, it gets no reminders and no member-payment matching; instead the card shows *To refund* with **Record the refund** — the payout books against the member's balance (validated like any settlement when a policy applies; a reject reopens it) and the document closes as *Refunded*. The summary strip separates the two directions of the payment process: *N open · X outstanding* counts positive invoices at their **remaining** value (a €500 invoice with €280 paid counts €220), while *N to refund · Y* totals the open credit notes the workspace still owes.
- **Archive** — closed invoices, filterable by member and month and sortable; cancelled invoices are **hidden by default** — the *Show cancelled* chip brings the correction trail back; the bar under the filters says how many invoices match and **Clear filters** brings the whole archive back. Each row carries its status chip (*Paid*, *Partially paid*, *Erroneous* struck through, credit notes with their negative amount), its month and its amount, with **Download PDF** right there. **Tap a row to open the invoice** — positions, balance, who it was billed to, where it stands (*Paid €300.00 on Aug 6*, *Reminded ×1 · last reminder…*, *Annex: 5 entries, 10 check-ins*), which invoice it replaces or was replaced by, its signature — and every action it still allows, spelled out: **Quick view**, **Download PDF**, **Share PDF**, export the **e-invoice (XML)**, remind, mark as paid, mark erroneous, issue a replacement.

**Marking as paid means matching a real payment — or applying a credit.** The dialog lists the member's registered payments — recorded transfers and confirmed online payments — and you map the invoice to one of them; there is no amount to type (no registered payment yet? the dialog says so: *record it or confirm it first*). It also lists the member's **account credits** (credit-note excess): matching one imputes the avoir on the invoice, past months included — the standard alternative to a cash refund, for associations and companies alike. Each credit spends exactly once: one already deducted inside an issued invoice can never settle a second document. Paid **more**? Create a **credit note** for the excess (a credit on the member's ledger) or force-accept with a mandatory note. Paid **less**? Accept it with a mandatory note. Everyone with invoicing access is notified of paid invoices, and the owner can put an **Invoice payment** validation rule (§7) on them: the match then waits for the quorum — a reject reopens the invoice.

**A paid invoice is definitive.** Once matched it can never be cancelled, replaced or altered — corrections happen before payment, by cancelling the open invoice and issuing its replacement. A payment that did **not** cover the whole amount, accepted with a note, shows as **partially paid** rather than paid.

**Proforma.** Both hub tabs carry a proforma action: on **To invoice** it renders the month's derived positions as a quote — no number, no signature, stamped PROFORMA, and **nothing is issued**; on **Open** it re-renders the issued invoice as a payment request that cannot pass for the original. Both offer the quick-view / download / share triad.

**Stamps.** A cancelled invoice carries a large diagonal **ERRONEOUS** across every page of its PDF, in light grey over the content: it cannot be mistaken for a valid document on a desk or a photocopy. The same stamp says **PROFORMA** on a quote, and **COPY** on any invoice rendered by someone other than its issuer — the workspace holds the original.

**Reminders (Mahnwesen).** The owner sets the **reminder rules** (checklist icon in the Invoices header, or *Workspace settings → Reminder rules*): how many levels, days until the first reminder, days between levels. Overdue open invoices are flagged **"Reminder N due"** and the bell icon on the card turns red — nothing is ever sent automatically. Sending generates a **payment-reminder letter** (level 1 friendly, higher levels firmer) from that level's template — shipped ready-made in your language, printed in the *member's* language, and editable per level in the report editor with the extra fields `{{ reminder_level }}`, `{{ reminder_date }}` and `{{ days_open }}`.

**The register.** The list icon in the Invoices app bar opens a one-line-per-invoice ledger: **date · name · amount · status**, sorted by date (tap the Date header to flip the direction), with the sum at the foot, and a **year** picker once there is more than one. Its export button opens the **Accounting export** sheet: **SAF-T (XML, international)** and — for a French workspace — **FEC (France, required in a tax audit)**.

**Handing the period to your accountant.** From the register, issuers export **SAF-T** — the OECD's *Standard Audit File for Tax*, the XML accounting software and tax administrations read. It covers exactly what the register shows, so picking 2026 gives you the 2026 file: the company as your own invoices state it, every customer, every invoice with its lines and totals, and the payments that settled them. Cancelled invoices stay in the file marked *annulled* — an audit file never deletes what happened. What it deliberately leaves out is the **chart of accounts**: DesKilo does not invent account numbers, because a wrong code has to be unbooked by hand. Your accountant maps the invoices onto their own accounts, which is their job and takes them a minute.

**France: the FEC.** A French workspace gets a second choice, the **FEC** (*Fichier des Écritures Comptables*) — the file an audit legally demands (art. L47 A-I du LPF). It is not XML: a tab-separated flat file of accounting **entries**, named `<SIREN>FEC<YYYYMMDD>.txt` as the arrêté requires, with the 18 mandated columns in their mandated order. Because it is made of entries it *cannot* avoid account numbers, so the export asks for them first — pre-filled with the *plan comptable général* (411 clients, 706 prestations, 512 banque) and yours to correct. Each invoice books its receivable against revenue at the **gross** amount, the credits it netted and the payment that settled it book as cash on their own dates, lettered with the invoice number. Cancelled invoices are absent: one voided before payment was never booked, so there is nothing to reverse. The *name* column follows the reader — an issuer scans member names, a member scans their own invoice numbers. Members see only what concerns them: issued, and never a cancelled one.

### 11a. Legal identity, VAT & mentions

**Before the first export, fill in the legal identity.** In *Workspace settings → **Legal identity & e-invoicing*** the owner declares:

- The **VAT regime** — it decides the number the EN 16931 norm demands: outside the scope of VAT, a **company registration number** (SIREN, HRB, CIF…); VAT-exempt under a small-business scheme, a **VAT number** plus the **reason no VAT is charged** (the field suggests the proper wording — *TVA non applicable, art. 293 B du CGI*, or for services to members of an association *Exonération de TVA, art. 261, 7-1° du CGI*). The regime is enforced end to end: only a VAT-registered workspace ever stamps a rate onto a subscription, supplement, service or package, and the VAT pickers simply disappear under any other regime.
- The structured **address** (street, postal code, city) beside the free-text letterhead address.
- The **e-invoicing platform** (§11b).
- The **invoice mentions**, with an **Organization type** switch — *Company / business* vs *Association (loi 1901)*: legal form & capital (e.g. *Association loi 1901*), trade register (companies: RCS; associations: **RNA W… · SIRET if assigned**), payment terms, late-payment penalty, the **€40 recovery indemnity**, early-payment discount (escompte), professional insurance, special mentions. Each clause prints the statutory default wording when left empty — and an association's documents drop the B2B-only clause defaults (late penalty, recovery indemnity, escompte are mandatory only between professionals; whatever you type still prints).

Members add their **country** — and their VAT number if they invoice as a business — beside their address in *Settings → Address*. DesKilo checks all of this **before** producing an e-invoice and refuses with the missing item named, because an invoice a platform rejects is worse than no invoice.

**Prices in DesKilo include VAT.** What you type as a subscription price, a service price or a day-pack price is what the member pays. Turning VAT on does not change a single amount anyone owes — it says how much of that amount is tax. That is why a bill, a statement and a quota never move when you add rates, and why no total ever needs reconciling. Under a VAT-charging regime the catalogue says so out loud: every service and day-pack row names its included rate (*incl. VAT 20 %*), the billing editor lets the owner pick the tariff's own VAT rate (default: the workspace default) and shows the VAT share inside each band amount as you type, each accessory can carry its own rate (default: the workspace default), and every price field reminds you it is gross.

**Setting the rates.** *Legal identity & e-invoicing → **VAT rates***. An empty list means VAT is off, which is how every workspace starts. **Use the usual rates** fills the list with your country's standard, intermediate and reduced rates as a first draft — a starting point, not tax advice. One rate is the **default** (the star): subscriptions, overage, supplements and adjustments use it, and so does every service that has none of its own. A service and a day pack each carry their own rate, picked in their editor. Removing a rate never deletes it — one an invoice or a service still refers to is kept, deactivated, so nothing is silently re-taxed. All of this is the *VAT management* feature toggle: switched off, the rate editor and every rate picker disappear while the stored rates keep applying — the tax math itself is never toggleable — and the *VAT declarations* toggle lives beneath it.

**The periodic VAT declaration** (*VAT rates → VAT declaration*, VAT-registered workspaces only). Pick the filing period — a month or a quarter, whatever your regime requires — and **Generate**: the app aggregates that period's issued invoices per rate **with the exact arithmetic the invoices carry**, so the return matches every document to the cent. The result shows the per-rate net base and output VAT, mapped onto your country's **official form lines** (France's CA3 boxes 08/09/9B/11, Germany's UStVA Kennzahlen 81/86, a generic per-rate list elsewhere). Every declaration exports as **PDF** and **machine-readable XML**; if an upload platform is configured under e-invoicing, **Transmit** sends it there electronically and records the acknowledgement — otherwise take the numbers to your tax portal (EFI, ELSTER…) or your accountant and **Mark as filed**. Either way the declaration becomes immutable, with its channel and receipt on record. The catalogue of suggested rates covers every EU member state, Switzerland (including the 3.8 % accommodation rate), Norway and the Canadian provinces; the US has no federal VAT, so the app says so instead of guessing. A filing aid, not tax advice — verify with your accountant.

**What it changes on a document.** An invoice issued after the rates exist carries the breakdown as issued: the positions table gains a rate column, and above the total the PDF shows the **net** and one line per rate. The **e-invoice (XML)** carries what EN 16931 requires in both UBL and CII; **SAF-T** declares each rate in its tax table; the **FEC** books the receivable gross against revenue net plus a **collected VAT** account (445710 by default, yours to change).

**An invoice already issued never changes.** It carries the rates, the identity and the amounts it was signed with — that is what makes it an invoice. If a document has to carry new figures, mark it **erroneous** and issue a **replacement**: the correction chain is visible on both documents, which is exactly what an audit wants to see.

### 11b. Where the e-invoice has to go (EU)

The **e-invoice (XML)** action opens a sheet that answers this for the workspace's own country before handing the file over: which channel business customers expect it on, whether a platform sits in the path, and which channel public buyers use. Four models exist in the union:

- **Peppol** — an access point delivers the file to the customer; no government platform in between. Belgium's B2B mandate works exactly this way, and Peppol is how public buyers are reached across the EU (Directive 2014/55/EU makes every authority able to receive an EN 16931 invoice).
- **Accredited platforms** — France: you pick a *plateforme agréée* (the renamed PDP), it routes the invoice and reports the data to the tax administration. The public portal is a directory, not a mailbox. Public-sector invoices stay on **Chorus Pro**.
- **Clearance platforms** — Italy (**SdI**, FatturaPA), Poland (**KSeF**, FA(3)), Romania (**RO e-Factura** via the SPV, CIUS-RO): the platform receives the invoice *first* and passes it on; sending straight to the customer is not an option. Each mandates its own syntax, so the sheet warns that the EN 16931 file DesKilo exports is not the one they accept — use it for Peppol, public buyers and foreign customers, and let your platform or accountant convert.
- **No imposed channel** — Germany today: receiving has been mandatory since 2025 and issuing phases in, but an e-mail attachment is a legal e-invoice; XRechnung and ZUGFeRD are the expected syntaxes. Public sector: **OZG-RE / ZRE**, or Peppol.

**Factur-X — one file, both readers.** The e-invoice sheet offers **Factur-X (PDF)** first: an ordinary-looking invoice PDF with the machine-readable invoice *inside it* (the EN 16931 data as CII, which is what the format mandates). A human opens it and sees the invoice; a platform opens it and finds `factur-x.xml`. It is what most French and German small businesses actually exchange, and it needs no second file. The plain **XML** stays available underneath for platforms that ask for it bare.

**Sending it, without leaving the app.** The owner registers the workspace's platform in *Legal identity → **E-invoicing platform***: an **upload URL**, a **token or credential**, optionally the **Authorization header** shape and the **file field name**. Any platform that accepts an upload with a credential works — a *plateforme agréée*, a Peppol access point, a national platform. The token is stored server-side, never travels back to a phone, and the app can only tell you that one is set. Once configured, the e-invoice sheet leads with **Send to the platform**: the Factur-X document goes straight out, and the invoice's detail sheet records when it left, what the platform answered and the id it gave back. Every attempt is logged — accepted, refused or undelivered — because a document that *may* have left is worse than one that failed.

**Rehearsing without risk.** The same screen takes **test endpoints** (the platform's UAT or a dev target: URL + token each) next to the production one. With the workspace's **developer mode** on (a workspace-wide setting only owners and admins can flip, under Settings → Advanced), sending offers the choice of environment, a test submission is marked as such on the invoice's transmission history, and the production endpoint is never used for a rehearsal — an unconfigured test environment simply refuses instead of falling back.

DesKilo still transmits nothing on its own account: it produces the document and hands it to the platform you chose. Mandate calendars keep moving: check your own tax administration before the deadline that concerns you.

### 11c. The report editor — every document, four presets, five languages

The **Invoice PDF template** (pencil icon in the Invoices header, or *Workspace settings*) is a banded reporting tool for every document the app prints. Three report **bands** render onto the PDF — header, body (the invoice lines), footer — while the e-invoice XML is never touched.

- **One report per document**: chips switch between **Invoice · Proforma · Statement · Agreement · Payments · Workspace · Reminder levels**. The proforma falls back to the invoice bands until you customize it; a customized statement replaces the built-in monthly-bill PDF.
- **Per language**: a second chip row — *Default (all languages)* · EN · FR · DE · ES · IT — stores a translation overlay per document; a member's report prints in *their* language when a template exists for it, else in the workspace default.
- **Markup or Visual**: the **Markup** mode edits the bands as text — [Liquid](https://shopify.github.io/liquid/) conditions and loops (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) plus a simple line markup: `#` title, `##` section, `>` small print, `---` divider, `a | b` table row, `=` bold row, `::: … ||| … :::` side-by-side columns (the seller-left / client-right address block and the right-aligned totals of a French facture — the shipped templates follow that exact structure), `![name]` an image from the workspace's **image library** (*Insert an image*). The **Visual** mode is a page-true design surface in the professional-designer tradition (Crystal Reports, Docentric): the three bands are edited **on a white A4 page** at the document's own margins, in the document's exact print typography — same font, sizes, colors and right-aligned amount columns as the generated PDF — with labeled band strips, dashed page-break guides where the PDF will paginate, and a zoom control (fit width, 75/100/150 %). `{{ tokens }}` stay highlighted; tap a line to edit it in place, add lines, move them, insert data fields from a palette. A **Design ↔ Preview** toggle merges your unsaved bands with your live (or sample) data through the real report engine on the same page — fields out, values in.
- **Templates gallery** (*Templates*): four ready-made presets for every document — **Classic · Simple · Detailed · Formal letter** — pick one and extend it. Every invoice preset already carries the statutory mentions (§11a).
- **Quick preview** renders the result instantly in the app — your newest invoice, or simulated sample data when none exists (watermarked *sample data*) — no PDF round-trip; **Preview** produces the PDF; **Reset to default** hands back the built-in layout as a working example. A broken template never blocks a document — the built-in layout takes over; the void watermark, digital signature, annex and page numbers stay fixed.

Template variables (invoice family): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (each with `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — and the legal set: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

### 11d. The report suite & the document library

- **Financial agreement** — every standing price that applies to a member: subscription, extra half-day, services, packages, whole-space and accessory supplements. Owners/admins send it from a member's action sheet; every member can quick-view/download/share their own from *Finances → Documents*.
- **Payments report** — everything you paid, declared or had validated in a month: your little balance sheet, self-service on the same row.
- **Workspace report** — identity, floor-plan counts, availability, features and prices: *Workspace settings → Workspace report*.
- **Document library** — *Settings → Documents*: the workspace's statutes, user guides, financial statements and meeting minutes, LINKED from whatever system you already use — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud or any https link (the drive keeps managing its own access; the app never stores foreign credentials). Every entry has a **visibility role**: every member, admins and owners, or owners only — enforced server-side, so a member never even downloads a list containing board documents. Admins and owners curate with the + button; a *Document library* feature toggle gates the whole thing.

## 12. Settings & profile

Your personal screen, top to bottom:

- **Profiles** (§1) and your **photo** (tap to change — pick or remove).
- **Members** — a shortcut into the directory; **WhatsApp** — your number, visible to fellow members only if you set it; **Status** — a free line (40 characters) shown in the directory; **Address** — your postal address (printed on your invoices), country and optional VAT number.
- **Help** — the built-in guide, in your language; **My badge** (§8); **Linked accounts** — attach a Google sign-in to your email account; **Documents** — the workspace's document library (§11d).
- **Preferences** — **Language** (system default or one of five), **Theme** (system / light / dark), **Scan with the front camera** (for wall tablets).
- **Advanced** — the push-notification status of this device, the workspace-wide **Developer mode** switch and the **Developer** trace screen (§8 payments).
- **Sign out**.

## 13. Notifications

Check-in reminders, pending confirmations, expense decisions — and when an admin **removes one of your reservations** (overrule), you and the admins are notified. Delivery is local-first; server pushes arrive out of the box on Android, iPhone/iPad, the browser and macOS (Firebase Cloud Messaging) — *Settings → Advanced* shows whether push is active on this device. The app-icon badge shows your pending-confirmations count **plus your unread messages** — on Android, iPhone/iPad, the macOS Dock, the Windows taskbar, and installed web apps. Member messages are announced **once per device with the sender and the full text** — including anything sent while the app was closed, announced the moment you next open it. Pushed payloads never carry names or times; the app builds the notification text locally.

## 14. Privacy

Minimal data: name, email, plan, bookings, ledger. You control your photo, your status, whether your name shows on the floor plan, and whether your phone number is visible in the directory. Kiosk badges are stored only as hashes — a lost badge is revoked, not guessed. No tracking, no third-party analytics. Financial history is anonymized, not deleted, on account erasure (bookkeeping retention).

## 15. Platforms

Android (Google Play), iPhone/iPad, desktop — **macOS** (a DMG: drag DesKilo into Applications) and **Windows** (an MSI installer) built from every release — and the **browser**: the same app, nothing to install, at the address your workspace publishes. Your data follows your account, so a desk booked on a phone shows up in a browser tab a second later.

What the browser cannot do is what a page is not allowed to do: read an NFC badge, or scan a QR code with a camera the way the kiosk does. Everything else — plan, bookings, members, money, invoices, PDF downloads — is the same app. On first launch of the macOS DMG, right-click the app and choose *Open*: the build is not yet notarised by Apple, so a plain double-click gets a Gatekeeper warning.
