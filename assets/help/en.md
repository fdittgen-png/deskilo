# User Guide

Everything a member, admin, or owner needs to use DesKilo.

> The screenshots in this guide show the app in French — every screen exists identically in all five languages (English, Français, Deutsch, Español, Italiano); switch in **Settings → Language**.

![](assets/help/images/settings-language.jpg)

## 1. Getting started

### Create an account

Open the app and sign up with your email, a password (8+ characters), and a display name — or **continue with Google**. You can show or hide the password while typing with the eye button. *Forgot password?* emails you a **one-time numeric code**, which you type back into the app together with your new password — deliberately a code rather than a link, so a reset works even where deep links don't. A Google sign-in can later be attached to an existing email account under **Settings → Linked accounts**.

### Create a workspace — or join one

After signing in you land on the welcome screen with two paths:

- **Create a workspace** — you become its **owner**. Pick a name, country (drives the default currency), and time zone. You'll then draw your floor plan in the editor (§8).
- **Join a workspace** — type the **workspace ID** someone shared with you, or tap **Scan QR code** and point the camera at the invite QR pinned to your space's wall. Your request arrives as **pending**: *New member* is one of the validation domains (§7), so a validator lets you in, and you then hold exactly the role the invite carries (§2).

### The setup questionnaire — prepare a new space before you open the app

Creating a workspace means dozens of decisions that live in a dozen different screens: what a booking may look like, what a month costs, what the law wants on an invoice, who validates what. The app lets you make them one at a time, as you meet them. The **setup questionnaire** lets you make them all at once, *before* you start — on a big screen, with your accountant or your board if that helps, without touching anything live:

<https://fdittgen-png.github.io/deskilo/setup.html>

It is a single web page. Nothing to install, no account, nothing sent anywhere: your answers are saved in your own browser, so you can close the tab and come back to them.

![](assets/help/images/setup-wizard.jpg)

*The wizard: twelve steps in dependency order, every question saying where the setting lives in the app, with a **?** that opens this guide at the matching section.*

**How you use it**

1. **Answer the steps in order** — identity, features, availability, floor plan, subscriptions, legal identity & VAT, services, payment instructions, roles & validation, members. Each step asks only what your earlier answers make possible: no VAT rates when you are not VAT-registered, no e-invoicing platform outside the EU, no day-package option for a member while no package exists, no child feature while its parent is off.
2. **Check the feature summary.** It lists every feature the app will switch on and *how your own answers configure it*. Untick what you do not want: it is exported disabled and its configuration is left out — you can always switch it on later in Settings → Features.
3. **Read the review step.** It separates what is complete, what is a choice to confirm and what actually blocks, each with a jump straight to the question that fixes it.
4. **Export the XML**, then open the app: **Settings → Coworking space → Import the space (XML)** creates the settings, the accessories and the floor plan directly. The same file's `<setup>` section carries everything the importer does not — billing, legal identity, roles, members — so you can finish those screens one by one; every question told you where its answer lives.
5. **Keep the file.** Loading it back into the page continues where you left off — including a file exported before a setting existed, which simply comes back with that setting at its default.

![](assets/help/images/setup-feature-summary.jpg)

*The feature summary: what the app will switch on, configured by your own answers — untick what you do not want.*

**One caution.** The exported file is plain text. Fill in an e-invoicing token or a payment-provider key only if you are answering privately; otherwise leave those fields empty and type the secrets in the app, where they go straight to the server and never come back.

**Skipping it costs nothing.** Every answer it collects is a setting you can also make — and change — in the app later. The questionnaire is a shortcut for the first hour, not a gate.

### Profiles — one account, several spaces

One account can belong to several workspaces. **Settings → Profiles** lists them all: each row shows the space's name, **your role there** (Member, Admin, Owner) and its workspace ID. The **check mark** marks the profile you are currently in; the **star** marks your **default** — the profile the app opens with, on every device and even after a reinstall (the choice is stored with your account). Tap a row to switch, **+ Add a profile** to join yet another space. Everything in the app is scoped to the active workspace.

![](assets/help/images/profiles.jpg)

*Profiles: every workspace your account belongs to, your role there, the star for the default, the check for the active one.*

### Finding your way around

The app has up to five destinations along the bottom: **Messages** (§16), **Calendar** (§5), the big central **Reserve** button (§4), **Members** (§6) and **Money** (§9). Messages and Reserve are always there; Calendar, Members and Money come and go with their feature (§8). **Messages is the inbox**: your conversations and the events & confirmations feed (§7) are its two faces, and the **bell** in the app bar jumps straight to the second with a count of what awaits you. The **gear** that opens **Settings** (§12) is in every header. On phones held sideways and on tablets, most screens switch to a **split layout** — controls in a side panel, content filling the rest.

**Everything stays live.** Whatever anyone changes — a booking, a new member, a setting — is pushed to every connected device within seconds, including the one that made the change. No restart, no pull-to-refresh.

**On the web: the menu button.** In a browser the bottom bar and its round Reserve button are gone — the window has the width a phone lacks and none of its thumb reach. The **☰ menu** at the top left opens a drawer with every destination one tap away: Reserve, the tabs, Events, then the administration screens (Workspace, Members & plans, Availability, Roles, Billing & reports, Payment instructions, Online payments, Badges, Services, Accessories, Billing, Features, Edit workspace) and, last, Documents, Privacy & data and Settings. The whole height stays for content. Phones and desktop apps keep the bar.

## 2. Roles & invitations

DesKilo has three additive roles and a co-ownership flavour on top of them, plus a device account:

| Role | Can |
|---|---|
| **Member** | Check in/out, reserve, submit expenses, see and manage their own events and ledger |
| **Admin** | Everything a member can, plus: act *for anybody* (reservations, payments, expenses — subject to confirmation, §7), approve expenses, issue kiosk badges |
| **Owner** | Everything an admin can, plus: edit the physical workspace, define plans and prices, manage roles, kiosk devices, and workspace settings |
| **Co-owner** | *Active*: the owner's permissions right now, plus automatic succession. *Passive*: a successor-in-waiting with no extra permissions today |
| **Kiosk** | A wall-mounted tablet account (§10) — shows the plan only; real members act through it with a badge |

Part of this is not carved in stone: the owner retunes **eleven administration permissions** in the **Role management** matrix (§8) — manage roles, manage members, validation policies, workspace settings, issue invoices, view finances, documents, services, approve expenses, view and manage commercial agreements. What the matrix does *not* govern is the everyday stuff — checking in, reserving, acting for another member, editing the space — which stays where the table above puts it, gated by the features and the per-member switches instead.

**Every invitation is bound to a role.** On the owner's *Workspace ID & QR* screen two tabs hold two invites, each with its own QR code and code:

- **Member invite** — the workspace ID itself, shown under the workspace's name. Print it, pin it to the wall, share it freely: whoever scans or types it asks to join as a plain member, and a validator admits them (§7). Buttons: **Copy ID**, **Share as PNG**, **Change the workspace ID** (replace the generated ID with a memorable one, 4–20 letters/digits) and **Invite someone**.
- **Admin invite** — a **personal, single-use code**, minted by an owner for one specific person. The screen says it plainly: *this code admits ONE person as an admin, then expires* (unused codes lapse after 14 days). Hand it only to the person it is meant for; mint a new one per admin with **New admin code**.
- **Invitations speak the invitee's language** — the invite sheet writes the message in the language you pick (five available), defaulting to the **workspace language** set in *Workspace settings*. The owner can also customize the invitation text **per language** there, with placeholders like `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; a language left empty uses the built-in translated message.

**There is no owner invite — by design** (the screen's footer reminds you). Ownership can only be granted by an existing owner, in *Members & plans*. A workspace always keeps at least one owner. Promoting or demoting an **admin** goes through the validation flow (§7) — it applies once the workspace's validators confirm.

**Co-owners keep the workspace alive.** The owner appoints any member or admin as a co-owner (*Members & plans → the member → Co-ownership*), in one of two flavors: an **active** co-owner works with the owner's permissions immediately; a **passive** co-owner has no extra permissions until the day they are needed. Either way, succession is automatic: if the last owner leaves — exits, is removed, or their account disappears — the best co-owner (active before passive) **becomes owner instantly**, on the server, with no action required. The owner can also hand over deliberately at any time with *Promote to owner now*. One nuance: validation rules that demand the *owner's* sign-off (§7) always mean a literal owner, not an active co-owner.

The QR encodes a link that names the role it grants (`deskilo://join?role=…`). Tampering with the link changes nothing — the server derives the role from the code itself: the workspace ID always joins as a member, and a personal invitation joins in exactly the role it was minted with, once. A forwarded admin code that was already used — or expired — admits nobody.

**Inviting someone by message** (*Invite someone*): each WhatsApp/SMS/share send mints its own personal single-use code and builds a ready-made message in the invitee's language. The recipient can simply copy the whole message and paste it into the app's join field — the code is detected automatically.

## 3. The floor plan (in the Reserve hub)

The plan shows the active level of your space: offices, desks, and seats, color-coded — **free**, **reserved**, **occupied**, **mine**, **blocked**. It opens **instantly from the last known data** and refreshes in the background — on flaky Wi-Fi you still see the most recent state instead of a blank screen. An occupied seat shows who's there as their **initial** — or as their **photo**, when they set one and the owner enabled *Member photos on the plan* — with a **check badge** when they are checked in and a **green dot** when they are online in the app right now. Full first names appear where there is room for them: on the lock chip of a whole-space booking, and in the list view. When a **whole table, room or floor** is reserved, the space itself says so — a coloured wash, a strong border, and a **lock chip with the occupant's name** in the middle (a checked-in glyph once they're there); the room's label reads *Bureau 2 · Florian*. Every user sees it, on the plan, in the Reserve hub and on the kiosk.

The plan can look like your real space: the owner can put a **photo of the room as the level background** and place freely **resizable illustration images** (plants, sofas…) on the grid. A **desk transparency** slider in the workspace settings lets the photo show through the drawn desks.

Getting around:

- Along the top: a **map / list** toggle (the list shows the same seats as rows), the **date chip** (tap to browse another day) and the window controls, which follow your workspace's granularity (§8): three **day-part chips** — morning, afternoon, full day — where the workspace books half-days; only *Full day* where it books whole days; **from → to** controls on a minute grid or a free time range; and both under *real hours*.
- The canvas **auto-fits** your floor when it opens or when you rotate the device; **pinch to zoom** or use the **+ / −** buttons, drag the **scrollbars** along the edges, and tap the **fit** button to re-centre.
- Pick the floor from the **level rail** on the right (1, 2, …); its **layers icon** acts on the whole level (below). In **landscape**, the controls move into a side panel so the plan fills the screen — handy on tablets.

Booking from the plan:

- **Walk-up check-in**: tap a free seat → the sheet suggests *now* until a canonical end → confirm. Under half-days and full days the server then **snaps the start back to the slot it belongs to**: arrive at 10:00, confirm *until 12:00*, and you book — and consume — the whole 8:00–12:00 morning (§4b). If someone reserved that seat later, your end time is capped and you're told.
- **Check-in on a reservation**: checking in means *you are there*. Under half-days, full days and real hours **any arrival on the booking's own day** opens the window — at 10:00 you can already check in on your 12:00 afternoon. On a minute grid the window opens 15 minutes before your start, or one grid step before it when that step is longer (so 5- and 15-minute grids keep the 15 minutes, an hourly grid opens an hour early). It closes when the reservation ends; outside it the button is disabled and says when it opens. Admins can check in a member standing at their seat (while *booking for others* is on).
- **Check-out**: manual — and it **truncates the booking to now**, so the seat frees immediately for everyone else. It is **personal by default**: an admin (the owner included) can only end someone else's check-in once *Admins may check members out* is on (§8). With **auto check-in/out** enabled, forgotten bookings close themselves — the sweep runs on every read, so a morning booking left open is completed at its own end from 12:01 onwards, not at midnight.
- **Whole spaces**: **double-tap** a desk, a room, or an empty stretch of floor — or tap the **layers icon** on the level rail — to act on the **whole table, office or level**. **One sheet** holds all of it: the space's name, the period picker (e.g. *Thu, Aug 6 10:13 → 12:00*) with the same repetition options as a seat, an optional **For the member** selector for admins booking on someone's behalf, and the confirm button.
- **Make not reservable**: on the booking sheet, owners and admins (with *Admins may block seats*) take the seat out of service from now on — it reads **blocked** on the plan until it is released again in the editor's seat sheet.
- **Time scroller**: pick a from→to window (or Morning / Afternoon / Full day, depending on the workspace granularity) to see occupancy at any future moment.
- Seats can carry **accessories** (monitor, standing desk…), some with a per-half-day supplement that shows up on your statement.
- Bookings count against your **monthly days** (§9) — the app blocks or bills you past your plan, depending on what the owner configured for you. One exception: a booking lying **wholly outside the working hours** may be free or exempt, depending on the workspace's outside-hours policy (§4b).

![](assets/help/images/reserve-plan-closed.jpg)

*The plan in the Reserve hub on a closed day: the closure banner, the view switch, the date and the day-part chips, the level rail (1 · 2 · layers) and the zoom controls.*

**A seat booked for part of the day looks part-booked (#903).** The plan reads a seat left to right as the open day: a booking that ends at midday fills the left half of the pad, one that starts after lunch fills the right, and a seat held all day fills whole as before. A hairline separates two neighbouring bookings so they never read as one, and each stretch carries the colour of who holds it — yours or somebody else's.

**Who is on this seat today.** Tap a seat that carries **more than one booking** and the day opens instead of the usual sheet: every stretch with its hours, its occupant and whether it is done, running or still ahead, and every free stretch as something you can take — tap it and the ordinary booking sheet opens on exactly that window. A seat with a single booking behaves as it always did. The whole thing rides the *Seat day timeline* feature.

## 4. Reservations (Reserve hub)

Open the **Reserve** hub (center button). Along the top: two rows of controls. The first says **what** you are looking at: the four **view buttons** and, on the plan, the **map / list** switch. The second says **when**: the **date chip**, a **Now** button once you have browsed away from today, and the same granularity-dependent window controls the plan itself uses (§3 — day-part chips, a *Full day* chip, or from → to). The **floor chips** (*All floors*, or one per level) sit on the plan itself, and the **QR scan** button (§4a) sits in the app bar, beside the editor and the bell. Then four views:

- **Plan** — the floor plan filtered to your chosen window; tap a free seat to book it.
- **Day** — every seat as a timeline row for the selected day (08:00 → 17:00 or your workspace's hours, the red line marking *now*); tap a free stretch to book, tap your own block to see its details.
- **Week** — a seat × day grid for the whole ISO week, a day strip (*Mon 3 … Sun 9*) on top; each cell holds the day's half-day slots with the occupant's initial. Find a free half-day at a glance and tap it to book.
- **Month** — an availability calendar: every day shows its **free-desk count** (e.g. *10/12*); tap a day to drop into its Day view.

**One place at a time — by default**: the workspace sets how many overlapping reservations one member may hold, and that number is **1** unless the owner raises it (§8). At 1, booking or checking in somewhere else while one is running is refused; checking in closes any earlier check-in whose booking already ended either way. Admins and owners can **overrule**: tapping an occupied or reserved seat offers *Remove reservation (overrule)* — the reservation is removed and the member and all admins are notified through the events feed.

Reservations follow the workspace **granularity rule** (§8 Availability) — half-days, full days, real hours (exact from–to times with the half/full-day windows as shortcuts), or free start/end times on the owner's slot grid. Half and full days cover the workspace's configured **working hours** (default 8:00–17:00 with the half-day boundary at 12:00). They respect the **open weekdays** and **closure days**, and the booking rules (advance horizon, minimum and maximum duration). **A booking always ends on the day it starts** — nothing crosses midnight; a stay that continues tomorrow is tomorrow's booking, made tomorrow (§4b). Repeating needs? Book a **series** (daily, weekdays, weekly) — closed days and conflicts are skipped and reported.

**Deleting a past or checked-in booking is a request, not an action.** A booking whose start has passed — or where you already checked in — cannot be cancelled directly: the sheet offers **Request deletion** instead. An owner or admin decides the one question that matters for billing: was the check-in simply forgotten (the booking stays on the record), or was it never used (it is removed)? The request appears on the Events feed with your optional reason; future untouched bookings keep the normal one-tap cancel. This whole path rides the **Booking deletion requests** feature: with it off, a started or checked-in booking has neither a cancel button nor a request — it simply stays on the record.

![](assets/help/images/reserve-day.jpg)

*The Day view: every seat as a timeline row, the red line marking now — tap a free stretch to book it.*

![](assets/help/images/reserve-week.jpg)

*The Week view: a seat × day grid holding each day's half-day slots, the occupant's initial in the cell.*

![](assets/help/images/reserve-month.jpg)

*The Month view counts the free desks per day (8/10); tapping a day drops into its Day view.*

![](assets/help/images/reserve-booking-sheet.jpg)

*The booking sheet: Morning / Afternoon / Full day, Book for (admins), Repeat — and Make not reservable, for owners and admins.*

### 4a. Scan a space code

Every seat, desk, office and level can carry a printed **QR card** (§8). Tap the **scan button** in the Reserve hub, point the camera at the card — or type its code — and the app identifies the space and shows exactly what *you* may do there:

- **Seat card** — reserve or check in on that exact seat, on the spot (today's window: morning / afternoon / full day where the workspace uses half-days, otherwise from now for the next hours).
- **Desk card** — the desk's seats with their live state; pick a free one. A table the owner marked bookable also offers the **whole table**, with its price per half-day, exactly like an office or a level card.
- **Office or level card** — if the owner made it reservable, the *Desk, office & level reservations* feature is on **and** you hold the personal right (§8) — owners and admins always do — you can reserve or check into the **whole office or floor** — with the same period picker (morning / afternoon / full day, or free times) and **series** options as a seat; its price per half-day is shown and lands on your bill. Otherwise the sheet tells you why, and an office falls back to its seats.

**A scan opens the kiosk's own sheet.** Reading a **seat**'s code — its printed QR, or the NFC tag stuck on the chair — offers exactly what tapping that seat on the kiosk offers: the same three actions (**Check in**, **Reserve**, **Check out**), the same period derived from the workspace settings. The one difference is that you are already signed in, so there is no badge step (§4b). Table, office and level cards open their own whole-space sheet as described above; **NFC tags resolve seats only**, so a chair tag is the one tap-to-book shortcut.

**Conflicts protect both directions:** an office or level cannot be reserved while any seat inside is already booked in that window — and no seat can be booked while its office or level is reserved as a whole.

### 4b. How booking behaves

All times below are workspace-local, and the examples assume the default working day (08:00 – 12:00 – 17:00).

**Booking ahead.** What a time window may look like depends on the workspace granularity (§8 Availability):

| You ask for | Half-days | Full days | Minute grid (5/15/30/60 min) | Real hours / free time range |
|---|---|---|---|---|
| The morning (8–12) | ✅ | ❌ — must cover the full day | ✅ if the edges sit on the grid | ✅ |
| The afternoon (12–17) | ✅ | ❌ | ✅ | ✅ |
| The whole working day (8–17) | ✅ | ✅ | ✅ | ✅ |
| An odd window (9–15) | ❌ | ❌ | ✅ if on the grid | ✅ |
| Before opening / after hours (a 6:00 start, 17–21) | only as the evening walk-up | only as the evening walk-up | ✅ — the grids are free-time | ✅ |
| Off the grid (10:02) | — | — | ❌ — the refusal names the grid | — |

The last row of that table is the only one a granularity can rule out by shape; everything else about a window is decided by rules that apply **on every granularity alike**:

- The future is open up to the **advance horizon** — 90 days unless the owner changes it (§8) — and refused beyond it.
- The **minimum and maximum duration** hold everywhere, not just on grids. Both are owner-set (§8); with the default 30-minute minimum, a half-day walk-up started at 11:45 for the 12:00 boundary is refused as too short — arrive earlier or take the afternoon.
- **A booking ends on the day it starts.** No window may cross midnight, whatever the granularity: an evening that runs on becomes tomorrow's booking, created tomorrow. The refusal reads *"a booking must end on the day it starts"*. The evening walk-up that runs to **local midnight** is still fine — midnight is that day's own end, not a crossing. Keeping every booking inside one day is what lets each day's occupancy, quota and bill be answered on that day alone.
- A booking on a **day that already ended** (yesterday and earlier) is refused — *"lies entirely in the past"* — unless the owner switched **Allow past bookings** on. Booking this morning's window later the same day always works.
- A **walk-up check-in must start today**: creating an already-checked-in booking for tomorrow is refused.
- A **closed day** refuses by name; an occupied seat refuses; and a member may hold only as many **overlapping** bookings as their allowance (below).
- The **Outside the opening hours** policy (§8) decides what a window leaving the working day is worth, or whether it may exist at all (below).

All of it is enforced in **one shared place on the server**, which is why the plan, the Reserve hub, a QR or NFC scan and the wall kiosk all offer exactly what will be accepted, and why the kiosk refuses precisely what the plan refuses — there is no "but the kiosk let me" path. A request that slips past a stale screen is refused with the reason named.

**Before you ask, the app tells you (#814).** Every one of those rules is mirrored on the device by the **booking gate** (Features → *Booking gate*, under *Booking policies*, on by default): the plan tap, the Day and Week free-slot taps, the booking sheet, the kiosk one-sheet and the QR/NFC scan sheet all check the window against the availability parameters **before** offering it, and name the same reason the server would — *closed on that day*, *lies entirely in the past*, *too far ahead — bookings are open N days in advance*, *too short*, *too long*, *a booking ends on the day it starts*, *outside the opening hours*. A refused window disables **Reserve** with the reason under the period; at the kiosk the badge is simply not accepted for it, and the scan sheet refuses a closed day up front exactly as the kiosk does. The **Day, Week and Month views** draw closed days as closed — muted columns, no free-slot tap, *Closed* instead of a free-desk count — and a **legend** under the controls names the seat states (*Free · Reserved · Checked in · Mine · Blocked · Closed day*). Where the owner switched **Admins may check members out** on, an admin's sheet on an occupied seat offers **Check out {name}**. In the browser, which has no camera scanner, the scan and kiosk sheets say so and point at the typed code and the NFC tag.

**How many places at once.** The workspace sets a **simultaneous-reservations** number (§8); it is **1** by default — exactly the historical one place at a time. An owner or admin may grant a single member a higher allowance in *Members & plans*, and that personal permission overrides the workspace number; nobody sets their own. The same allowance governs **check-ins**: a member allowed 2 places may be checked in at 2 places at once. Reaching the allowance refuses with the familiar message — *you already have a reservation in that period*, or *already checked in elsewhere*.

**Outside the opening hours.** A window that leaves the working day — a 6:00–8:00 early morning, a 17:00–21:00 evening, the overtime walk-up running to local midnight — is governed by one workspace-wide policy with **four** mutually exclusive answers (§8), the same on every granularity.

| Mode | A booking (or walk-up check-in) outside the hours |
|---|---|
| **Off** | ❌ refused on every granularity — including the evening overtime walk-up that the day-based granularities otherwise always allow, and including a booking that merely runs **past** the day's end (16:00–20:00) or starts before it opens |
| **Spontaneous only** | ✅ the walk-up check-in, at **either edge of the day** — the 6:00 early arrival as much as the evening overtime to midnight — ❌ reserving that window **ahead**, and ❌ a booking spilling past the day's end |
| **Free** | ✅ allowed, but never counted and never charged: the booking is pure information — others see the space is taken, and a check-in shows where to find the person |
| **Charged** (the default) | ✅ allowed and counted like ordinary usage — **except** on a day where you already hold a regular inside-hours booking, and the outside part then rides free |

That exemption is the point of the default: it stops "book only outside the hours to avoid paying" without charging twice a member who already used their day. Two fine points. **Free and charged look only at windows lying *wholly* outside the hours** — a booking touching the working hours at all, even by a minute, is an ordinary counted booking. **Off and Spontaneous only refuse more widely**: they also refuse the spilling window, because a space that closes at 17:00 has no business being booked until 18:00. *Spontaneous only* is where the retired **Minute bookings within working hours** switch went — the same idea, now on every granularity. A workspace that still carries the old switch reads as *Spontaneous only*, with one deliberate improvement: the old switch let only the *evening* walk-up through, whereas a mode named for spontaneity has no business turning away the member who arrives at 6:00. Booking ahead is what it refuses; walking in is what it is for. The granularity's own shape rules still apply on top, so this opens no arbitrary window.

**Walk-ups snap to the slot.** A walk-up (tap a free seat, scan its QR/NFC, or the kiosk) books *now* until a canonical edge — the half-day boundary, the day end, or a grid edge. Under day-based granularities the booking covers the **whole slot the end belongs to**: arriving at 10:00 and choosing *until 12:00* books the full 8:00–12:00 morning; when the snapped-back window turns out to be unavailable — someone else's booking, one of your own overlapping it, a blocked seat, a whole table/office/level taken — the booking anchors at your arrival instead, keeping the slot's end. At or after the working day's end a walk-up may run to **local midnight** (evening overtime — on every granularity, unless **Outside the opening hours** is *Off*, the one policy that refuses it); it stops there, because a booking ends on the day it starts. And a walk-up check-in must start **today**: creating a "checked-in" booking for tomorrow is refused.

**A scan behaves like the kiosk.** Scanning a **seat** — its printed QR card or the NFC tag on the chair — opens the very sheet the kiosk opens when that seat is tapped: **Check in**, **Reserve** or **Check out**, on the same periods derived from the workspace settings, minus the badge step, because you are already signed in. (Table, office and level QR cards open the whole-space sheet instead, §4a; NFC tags resolve seats only.) From there the space decides:

| What you scan | What the sheet does |
|---|---|
| A space you hold a booking on | continues into checking **that** booking in |
| A free space | the check-in books it implicitly, snapped to the slot like any walk-up |
| A space someone else's booking blocks | names the holder and offers **Message them** — the conversation opens with the blocking booking referenced |

The same *message the holder* action sits on the **plan** when you tap a seat someone else occupies. At the kiosk the receipt names the holder and points you to the app instead: a wall device never sends messages for you.

**Checking in.** Under half-days, full days and real hours the window opens for the **whole booked day**: at 10:00 you can already check in on your 12:00 afternoon, because the slot *is* the working day. On a minute grid it opens **15 minutes before** your start — or one **grid step** before it where that step is longer, so 5-, 15- and 30-minute grids keep the 15 minutes and an hourly grid opens a full hour early. The sheet always reads the real clock, so browsing a future date never hides today's check-in on your own booking. Checking in on a different day ("tomorrow's booking today"), after the reservation ended, twice, or on a closed day is refused with the reason. If you are still checked in **elsewhere**: a booking still running blocks it once you have reached your allowance (one by default, so the first running booking already blocks — *check out there first*); one that already ended completes itself silently — stamped at its own end — and the new check-in proceeds. An admin can check a member in while *Booking for others* is on (§8 Features).

**Checking out.** Checking out before the reserved end **truncates the booking to now** — the seat frees immediately for everyone else. After an early same-day check-in, checking out before the reserved start keeps the **real presence** (from the check-in instant to now). Forgot and came back later? The check-out still works: the booked end stays, the stamp is truthful. Checking out without a check-in — or twice — is refused. By default **check-out is personal**: an admin can only end a member's running check-in once the owner switched **Admins may check members out** on (§8). A check-in never closed at all completes itself the moment you check in somewhere else after it ended — or, with **auto check-in/out** on, at the next sweep.

**No-shows.** A reservation never checked in simply stays *reserved* in the history. With **auto check-in/out** on, the sweep marks the past window attended — checked in at the start, checked out at the end, completed. The sweep is **lazy**, running on every read rather than at a fixed hour, so a morning booking nobody touched is already settled when someone opens the plan at 12:01.

**Cancelling.**

| Case | What happens |
|---|---|
| A future booking of yours | ✅ cancelled with one tap |
| Your running, checked-in booking | ❌ no outright cancel — the sheet offers **Request deletion** (§4) and **End earlier** (below) instead, because the presence already happened |
| Giving back the rest of the day | ✅ **End earlier** on a running booking: under half-days and full days it moves the end to the half-day boundary while that is still ahead; on grids it opens a snapped picker that refuses anything not ahead of now. The start is immovable, and the freed time is immediately bookable by others |
| A completed or already cancelled booking | ❌ nothing left to cancel |
| Someone else's booking | ❌ for a member; ✅ for an admin/owner — the overrule (§4), attributed to the admin in the events feed |
| A series, "this and following" | ✅ cancels the remaining *reserved* occurrences from that date; checked-in and completed ones keep their history |
| A **past or checked-in** booking you want removed | a **deletion request** (§4): a validator confirms (removed) or rejects (kept); a new request supersedes a pending one, and future bookings are told to cancel directly |

**Approvals.** Where the owner put a validation policy on **whole-space reservations** (§7), the booking blocks the space immediately and waits for the quorum — a reject cancels it; no policy, no approval step. Deletion requests ride the same framework. **Nobody validates their own event** — with one exception the owner switches on deliberately: in the validation rules (§7), two independent switches let **admins** and/or **owners** settle *their own* **reservation deletion** requests on the spot instead of waiting for a validator. Both are **off by default**, they reach reservation deletions and nothing else, and an auto-settled deletion is marked as such in the events feed — always distinguishable from a peer-reviewed one.

## 5. Calendar (Calendar tab)

The month at a glance, with two scopes and two shapes:

**The calendar is a selector, not a stage (#718).** Pick a **day** or a **range**; what you see is one feed of everything dated that you may see — bookings, check-ins and check-outs, alerts, messages, invoices, payments, consumption, reminders — grouped by day, filtered by kind with the chips, and **every row opens its source** (the booking, the conversation, the alert, the invoice, the month on Finances). A member with the finance or member-administration permission can look at another member; kinds the server does not allow for that member show as **locked**, never as an empty day. The shield opens *Who can see this*, with the access log.

**Three views (#818).** With *Calendar views* on (default), the tab opens on the **Agenda** — everything dated in the **next 30 days**, grouped under *Today · Tomorrow · weekday* headers, the arrows stepping 30 days and **Today** jumping back. **Week** shows a strip of seven pills (weekday, number, coloured markers, count) with the whole week's feed below; **Month** a compact grid where each day carries up to three **markers** — *bookings & presence*, *alerts & messages*, *money* — today ringed, the selected day filled, **closed days** muted and struck through; tap a day to read it below (the legend under the grid names the colours). A closed day says so in the feed, with the closure's reason. The feed also carries two facts it did not before: the **payment due date** of every open invoice (issue date + the reminder term) and each **scheduled expense** falling due. The kind chips and the member picker keep narrowing the query as before; the shield opens *Who can see this*. Off, the plain day-or-range selector stays.

- **Mine / Everyone** — your own bookings, or the whole community's; every member has this toggle, since the plan and the Reserve hub's week grid already show everybody's occupancy. The dots under a day tell you at a glance: **red** = you have a booking, **blue** = other members do, **both dots** = both. Today is ringed.
- The **shape toggle** beside it switches the lower half between an **agenda list** (each reservation as a card: time window, member, space) and a **day timeline** (seats × the hours of the selected day). The seats × *days* week grid lives in the Reserve hub (§4), not here.
- The **floor chips** (*All floors* / per level) filter the **timeline**.
- Tap a day in the month grid to load it below. In landscape the calendar and the detail use the split layout.

![](assets/help/images/calendar-agenda.jpg)

*The Calendar tab: a day or a range, the kind chips, one feed grouped by day — every row opens its source.*

## 6. Members directory (Members tab)

![](assets/help/images/member-profile-sheet.jpg)

*A member's profile: today's booking, contact, and — where you may see it — their money position.*

**Tap a member for their profile (#704).** Their photo, role and status; what they have booked and whether they are checked in right now; and **Contact** — the opt-in WhatsApp number for everyone, the **e-mail address and plan share for admins**. Where you may see the figures — **your own always, somebody else's with the *View finances* permission** — the profile also carries **Money**: the net position (who owes whom), the open invoices with what is left on each, the payments already in, and the month being consumed right now. The same card the Money tab shows, so the two can never disagree.

**One page per member (#825).** Tapping a member now opens a **full page**: their photo with the presence dot, role chips, their own status line, **when they were last seen** ("Seen 20 h ago", not a bare number), and since when they are a member. A **Right now** card says in one sentence whether they are checked in, hold a reservation this minute, or when their **next** booking is — tap it, or any upcoming row, to open that booking. **Quick actions** sit below: Messages, WhatsApp and (for admins) e-mail, plus *Add a service* and *Send the financial agreement* where those apply. The contact and money cards follow, unchanged. **Admins and owners** get a **Manage** section on the same page — *Membership* (approve or reject, pause, role, co-ownership, kiosk), *Booking rules* (reservation limit, simultaneous reservations, whole-level bookings as a switch), *Billing* (subscription, when days run out, negotiations) and *Badges & access* — every row showing its **current value**, so nothing has to be opened to be known. The rows in *Settings → Members & plans* open the same page.

See who's part of your community:

- Each member card shows their **photo** (or initial), **role chip** (Admin, Owner), **custom status** ("in Berlin till Friday…"), an **online / last-seen** indicator (*Online*, *10 min*, *2 d*) and a **reservation chip**: checked-in seat, *Reserved now*, or next upcoming reservation.
- Tap a member for their **detail sheet** — role, presence, their **upcoming reservations**, and **Messages**.
- **Messages**: a per-member **conversation thread** (up to 500 characters per message) — open it from the **Messages** tab (§16), the member's sheet or their directory profile, read the whole exchange as chat bubbles and send from the same place. Every message reaches the other side twice over: a **push** that carries no content at all (*"You have a new message"* — by privacy design), and, once the app is running, a local notification that does show your name and text.). The full text is always readable in the **Messages** tab, for the recipient and the sender (the push itself carries no content, by privacy design). Admins get a **Notify all admins** megaphone — in *Members & plans* (Settings → Administration), not on the Members tab, which has no app bar of its own — reaching every admin including the owner. Toggleable via the *Member notifications* feature. While composing, two chips let you **link a reservation or live check-in — yours or any other member's** — or **a space** (seat, table, room or level) — the reference shows as a tappable link on both sides: a reservation link opens that reservation, a space link opens the space’s booking sheet, perfect for discussing a future booking.
- The **message icon** on a card messages that member on **WhatsApp** (if they shared their number); the **group button** opens your community's WhatsApp group (set by the owner).
- Set your own photo, status, and phone visibility in **Settings** (§12).
- Admins and owners additionally see each member's **email** under the name — plain members don't: member-to-member contact stays the opt-in WhatsApp number.

![](assets/help/images/members-directory.jpg)

*The directory: photo or initial, role chip, status, online/last-seen, and the next reservation on each card.*

## 7. Events & confirmations (Messages → Events)

**Where it lives.** The feed is the second face of the **Messages** tab, and the **bell** in every app bar is a shortcut straight onto it, carrying the count of what awaits you. One place holds the alerts, so reading one there is reading it everywhere. With the reworked messaging the tab is labelled **Alerts**, and it marks itself read only while it is the face on screen — switching to it is reading it, having it behind the chats is not.

The events feed is the audit trail of your workspace: reservations created/changed/cancelled, payments recorded, invoices paid, expenses submitted, extra-days requests, role changes, deletion requests. Members see their own events; admins and owners see everyone's. **Filter chips** (All · Reservation · Payment · Expense · …) narrow the list — your choice is remembered — and a **Group by** menu folds the feed into groups by type, day or member (tap the group symbol to return to the flat list); each row carries its status icon — an **hourglass** while pending, a **green check** once confirmed — and money events show *who validated them and when* right on the row.

**Waiting for your confirmation:** whenever an admin does something *for somebody else* — books a seat for you, records your payment, demotes an admin — it stays **pending until confirmed**. Pending items are pinned on top with a red ✕ and a green **Accept** button, and you get a notification. Actions you take on yourself never need confirmation.

**Messages moved.** Member messages now live in their own **Messages** tab (§16), not here — a message in two places is one you can mark read in one and still see unread in the other. This feed keeps the one message kind that has no conversation to live in: a **broadcast to all admins**.

**Validation quorum:** for money matters and role changes the owner defines *who* must approve and *how many* approvals are needed. **Nobody validates their own event** — only another person can (one owner-configured exception, for reservation deletions, below); where no other validator exists, the request simply waits. After 7 days without an answer, what happens depends on which way the request cuts. A request **you submitted** for yourself — a deletion, extra half-days, an invoice write-off — **expires**: nothing costly is ever granted silently. Something an admin **did for you** — created or modified a booking, recorded a payment — **auto-confirms** instead, because it already happened and the feed only asked you to acknowledge it; a booking an admin made for you is then granted and consumes your quota. An expired **invoice payment** — a match, a refund or a regrouping nobody decided in time — releases what it held: the payment, the credit note and the regrouped invoices are back where they were (#816).

The owner tunes this per **domain** in **Settings → Validation rules** — fourteen cards, one per event type, each inheriting from the **default rule** until edited: *Default rule, Payment, Expense, Service, Extra half-days, Booking deletion, Role change, New member, Reservation, Whole-space reservations, Invoice payment*, *Outstanding write-off*, *Price negotiation* and *Scheduled expense*. A rule sets the number of required validations, *which* admins may validate (all, or named ones), and whether the owner must always sign off. The **Booking deletion** rule carries two more switches — *admins delete without validation* and *owners delete without validation*, both **off by default** — the single, deliberate exception to "nobody validates their own event": that requester's own deletion request settles itself and stays marked **auto-validated** in the feed. They apply to reservation deletions and to nothing else.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*Left: one rule per domain, inheriting from the default. Right: editing a rule — required validations, allowed validators, owner sign-off.*

![](assets/help/images/messages-events.jpg)

*The Events face of Messages: kind chips, Unread / Read, and Group by Type · Date · Member.*

## 8. For owners: the editor & settings

All administration lives under **Settings → Administration** — *Coworking space* (the workspace settings), *Members & plans*, *Availability*, *Role management*, *Billing & reports* (the invoicing hub with the report editor and reminder rules in its header), *Payment instructions*, *Online payments*, *RFID / NFC badges*, *Services*, *Accessories*, *Billing*, *Features*, *Validation rules* and *Workspace ID & QR*, in the order the screen lists them (some ride their feature: *Accessories*, *Online payments*, *RFID / NFC badges*…). One rule to know: **a feature's settings entry only appears while that feature is enabled** — switch *Online payments* off in **Features** and its configuration screen disappears with it (and comes back when you re-enable it). The **Features** entry itself is always there, so you can always switch a module back on.

**Country, currency, time zone (#711).** The country picker now covers the 32 countries the app can declare tax in (EU-27, Switzerland, Norway, the UK, the US and Canada). Currency is a **picker** of the codes the app can format — each with its symbol, and each with the right number of decimals: a yen has none, a dinar has three, and every amount, invoice and online payment respects that. Time zone is a **searchable list** of the IANA zones the clock can actually install; a typo can no longer save.

### The space editor

Open the **editor** from the Reserve hub's app bar (crossed tools icon). The **Space editor** screen lists your floors — drag to reorder, the **layers icon** marks a level *Bookable as a whole*, the **⋮ menu** renames or deletes, **+ Add a floor** extends the building. Open a floor to draw it on the grid with the bottom toolbar — **Select · Office · Table · Seat · Image · Erase**:

- An **office** gets a name, an optional *Bookable as a whole* switch and a **price per half-day**.
- A **table** gets a name, the same whole-table option and its own **price per half-day**.
- A **seat** gets a name, a **seating direction** (↑ → ↓ ←), an optional **chair type**, its **accessories** (each may carry a per-half-day supplement) and a **Blocked (maintenance)** switch. Its **NFC/RFID tag** field takes the chair tag's UID in hex — read it with the tag button or type it — so a tap on the chair resolves this seat (§4a).
- **Image** places a resizable illustration; the photo icon in the app bar sets the level's **background photo**.
- Deleting a space that has history is the **owner's** call, and with *Delete spaces with history* on (the default) it just works: bookings that referenced the space keep a text snapshot of what it was, and any still-reserved booking on it is cancelled automatically. Switch the feature off and a space with future reservations has to be emptied by hand first.

![](assets/help/images/space-editor-floors.jpg)

*The Space editor's floor list: drag to reorder, the layers icon marks a level bookable as a whole.*

![](assets/help/images/space-editor-canvas.jpg)

*A floor on the grid with the bottom toolbar — Select · Office · Table · Seat · Image · Erase.*

![](assets/help/images/space-editor-seat.jpg)

*A seat's sheet: name, seating direction, chair type, accessories, the NFC/RFID tag field and the blocked switch.*

### Workspace ID & QR

Your role-bound invites (§2): member invite = the workspace ID (replace it with a memorable one, copy it, share the QR as PNG), admin invite = single-use personal codes.

![](assets/help/images/workspace-id-qr.jpg)

*Workspace ID & QR: the member invite (QR + ID — copy, change, share as PNG, invite someone) and the admin-invite tab.*

### Availability

#### Open days & granularity

- **Open weekdays** — chips Mon…Sun.
- **Booking granularity** — one of: *free time range*, *5 / 15 / 30 / 60-minute slots*, *half-days (morning & afternoon)*, *full days only*, or *real hours* (exact from–to, with half/full-day shortcuts).

![](assets/help/images/availability-basics.jpg)

*Open weekdays and the granularity choice — what a booking may look like starts here.*

#### Working hours

- **Working hours** — day start, half-day boundary, day end (default 08:00 / 12:00 / 17:00). Half-day and full-day slots everywhere — reservations, check-in and billing — follow these hours; under *real hours* you also set how many hours bill as a half and a full day.
- **Closure days** — dated exceptions, added with **+**.

![](assets/help/images/availability-hours.jpg)

*The working hours: day start, half-day boundary, day end — every half-day and full-day slot follows them.*

#### Booking policies

- **Booking policies** — four entries that relax or tighten the rules of §4b (the section rides the *Booking policies* feature); the two switches are both **off by default**:
  - **Allow past bookings** — members may backfill a booking that already ended (yesterday and earlier). Off, such bookings are refused; booking a window earlier the *same day* is always allowed either way. Switch it on for spaces that record attendance after the fact.
  - **Admins may check members out** — an admin can end a member's running check-in. Off, check-out is strictly personal. Useful where staff closes the room in the evening.
  - **Outside the opening hours** — one question, four mutually exclusive answers, the same on every granularity: *what may happen outside the working day?* **Off** — nothing: no booking ahead, no walk-up, and a booking spilling past the day's end (or starting before it opens) is refused too. **Spontaneous only** — the walk-up check-in stays possible at **either edge of the day**, the early arrival before opening as much as the evening overtime to midnight, while reserving ahead outside the hours is refused; this is where the old **Minute bookings within working hours** switch went, and workspaces that had it on read as this (that switch allowed only the evening walk-up — the mode is named for spontaneity, not for the evening, so the morning walk-in is allowed too). **Free** — allowed, never counted and never charged (pure presence information). **Charged** (the **default**) — counted like ordinary usage, except on a day where the member already holds a regular inside-hours booking, when the outside part rides free.
  - **Simultaneous reservations per member** — how many overlapping bookings one member may hold, check-ins included. **1** by default: one place at a time. An owner or admin can grant a single member a higher allowance in *Members & plans* (never for themselves), and that personal permission wins over this number.

![](assets/help/images/availability-outside.jpg)

*The outside-the-opening-hours policy: one question, four mutually exclusive answers — the same on every granularity.*

#### Booking limits

  Below them sits **Booking limits** — three numbers the server has always enforced and that the app can now set:

  - **Advance booking horizon** — how many days ahead a booking may start (default **90**); beyond it the booking is refused by name.
  - **Minimum duration** — the shortest booking accepted (default **30 minutes**), on every granularity. It is exactly why an 11:45 arrival for the 12:00 half-day boundary is refused as too short.
  - **Maximum duration** — the longest accepted (default **24 hours**). Since a booking ends on the day it starts, a full day is the ceiling and the picker offers nothing above it.

  Set a minimum above the maximum and the screen says so, because the server checks each bound on its own and would simply refuse every booking without explaining why.

![](assets/help/images/availability-limits.jpg)

*The booking limits — advance horizon, minimum and maximum duration — and the closure days beneath them.*

  The two **auto-validation** switches — *admins delete without validation*, *owners delete without validation* — are not here: they live with the validation rules (§7), off by default, and reach reservation deletions only.

### Features

![](assets/help/images/features-tree.jpg)

*The Features screen: every module with its description; an indented child needs its parent.*

Switch whole modules on or off per workspace — each toggle carries its description right on the screen: calendar tab, events tab, notification feed grouping, money tab, services, accessory supplements, online payments, invoices, admins issue invoices, invoice PDF template, payment reminders (dunning), VAT management, VAT declarations, e-invoice delivery to the customer, PDF export, series booking, booking for others, push notifications, admins may block seats, table/desk & level reservations, admins may assign levels, kiosk mode, RFID/NFC badges, QR badges, kiosk member photos, members directory, WhatsApp integration, space QR codes, chair NFC tags, member photos on the plan, co-owners, auto check-in/out, data export (Excel), working hours, booking policies, member notifications, document library, member reports, booking deletion requests, role management, plan-object deletion, contextual help hints, and interface animations. Switching a module off removes *all* of its screens and buttons for every member.

The list is **hierarchical**: a feature that needs another sits indented under it with a *Requires…* note, and is greyed out while its parent is off — *Money* carries services, accessory supplements, online payments and invoicing; *Invoices* carries the admin delegation, the PDF template, the payment reminders, VAT management (with the declarations beneath it again) and the customer e-invoice delivery; *Kiosk mode* carries three children — RFID/NFC badges, QR badges and kiosk member photos; *Table/desk & level reservations* carries *admins may assign levels*; *Members directory* carries the WhatsApp integration; *Events tab* carries the feed grouping. Switching a parent off takes its whole subtree out of the app; the child's stored choice comes back untouched when the parent returns.

### Members & plans

Tap a member to open their **management sheet** — every per-member action in one place: **Send the financial agreement** (§11d), **Messages**, **Add a service** (service, quantity, billing month → *submit for confirmation*), **Subscription** (their percentage), **When the days run out** (the over-consumption policy, §9), **Reservation limit** (how many **open** reservations the member may hold in total, whenever they fall), **Simultaneous reservations** (how many bookings may **overlap in time** — the personal allowance that overrides the workspace number, §4b; two different caps, so read the labels), **May reserve a whole desk, office or level**, **Badges** (§10), **Name admin** (validated, §7), **Co-ownership**, **Turn into a kiosk** — or **Revert the kiosk to a member** on a device account — **Approve** or **Reject** a pending membership, and **Pause the membership**. Each row shows the member's **email** under the name.

![](assets/help/images/members-plans-list.jpg)

*Members & plans: e-mail, plan share and role chips per row; megaphone, add and filters in the app bar.*

![](assets/help/images/member-management-sheet.jpg)

*A member's management sheet — every per-member action in one place.*

![](assets/help/images/member-management-sheet-self.jpg)

*Your own sheet is shorter: nobody grants themselves rights (no admin/whole-space/simultaneous rows on yourself).*

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

*The subscription dialog (the member's percentage) and the reservation-limit dialog (the cap on open reservations).*

### Billing

- **Fee tiers** — the price ladder behind percentage subscriptions: each tier says *from X %*, *up to Y %*, the monthly **fee** and the per-extra-half-day **overage rate**. **+ Add a tier** extends the ladder.
- **Subscription levels** — which percentages members may pick (chips: 25 % · 50 % · 75 % · 100 %, plus your own values), and an optional **negotiated free value** switch.
- **Day packages** — a number of days for a price (name · days · price), each with its own enable toggle; members on the *packages* policy buy them when their days run out.

![](assets/help/images/billing-tiers.jpg)

*Fee tiers (from % · up to % · fee · overage) and the subscription levels members may pick.*

![](assets/help/images/billing-packages.jpg)

*Day packages: a number of days for a price, each with its own enable toggle.*

### Services and Accessories

The catalogs behind §9 — owner-defined extras (lockers, printing…, each with a price and optional VAT rate) and per-seat equipment with optional per-half-day supplements. Both are plain lists with a **+** button.

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

*The services catalog and a new service — name, price, its own VAT rate where the regime charges one.*

![](assets/help/images/accessories-catalog.jpg)

 

![](assets/help/images/accessory-edit-dialog.jpg)

*The accessories catalog and an accessory's editor — the supplement bills per reserved half-day.*

**Stock (#731).** A service that came from a supply shows *N in stock* / *Out of stock*; a consumption larger than the shelf is refused.

### Workspace settings (Coworking space)

The workspace's own screen, top to bottom:

- **Identity** — name, country, currency (proposed from the country, editable), time zone, **workspace language** (invitations default to it; *sender's app language* is an option) and the postal **address** printed on invoices.

![](assets/help/images/workspace-identity.jpg)

*Identity: country drives the proposed currency and time zone; the workspace language writes the invitations.*
- **Payments & billing** — the **payment instructions** members see on an unpaid bill (IBAN, PayPal.me link, Wero phone number, Lydia, Wisetag, payment reference hint — leave a field empty to hide it), and **Legal identity & e-invoicing** (§11a).

![](assets/help/images/workspace-billing-links.jpg)

 

![](assets/help/images/payment-instructions.jpg)

*Payments & billing: the two entries into payment instructions and legal identity — and the instructions form itself, field by field.*
- **WhatsApp group** — the community group link shown in the directory.
- **Invitation message** — the per-language invitation templates (§2).

![](assets/help/images/workspace-invitation.jpg)

*The invitation message per language, with its placeholders, and the desk-transparency slider beneath.*
- **Desk transparency** — the slider that lets a background photo show through drawn desks.
- **Invoice PDF template** and **Reminder rules** — shortcuts to the report editor and the dunning configuration (§11).
- **Exports** — *Export the space (XML)* (settings + floor plan, no personal data — back it up, template it, migrate an instance), *Export the configuration (PDF)* (a full snapshot: settings, members, plan), *Workspace report* (everything about the space through the report engine's « workspace » template), *Space QR codes (PDF)* (one credit-card QR per seat, desk, office and level, ten per A4), *Export the data (Excel)* (one workbook: reservations, payments, invoices, members, plan — one tab each), *Import the space (XML)* (restores settings and floor plan; replaces the current plan). Every export lands in your device's **Downloads** folder.

![](assets/help/images/workspace-exports.jpg)

*The exports block — XML, configuration PDF, workspace report, space QR codes, Excel, XML import — and the danger zone.*
- **The setup questionnaire** — <https://fdittgen-png.github.io/deskilo/setup.html> (§1 explains it in full): the standalone page that collects a whole configuration *before* the app exists. **Import the space (XML)** above is where its file lands — settings, accessories and floor plan directly; the file's `<setup>` section carries billing, legal identity, roles and members for the screens that own them.
- **Danger zone** — **Reset the workspace**: deletes all reservations, the accounting and the floor plan; keeps settings and members. Guarded by a typed confirmation.

### Space QR codes & whole-space reservations

Four steps turn "scan the code on the desk" into the daily booking flow (§4a):

1. In the **editor**, mark a table, an office or a level **Bookable as a whole** and give it a **price per half-day** — the table's or office's property sheet, or for a level the **layers icon right on its row**.
2. Enable **Desk, office & level reservations** in **Features** (off by default).
3. Grant each entitled member **"May reserve a whole desk, office or level"** — owners and admins set it in the member's management sheet, never for themselves. Owners and admins hold the right themselves without the switch, in the app and at the **kiosk** alike.
4. Print the cards: **Workspace settings → Space QR codes (PDF)** — cut them out and stick each card on its space.

An office reservation covers **all the desks inside it**; a level reservation covers the whole floor. Both are only possible while nothing inside is booked — and they show up as their own lines on the member's bill.

### Co-owners

Make sure the community never depends on one account:

1. Open *Members & plans → the member → **Co-ownership*** and pick **active** (owner permissions now) or **passive** (successor-in-waiting).
2. Hand over at any time with ***Promote to owner now*** — the co-owner becomes a full owner alongside you.
3. If the last owner ever leaves the workspace, the best co-owner is **promoted automatically** on the server — active before passive. This safety net works even while the *Co-owners* feature toggle is off (the toggle only hides the appointment buttons).

### Role management

One central matrix decides **which role holds which permission** — manage roles, manage members, validation policies, workspace settings, issue invoices & match payments, view finances, documents, services, approve expenses, view and manage commercial agreements. Open it under *Settings → Administration → Role management* (its feature flag must be on):

- The **owner always holds every permission** — the row is locked.
- Whoever holds *Manage roles & permissions* edits the other rows. A **co-owner** starts with everything ("co-owner can have less" — the owner removes what they want); an **admin** starts with today's admin abilities; a **member** with none.
- Everyone else with any permission sees the matrix **read-only**, their own role highlighted.
- An untouched matrix means the defaults — nothing changes until the owner edits it. The legacy *admin invoicing* feature flag keeps granting invoicing to admins for compatibility. The server enforces the same matrix in every invoicing RPC — issue, replace, cancel, remind, match, refund, write-off and regroup all ask `has_permission` (#816) — so the UI and the database cannot disagree; a member granted *issue invoices* can use it like an admin.

**Who validates (#732).** A rule names its **scope**: *Admins* (the owner and every admin, or the ones you list), *Listed persons* (the owner and exactly the people you pick — a plain member can be a validator), or *All members*. The count and the owner sign-off keep their meaning, and nobody ever validates their own event. Feature *Validators by role or person*.

![](assets/help/images/roles-matrix.jpg)

*Role management: the owner card locked, the co-owner card fully granted by default — the admin and member cards follow with the same eleven permissions.*

### Setting up online payments

Each community collects to its **own** provider account; the app never keeps the secret keys on any device — they live on the server.

1. Open **Settings → Online payments** (owner only).
2. Pick a provider and paste its keys from that provider's dashboard:
   - **PayPal** — Client ID, Secret, Environment (start with *sandbox*), Webhook ID, Return URL (PayPal Developer → your REST app).
   - **Credit card (Stripe)** — Secret key, Webhook signing secret, Return URL (Stripe → API keys / Webhooks).
   - **Mollie** — API key, Return URL (offers iDEAL, Bancontact, cards…).
   - **Wero (via Mollie)** — the same Mollie API key, with Wero enabled in your Mollie account.
3. **Save** — a green *Configured* chip appears. Turn on the **Online payments** feature (Settings → Features), and members see **Pay online** on an outstanding bill. (The *Online payments* settings entry itself only shows while the feature is on.)

![](assets/help/images/online-payments-config.jpg)

*One card per provider — PayPal shown; Stripe, Mollie and Wero take the same shape: keys in, a Configured chip back.*

A saved secret is never shown again — leave its field blank to keep it, type to replace it, **Remove** to clear the provider. Fees are the provider's (typically ~1.5–3% per payment, no monthly fee); DesKilo adds nothing, and the manual bank-transfer/IBAN route stays free.

If a payment doesn't start, turn on **Settings → Advanced → Developer mode** and open the **Developer** screen: the *payments* trace shows exactly which providers are configured and which fields are still missing.

![](assets/help/images/developer-screen.jpg)

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

1. Open **Settings → RFID / NFC badges** (owner only). Switch **Enable NFC badge check-in** on, and read the **device status** line — it distinguishes *ready*, *NFC turned off in Android settings*, and *no NFC hardware*. Android phones and tablets with NFC, and **iPhones**, can read a tag; iPads have no NFC hardware at all.
2. Give each member a card: **Members & plans → the member → Badges → Register a card**, then hold their card to the device. Any card with a readable chip works (MIFARE, NTAG…). Members can also do it **themselves**: **Settings → My badge** mints their printable QR badge and registers their own card — no admin needed.
3. Use them at a **kiosk** (§10): the member taps the card to reserve or check in. Revoke a lost card from the same Badges dialog; **swipe a revoked badge to the right to delete it** for good (after a confirmation).

Badges belong to **one workspace** — the dialog names which one you're registering into, so register the card under the workspace whose kiosk will read it. The same physical card can serve you in several workspaces. A badge QR saved **as PDF** prints ten credit-card copies on one A4 page — spares included.

![](assets/help/images/nfc-config.jpg)

*Step 1 — the NFC switch, and the device-status line that says whether this device can read a card.*

![](assets/help/images/member-badges-dialog.jpg)

*Step 2 — a member's badges: QR badge and registered card, each with its revoke and its own "signs me in" switch.*

![](assets/help/images/my-badge-code.jpg)

*Self-service: Settings → My badge mints the printable QR badge; the badge code is yours alone to set.*

## 9. Money (Finances tab)

Your ledger answers *what do I owe, what am I owed* — and *how much can I still book*. In portrait the month's bill scrolls above the action buttons; in landscape the actions move into a side panel and the bill fills the rest. The **‹ month ›** header browses any month; the **PDF button** exports the visible bill (§ below).

**The bill, card by card:**

- **This month** — how many **days** your subscription includes this month, how many you've **used**, how many are **left**, with a progress bar. A booked morning counts as 0.5 days — unless it lies wholly outside the working hours and the workspace's outside-hours policy makes it free or exempt (§4b): the very same rule drives the quota here and the amount on the bill. The monthly entitlement follows the workspace's open days and your percentage — the subscription card beneath spells it out (*3 of 42 half-days used, 21 open days*).
- **Overage** — the extra half-days beyond your plan, at your fee tier's rate.
- **Consumed services** — each service consumption with the services total.
- **Accessory supplements** — the per-half-day extras attached to the seats you booked.
- **Level, office and desk reservations** — whole-space bookings, each at its price per half-day.
- **Day packages** — packs bought this month.
- **Open positions** — everything still *awaiting validation* (expenses, service consumptions…), in its own amber-rimmed card: these amounts are not yet on the bill.
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
- **Documents** — **Invoices** (yours are always readable here: positions, balance, status — and for issuers the invoicing hub, §11), **My conditions** (which renders the document titled *Financial agreement*) and the **monthly payments report**, self-service (§11).

Finances has **four faces** along the top — **Statement · Payments · Invoices · Documents** (§9c–9f) — sharing the **‹ month ›** chooser and the **PDF** button; the shield, the bell and the gear sit in the app bar as everywhere else.

### 9a. Once the month is invoiced, the invoice decides

- Your bill shows an **invoice card** — number, state, total, what's paid, what remains — and the month reads **settled** as soon as the invoice is paid, its remainder cancelled, or its credit note refunded, even when the settling payment was recorded in a later month. A **partially paid** invoice keeps the month outstanding at exactly the **remaining** amount (that's also what *Pay online* charges). A **credit note** month shows what the workspace owes you back — nothing to pay on your side.
- **Your account** — when you hold spare credit (an avoir, or payments left over from a past month), the Finances tab shows your real cross-month position above the bill: **credit on account**, every **open invoice** with its remaining amount, refunds the workspace owes, and the resulting **net position**. Your credit can settle open invoices — the workspace applies it when matching payments (imputation). Months before your membership began owe nothing and never read outstanding.

### 9b. Quick view, save, share — every report

Every report in the app — the bill, invoices, proformas, credit notes, your self-service documents — offers the same three actions: **Quick view** (see the rendered document on screen before any PDF exists), **Download PDF** (save locally) and **Share PDF** (hand it to any app — WhatsApp, mail, …).

**Reports speak the reader's language:** a document prints in the **member's** language when a template exists for it, otherwise in the **workspace language**, and failing both in the **language of the workspace's country** (§11 templates per language). Where that country has no single language, the app does not guess — it refuses and asks you to *set the workspace language first*.

**Every document as a standard letter (#874).** With *Letter standard for every document* on, a document the owner never designed — invoice, proforma, statement, financial agreement, payments report, consumption report, every reminder level — prints as a positioned letter: the letterhead at 20 mm, the recipient inside the DL envelope window (110 mm across, 45 mm down), the identification block resuming at 90 mm, one footer on every page with the bank details and the reference, a short strip on pages 2+. Fold on the marks and the address shows. A designed layout always wins; `dart run tool/report.dart default --kind usage` prints a default to start from.

### 9c. The Statement face

**The month as it stands.** Your account (the real cross-month position), the **This month** card (days included, used, left), the **subscription** card, **consumed services**, **accessory and space supplements**, **day packages**, **open positions** still awaiting validation, **payments & credits**, the month's **invoice card** once invoiced (§9a) and the **balance**. Read-only: nothing to press here except the **‹ month ›** chooser, shared by all faces.

![](assets/help/images/statement-account.jpg)

*The top of the Statement: your account (the real cross-month position) and your negotiated conditions — the tariff beside your prices, with Who can see.*

![](assets/help/images/statement-balance.jpg)

*The bottom of the Statement: services, pending items still awaiting validation, payments & credits, and the balance.*

### 9d. The Payments face

**Settle and ask.** An **overdue strip** when an invoice is past the workspace's payment term (§11e), the **balance**, the **payment instructions** and **Pay online** while something is owed, then the actions: **Record a payment**, **Buy a package** (package plans), **Submit an expense**, **Request extra half-days**, **Add a consumption**.

**Supplies (#731).** Bought coffee capsules or vacuum bags for the space? In **Submit an expense**, switch on *This is a supply for the space*, name the item (or pick an existing one), the quantity and what one consumption will cost (prefilled from amount ÷ quantity). Once the expense is validated you are reimbursed as usual **and** the item goes on the shelf as a consumable service with that stock; members who use it add a consumption and pay for it, the stock counts down, and at zero the item cannot be consumed until the next supply. Feature *Supplies from expenses* (needs Services).

![](assets/help/images/finances-payments.jpg)

*The Payments face: the balance and its state, Record a payment, then Submit an expense, Request extra half-days, Add a consumption.*

### 9e. The Invoices face

**What was I invoiced?** A headline card — *nothing open, you are up to date*, or *N open · amount due*, with overdue count — then **every invoice issued to you**, newest first, each with its status chip, **due in N days** or **overdue by N days**, how often it was reminded, and a **pay** button that jumps to the Payments face; tap a row for the detail sheet with quick view, PDF and share. Issuers find the **Invoices** button to the register (§11).

**The journey (#812).** Every row also carries the invoice's **journey bar** — *Issued · Payment · Confirmation · Closed*, the current step ringed — and **your move** in one sentence: *pay X by date*, *you declared X — the workspace is confirming it*, *your payment is registered — the workspace matches it*, *paid on … — closed*. **How it works** on the headline card opens the four steps with what the workspace does and what you do. Feature *The journey of an invoice* (under Invoices).

![](assets/help/images/finances-invoices.jpg)

 

![](assets/help/images/invoice-detail.jpg)

*The Invoices face — the headline card and every invoice issued to you — and an invoice's detail sheet: positions, balance, signature, quick view / PDF / share.*

### 9f. The Documents face

**The rest of the paperwork:** **My conditions** (your financial agreement), the **monthly payments report**, **this month's statement as PDF**, and the **document library** when the workspace uses one (§11d). Switch the faces off in Features → *Finance faces* to get the single column back.

![](assets/help/images/finances-documents.jpg)

*The Documents face: My conditions, the payments report, the month's statement as PDF, the document library.*

### 9g. Price negotiations

**The tariff is the default; your deal is yours.** An owner or a finance admin can propose a **price negotiation** for a member — a monthly fee, an overage rate per half-day, a discount on the supplements (accessories, whole-space reservations) — each optional, the tariff where absent. The proposal lands in Événements for the rule's validators (*Price negotiation* domain, or the default rule); once confirmed it applies from the chosen month and supersedes the previous deal. On your **Relevé** face the card *My negotiated prices* shows the tariff struck through beside your prices, since when, and **Who can see this**: you, the owners and the finance admins — every read by someone else is logged and listed there (§14). Feature *Price negotiations*.

**Services, packages and the occupation (#744).** The deal can also fix the **occupation** — the percentage of open days included each month, negotiated together with its price (applied to the member once validated, the previous value shown beside it) — and a **unit price per service and per package**: a consumption or a package purchase is charged at the member's price, the catalogue price shown struck through in the sheets and on the card.

### 9h. Scheduled expenses

**Subscriptions keep paying themselves — with you in the loop.** Any member, whatever their role, can **schedule a recurring expense** (internet, phone, electricity…): an amount, a first occurrence, a rule — every X days, weeks, months or years — and how long it runs (*X times*, *until a date*, or both; whichever ends first). The **schedule itself is validated first** (its own *Scheduled expense* validation domain), so the amount on it is an amount the validators approved. From then on, every due date **materialises an occurrence and presents it to you** on the Payments face — nothing is ever booked silently:

- Confirm it **at the validated amount** and the expense is added to your expenses immediately — already settled, since the schedule was approved.
- Confirm it **at a different amount** and a short **explanation is mandatory**; the expense then goes through the normal expense validation. Confirmed → added; **rejected → it comes back to you**, and you can change the amount and/or the description and resend it.

The list of your schedules (state, rule, next due date) and the *Schedule a recurring expense* form live behind **Finances → Payments → Scheduled expenses**; ending a schedule is one tap there. Feature *Scheduled expenses* (under the Finances tab).

### 9i. The consumption report

Since the participation is **billed ahead of its month** and **consumed** during it, the month deserves a closing word. **Month consumption report** — on the Usage face and among the Documents — is a letter to the member: what the participation paid for (the fee, the included half-days), what was actually consumed (half-days, supplements), what is left or exceeded, and, beneath, **every usage record** of the month with its counted time. The figures are the statement's and the records' — nothing is recomputed. Like every letter it is viewed, saved or shared, printed with the workspace's letterhead and, once designed, its own layout (the designer lists it as *Consumption report*).

## 10. Kiosk mode (wall tablet)

Mount an Android tablet or iPad by the door and let people check in as they walk in:

1. The owner creates a normal account for the device, joins it to the workspace, and flags it as a **kiosk** in *Members & plans*.
2. **Kiosk mode never starts by itself.** On every app start the tablet asks *Start kiosk mode?* — confirm and the pad locks down: full-screen floor plan only, back button disabled, and on **Android** the app pins itself so nothing else can be opened, which means leaving kiosk mode there involves restarting the tablet. An **iPad** has no such pinning, so only the route lock applies — use iOS **Guided Access** (Settings → Accessibility) to get the equivalent. Choose *Not now* instead and the app opens normally — useful for setup. The kiosk designation itself can be reverted at any time: on the device under **Settings → Kiosk device**, or by the owner in *Members & plans*.
3. Each member carries a **badge** — minted by an admin (*Members & plans → Badges*) or by the member themselves (**Settings → My badge**, §8): a printable **QR badge** and/or their **RFID/NFC card**. Each rides its own feature toggle (**QR badges**, **RFID/NFC badges**), both under *Kiosk mode*, so a workspace can offer one credential, the other, or both.
4. At the kiosk, tap a seat (or **This level** — which needs whole-space reservations enabled *and* that level marked bookable) — **ONE sheet** opens with everything on it: **Check in** already selected (one tap switches to **Reserve** or **Check out**), the **period already derived from the workspace settings**, and the **badge reader live** at the bottom. Under half-days, the part of the day you are standing in is preselected (Morning / Afternoon / Day chips to change it — a running window starts *now*, day-parts already over are not offered at all, and what *is* greyed out is a still-future part while **Check in** is the chosen action, since you cannot be present in advance; after hours a single *Rest of the day* remains, running to midnight and no further, because a booking ends on the day it starts). Under timed granularities: From/To pickers snapped to the slot grid, a check-in's start pinned to *now*. The sheet **names the rule it follows** — the granularity and today's working-hours windows — so what it offers is exactly what the settings allow; on a **closed day** the kiosk says so up front with a banner instead of failing at the end. Reserving a window that has already begun also offers **Check in right away** (on by default): one badge presentation books the reservation *already checked in*. Then present the badge:
   - **Tap the RFID/NFC card.** While the card reader is armed the camera stays down; if NFC is off or absent, the sheet says so explicitly.
   - Or tap **Scan the QR badge** — the tablet reads the printed badge **with its own camera** (front camera by default, since a wall tablet's back lens faces the wall; switch in *Settings → Scan with the front camera*). A USB/Bluetooth wedge scanner or typing the code works too.
5. **The badge IS the confirmation:** it executes immediately, and a **self-dismissing receipt** shows *who* was recognized — with their **profile photo**, where the *Member photos at the kiosk* feature is on — *what* happened, *where* and *until when*, then the wall is clean for the next member. The wall plan shows occupant photos the same way. The happy path is two gestures: tap your seat, present your badge.

**What the wall deliberately cannot do.** Tap a seat someone else holds and the kiosk **names the holder and points you at your phone**: a wall device never sends a message on a member's behalf, because anyone standing in front of it could. The *Message them* action for a blocked space lives in the app (§4b). Everything the kiosk *does* offer is checked by the same server rules as the app — including the past-day guard, the walk-up-must-start-today guard and the same-day rule — so the wall refuses exactly what the plan refuses.

Your identity exists only for the moment of the operation: the credential is sent **only for that operation** — once to identify you, once to carry out the action — and **nothing is stored**, on the tablet or anywhere else. The booking is made **in your name**, and you are "signed out" the instant it completes. (Per-operation Google sign-in is still on the roadmap; **iPads have no NFC hardware**, so on an iPad the camera QR path is the way.)

## 11. Invoicing (owners & billing admins)

*Owners issue invoices; admins too once they hold the **issue invoices** permission (Role management, §8 — or the legacy **Admins issue invoices** feature delegation). The **Invoices** feature sits under Finances in the feature list.*

**Bank details for countries without IBAN (#711).** Under *Payment instructions*, beside the IBAN: bank name, account number, a routing code named the way your country names it — *sort code* in the UK, *routing number* in the US, *transit · institution* in Canada — and a BIC/SWIFT for cross-border transfers. Only filled fields print on the how-to-pay card.

An invoice in DesKilo is generated, never composed: its positions are **derived exclusively from the month's tracked data** — subscription, overage, supplements, services, packages — minus the month's payments and credits, so the bottom line **is the balance due**. Each document snapshots the workspace's and the member's postal addresses (set yours in **Settings → Personal information**; the workspace address is in the workspace settings) and is **digitally signed** at issue — it never changes afterwards. A **detailed annex** (the month's ledger and attendance) can be attached with one switch when issuing.

**The journey of an invoice (#812).** With the feature *The journey of an invoice* on (default), the hub tells the process instead of listing states. A **stage strip** replaces the summary pills — *1 · To issue · 2 · To collect · 3 · To confirm · 4 · Closed* — with live counts (To collect at the remaining value, with the overdue count in red; To confirm holds every invoice whose next move is not the member's: a declared payment awaiting another admin, a registered payment awaiting its match, a match or write-off awaiting the validators, a credit note to refund); each tile is one tap from its tab. Every **open card** carries the **journey bar** (*Issued · Payment · Confirmation · Closed*) and the **next move** as a sentence — *waiting for Flo's payment of €250 — due 27 May*, *Flo owes €250 — overdue by 6 days*, *Flo declared a payment of €250 — another admin confirms it in Events*, *a payment of €250 is registered — match it to this invoice*, *payment matched — awaiting the validators' decision*, *credit note — refund €8 to Flo and record it*. The action that move expects from you is the card's **one labelled button** (*Send reminder 2*, *Mark as paid*, *Record the refund*, *Open Events*); the rest stay icons with tooltips. The **detail sheet** opens on the same bar and sentence, its dated facts under a *Timeline* heading, and the expected action leads the list. The **?** in the header opens **How invoicing works** — the four steps, each with the workspace's side and the member's — the same sheet members open from their Invoices face.

Issuers open **Finances → Invoices** and land on a three-tab hub under a live summary strip (*N to invoice · N open · X outstanding · N to refund · Y*):

- **To invoice** — every member whose previous month has billable data and no invoice yet, with what the month adds up to: issue per member (with a preview of the derived positions) or **Invoice all** in one sweep — which asks for confirmation first, naming the count, the month and the total. The **New invoice** button opens the same sheet for any member and month — member picker, ‹ month ›, the derived positions, the balance, the **detailed annex** switch and **Issue the invoice** (a green *Invoice issued.* snack confirms). **One active invoice per member and month** — a month only becomes invoiceable again after its invoice was cancelled. The issue sheet opens on the **completed month** (the moment its numbers stop moving); pick the running month instead and it warns you, because that month can only be invoiced once.
- **Open** — issued invoices awaiting settlement, oldest first; anything waiting longer than 30 days turns red, in the card and in the summary strip. Every action is an icon with a tooltip (cancel · proforma · reminder · mark as paid). **Tap a card to read the invoice.** **Send a reminder** records the reminder and shares the PDF with a message — the card shows *Reminded ×N*. **Mark as erroneous** cancels the invoice for correction (an explicit dialog warns the action is irreversible): it moves to the archive struck through, and a **replacement** re-derives the same month from the corrected data, referencing the original. **Mark as paid** matches a real payment (below). **A partial payment does not close an invoice**: it stays on Open, badged *Partially paid* with the remaining amount, until the outstanding remainder is explicitly **cancelled through the validation framework** — an admin/owner requests the write-off (with a reason), the validators confirm, and only then does the invoice move to the archive as *Partially paid · remainder cancelled*. **A NEGATIVE invoice is a credit note (avoir)** — the month's credits exceeded its charges, so the WORKSPACE owes the member: its PDF is titled *Credit note*, it gets no reminders and no member-payment matching; instead the card shows *To refund* with **Record the refund** — the payout books against the member's balance (validated like any settlement when a policy applies; a reject reopens it) and the document closes as *Refunded*. The summary strip separates the two directions of the payment process: *N open · X outstanding* counts positive invoices at their **remaining** value (a €500 invoice with €280 paid counts €220), while *N to refund · Y* totals the open credit notes the workspace still owes.
- **Archive** — closed invoices, filterable by member and month and sortable; cancelled invoices are **hidden by default** — the *Show cancelled* chip brings the correction trail back; the bar under the filters says how many invoices match and **Clear filters** brings the whole archive back. Each row carries its status chip (*Paid*, *Partially paid*, *Erroneous* struck through, credit notes with their negative amount), its month and its amount, with **Download PDF** right there. **Tap a row to open the invoice** — positions, balance, who it was billed to, where it stands (*Paid €300.00 on Aug 6*, *Reminded ×1 · last reminder…*, *Annex: 5 entries, 10 check-ins*), which invoice it replaces or was replaced by, its signature — and every action it still allows, spelled out: **Quick view**, **Download PDF**, **Share PDF**, export the **e-invoice (XML)**, remind, mark as paid, mark erroneous, issue a replacement.

**Marking as paid means matching a real payment — or applying a credit.** The dialog lists the member's registered payments — recorded transfers and confirmed online payments — and you map the invoice to one of them; there is no amount to type (no registered payment yet? the dialog says so: *record it or confirm it first*). It also lists the member's **account credits** (credit-note excess): matching one imputes the avoir on the invoice, past months included — the standard alternative to a cash refund, for associations and companies alike. Each credit spends exactly once: one already deducted inside an issued invoice can never settle a second document. Paid **more**? Create a **credit note** for the excess (a credit on the member's ledger) or force-accept with a mandatory note. Paid **less**? Accept it with a mandatory note. Everyone with invoicing access is notified of paid invoices, and the owner can put an **Invoice payment** validation rule (§7) on them: the match then waits for the quorum — a reject reopens the invoice.

**A paid invoice is definitive.** Once matched it can never be cancelled, replaced or altered — corrections happen before payment, by cancelling the open invoice and issuing its replacement. A payment that did **not** cover the whole amount, accepted with a note, shows as **partially paid** rather than paid.

**Proforma.** Two of the hub's three tabs carry a proforma action: on **To invoice** it renders the month's derived positions as a quote — no number, no signature, stamped PROFORMA, and **nothing is issued**; on **Open** it re-renders the issued invoice as a payment request that cannot pass for the original. Both offer the quick-view / download / share triad.

**Stamps.** A cancelled invoice carries a large diagonal **ERRONEOUS** across every page of its PDF, in light grey over the content: it cannot be mistaken for a valid document on a desk or a photocopy. The same stamp says **PROFORMA** on a quote, and **COPY** on any invoice rendered by someone other than its issuer — the workspace holds the original.

![](assets/help/images/dunning-rules.jpg)

*The reminder rules: levels, days until the first reminder, days between levels — and the Automatic reminders switch.*

**Reminders (Mahnwesen).** The owner sets the **reminder rules** (checklist icon in the Invoices header, or *Workspace settings → Reminder rules*): how many levels, days until the first reminder, days between levels. Overdue open invoices are flagged **"Reminder N due"** and the bell icon on the card turns red — nothing is sent for you unless **Automatic reminders** is on (§11e). A manual reminder is recorded at its level and lands in the member's feed exactly like an automatic one (#816). Sending generates a **payment-reminder letter** (level 1 friendly, higher levels firmer) from that level's template — shipped ready-made in your language, printed in the *member's* language, and editable per level in the report editor with the extra fields `{{ reminder_level }}`, `{{ reminder_date }}` and `{{ days_open }}`.

![](assets/help/images/invoice-register.jpg)

*The register: one line per invoice, the sum at the foot, the year picker, and the accounting-export button (SAF-T / FEC).*

**The register.** The list icon in the Invoices app bar opens a one-line-per-invoice ledger: **date · name · amount · status**, sorted by date (tap the Date header to flip the direction), with the sum at the foot, and a **year** picker once there is more than one. Its export button opens the **Accounting export** sheet: **SAF-T (XML, international)** and — for a French workspace — **FEC (France, required in a tax audit)**.

**Handing the period to your accountant.** From the register, issuers export **SAF-T** — the OECD's *Standard Audit File for Tax*, the XML accounting software and tax administrations read. It covers exactly what the register shows, so picking 2026 gives you the 2026 file: the company as your own invoices state it, every customer, every invoice with its lines and totals, and the payments that settled them. Cancelled invoices stay in the file marked *annulled* — an audit file never deletes what happened. What it deliberately leaves out is the **chart of accounts**: DesKilo does not invent account numbers, because a wrong code has to be unbooked by hand. Your accountant maps the invoices onto their own accounts, which is their job and takes them a minute.

**France: the FEC.** A French workspace gets a second choice, the **FEC** (*Fichier des Écritures Comptables*) — the file an audit legally demands (art. L47 A-I du LPF). It is not XML: a tab-separated flat file of accounting **entries**, named `<SIREN>FEC<YYYYMMDD>.txt` as the arrêté requires, with the 18 mandated columns in their mandated order. Because it is made of entries it *cannot* avoid account numbers, so the export asks for them first — pre-filled with the *plan comptable général* (411 clients, 706 prestations, 512 banque) and yours to correct. Each invoice books its receivable against revenue at the **gross** amount, the credits it netted and the payment that settled it book as cash on their own dates, lettered with the invoice number. Cancelled invoices are absent: one voided before payment was never booked, so there is nothing to reverse. The *name* column follows the reader — an issuer scans member names, a member scans their own invoice numbers. Members see only what concerns them: issued, and never a cancelled one.

![](assets/help/images/invoices-admin.jpg)

*The issuers' hub: To invoice · Open · Archive under the live summary strip; an open invoice with its four actions (cancel · proforma · reminder · mark as paid).*

![](assets/help/images/invoices-to-invoice.jpg)

 

![](assets/help/images/invoice-new-sheet.jpg)

*To invoice with nothing left and the summary chip — and the New invoice sheet: member, month, the derived positions, the detailed annex switch.*

### 11a. Legal identity, VAT & mentions

**Before the first export, fill in the legal identity.** In *Workspace settings → **Legal identity & e-invoicing*** the owner declares:

- The **VAT regime** — it decides the number the EN 16931 norm demands: outside the scope of VAT, a **company registration number** (SIREN, HRB, CIF…); VAT-exempt under a small-business scheme, a **VAT number** plus the **reason no VAT is charged** (the field suggests the proper wording — *TVA non applicable, art. 293 B du CGI*, or for services to members of an association *Exonération de TVA, art. 261, 7-1° du CGI*). The regime is enforced end to end: only a VAT-registered workspace ever stamps a rate onto a subscription, supplement, service or package, and the VAT pickers simply disappear under any other regime.
- The structured **address** (street, postal code, city) beside the free-text letterhead address.
- The **e-invoicing platform** (§11b).
- The **invoice mentions**, with an **Organization type** switch — *Company / business* vs *Association (loi 1901)*: legal form & capital (e.g. *Association loi 1901*), trade register (companies: RCS; associations: **RNA W… · SIRET if assigned**), payment terms, late-payment penalty, the **€40 recovery indemnity**, early-payment discount (escompte), professional insurance, special mentions. Each clause prints the statutory default wording when left empty — and an association's documents drop the B2B-only clause defaults (late penalty, recovery indemnity, escompte are mandatory only between professionals; whatever you type still prints).

Members add their **country** — and their VAT number if they invoice as a business — beside their address in *Settings → Personal information*. DesKilo checks all of this **before** producing an e-invoice and refuses with the missing item named, because an invoice a platform rejects is worse than no invoice.

**Your personal information (#886).** *Settings → Personal information* holds what every document prints about you: first name and **family name** (written in capitals on documents, as on official mail), an optional **company**, street, postal code, city, country, telephone, the **e-mail your documents go to**, and — if you invoice as a business — your VAT number and registration id. The form previews the block exactly as the invoice's envelope window will show it: name, company, street, `POSTAL CITY`, and the country only when you live abroad. Lists and documents call you by this name; the free-text address of older versions remains the fallback until you fill the form.

**Managed profiles (#887).** Someone joins the association before they have the app? An admin opens **Members → Add a managed profile** and fills in the same identity form. The member exists at once — you book seats for them, issue their invoices (printed with the identity you typed), set their subscription — and their page carries a **Managed** chip. When the person is ready, **Hand over to the person** mints a personal code bound to that profile (QR, link or message, like any invitation). They create their account, enter the code, and take the profile over: reservations, invoices and subscription stay theirs, the identity you typed lands in their own settings (their data from then on — only fields they left empty are filled), and the membership goes through the usual join approval. **Revoke handover** withdraws an unused code.

**A client can be a company (#910).** A managed profile does not need a first name: a **company name** is enough. When no personal name is given, the company becomes the addressee — on the invoice, in the lists, in the payment thread — and it then drops out of the address beneath it, since it is already the line above. Name a person and nothing changes: the company stays in the address block, between the name and the street. Documents already issued benefit too — the company name was frozen on them all along, it simply was not read.

**The company first, the person after (#912).** When a client carries both a company name and a personal one, the document is addressed to the **company** — it is the company that owes the invoice — and names the person on the line below, with the form of address they chose:

> SASU KaloA
> Mr Guilhem MARTIN
> 209 rue Jean Bart, Immeuble AGORA 1B
> 31670 LABÈGE

The **form of address** is a field in your personal information: *Mr*, *Ms*, or *None*, which prints the name alone. It is never guessed from a first name, and each reader sees it in their own language — *Monsieur* in French, *Herr* in German. With no company, nothing changes: the person stays the addressee.

**The due date is on the document (#910).** Every invoice now prints its **settlement date**, taken from the delay in your reminder rules — the same delay the app counts down in the payment thread, so the two can no longer announce different dates. A design can place it anywhere with `due_date`. And a one-page document no longer carries a page number: "1/1" tells nobody anything.

**Prices in DesKilo include VAT.** What you type as a subscription price, a service price or a day-pack price is what the member pays. Turning VAT on does not change a single amount anyone owes — it says how much of that amount is tax. That is why a bill, a statement and a quota never move when you add rates, and why no total ever needs reconciling. Under a VAT-charging regime the catalogue says so out loud: every service and day-pack row names its included rate (*incl. VAT 20 %*), the billing editor lets the owner pick the tariff's own VAT rate (default: the workspace default) and shows the VAT share inside each band amount as you type, each accessory can carry its own rate (default: the workspace default), and every price field reminds you it is gross.

**Setting the rates.** *Legal identity & e-invoicing → **VAT rates***. An empty list means VAT is off, which is how every workspace starts. **Use the usual rates** fills the list with your country's standard, intermediate and reduced rates as a first draft — a starting point, not tax advice. One rate is the **default** (the star): subscriptions, overage, supplements and adjustments use it, and so does every service that has none of its own. A service and a day pack each carry their own rate, picked in their editor. Removing a rate never deletes it — one an invoice or a service still refers to is kept, deactivated, so nothing is silently re-taxed. All of this is the *VAT management* feature toggle: switched off, the rate editor and every rate picker disappear while the stored rates keep applying — the tax math itself is never toggleable — and the *VAT declarations* toggle lives beneath it.

**The periodic VAT declaration** (*VAT rates → VAT declaration*, VAT-registered workspaces only). Pick the filing period — a month or a quarter, whatever your regime requires — and **Generate**: the app aggregates that period's issued invoices per rate **with the exact arithmetic the invoices carry**, so the return matches every document to the cent. The result shows the per-rate net base and output VAT, mapped onto your country's **official form lines** (France's CA3 boxes 08/09/9B/11, Germany's UStVA Kennzahlen 81/86, a generic per-rate list elsewhere). Every declaration exports as **PDF** and **machine-readable XML**; if an upload platform is configured under e-invoicing, **Transmit** sends it there electronically and records the acknowledgement — otherwise take the numbers to your tax portal (EFI, ELSTER…) or your accountant and **Mark as filed**. Either way the declaration becomes immutable, with its channel and receipt on record. The catalogue of suggested rates covers every EU member state, Switzerland (including the 3.8 % accommodation rate), Norway and the Canadian provinces; the US has no federal VAT, so the app says so instead of guessing. A filing aid, not tax advice — verify with your accountant.

**What it changes on a document.** An invoice issued after the rates exist carries the breakdown as issued: the positions table gains a rate column, and above the total the PDF shows the **net** and one line per rate. The **e-invoice (XML)** carries what EN 16931 requires in both UBL and CII; **SAF-T** declares each rate in its tax table; the **FEC** books the receivable gross against revenue net plus a **collected VAT** account (445710 by default, yours to change).

**An invoice already issued never changes.** It carries the rates, the identity and the amounts it was signed with — that is what makes it an invoice. If a document has to carry new figures, mark it **erroneous** and issue a **replacement**: the correction chain is visible on both documents, which is exactly what an audit wants to see.

**Invoicing a business in another EU country (#895).** A workspace that charges VAT does not charge it to a **business in another member state**: that customer self-assesses the tax (art. 196). When the customer's profile carries a VAT number and a country different from yours, the invoice is issued **without tax**, states the category the norm wants (AE) and prints the statutory mention — *Autoliquidation*, *Steuerschuldnerschaft des Leistungsempfängers*, whichever your country speaks. The price stays the tariff: nothing is added, nothing is taken off. The e-invoice check refuses to send such a document until the customer's VAT number is there, since it is what proves the tax is theirs. A workspace that never invoices businesses abroad turns the whole thing off on *Legal identity → Reverse charge for EU businesses*.

**When VAT falls due (#896).** A VAT-registered workspace declares either **on invoices** — the tax is due when you issue the document — or **on receipts** — it is due the day the customer pays. In France services are on receipts unless you opt for invoices; Germany calls it *Ist-Versteuerung*, Italy *IVA per cassa*. Choose in *Legal identity → VAT falls due*. On receipts, a period declares **the payments received inside it** rather than the documents issued: a part payment carries a share of every rate in the document, in proportion, and the rounding goes to the widest rate so the total matches exactly what was received. The accountant's VAT report follows the same rule — a position there is a payment, dated the day it arrived — so report and declaration cannot drift apart. Every invoice prints the matching mention, and the declarations screen names the basis in use.

**A reversal gives back the tax too (#894).** A credit that cancels a VAT-bearing charge now names the rate it reverses, so the document's breakdown shows that tax as negative and the declaration nets it out — a distributed expense given back (#828) reverses at the rate it charged. Money moving — a payment, a reimbursement — carries no rate and never touches the tax, as before. A document whose total is negative is typed as a **credit note (381)** in the e-invoice, not as an invoice.

**Payment conditions per member (#881).** The wording above is the workspace's default for everyone. A member may carry **their own** — a longer payment term for a key account, say. It is never typed on the member directly: an admin holding the *Request payment-condition changes* permission opens the member's page, **Payment conditions → Request a change**, fills only the fields that differ (an empty field keeps the workspace's wording) and gives a reason; the request becomes a **Payment conditions** validation card decided like every other domain (the owner, by default), and the override applies on confirmation. The member sees the effective conditions read-only on their page and in **Settings → Payment conditions**, labelled *Workspace default* or *Member's own*; every invoice and reminder prints the effective ones, and a layout may test `payment_terms_source`. *Use the workspace default again* asks to drop the override — through the same validation.
**VAT — the compliance checklist (#878).** Reviewed 2026-09-05 against Directive 2006/112/EC and EN 16931 (ADR 0015). What holds: the seller's regime is **frozen on each document** at issue (an association that becomes exempt keeps its earlier out-of-scope invoices as they were); the per-rate breakdown is frozen too, rounded per line exactly as the server does; numbering is continuous and documents never change (corrections void and reissue). What the app now does for you: an **exempt or out-of-scope seller's documents print the statutory mention of their country** (FR art. 293 B CGI, DE § 19 UStG, AT, ES, IT, BE, NL, LU, else the Directive) when you wrote none in *Legal identity*; the e-invoice check **warns when a customer's VAT number does not have its country's shape**. What stays the owner's: keep the rate catalogue current when a rate changes; a VAT-charging seller must hold a VAT id. The three limits the review recorded are now closed: credit notes reverse VAT (#894), intra-EU reverse charge is decided at issue (#895), and the cash basis is a workspace setting (#896).
**The VAT report (#878).** On *VAT declarations*, for the selected month or quarter: **VAT report (PDF)** — every taxable position (document, date, customer, net, rate, VAT, gross, category, the reversed original when any), subtotals per rate and category, period totals — as a letter you can view, save or share and design like every document (*VAT report* in the editor); **VAT report (CSV)** — the same positions, semicolon-separated, for the accountant.

### 11b. Where the e-invoice has to go (EU)

The **e-invoice (XML)** action opens a sheet that answers this for the workspace's own country before handing the file over: which channel business customers expect it on, whether a platform sits in the path, and which channel public buyers use. Four models exist in the union:

- **Peppol** — an access point delivers the file to the customer; no government platform in between. Belgium's B2B mandate works exactly this way, and Peppol is how public buyers are reached across the EU (Directive 2014/55/EU makes every authority able to receive an EN 16931 invoice).
- **Accredited platforms** — France: you pick a *plateforme agréée* (the renamed PDP), it routes the invoice and reports the data to the tax administration. The public portal is a directory, not a mailbox. Public-sector invoices stay on **Chorus Pro**.
- **Clearance platforms** — Italy (**SdI**, FatturaPA), Poland (**KSeF**, FA(3)), Romania (**RO e-Factura** via the SPV, CIUS-RO): the platform receives the invoice *first* and passes it on; sending straight to the customer is not an option. Each mandates its own syntax, so the sheet warns that the EN 16931 file DesKilo exports is not the one they accept — use it for Peppol, public buyers and foreign customers, and let your platform or accountant convert.
- **No imposed channel** — Germany today: receiving has been mandatory since 2025 and issuing phases in, but an e-mail attachment is a legal e-invoice; XRechnung and ZUGFeRD are the expected syntaxes. Public sector: **OZG-RE / ZRE**, or Peppol.

**Factur-X — one file, both readers.** The e-invoice sheet offers **Factur-X (PDF)** first: an ordinary-looking invoice PDF with the machine-readable invoice *inside it* (the EN 16931 data as CII, which is what the format mandates). A human opens it and sees the invoice; a platform opens it and finds `factur-x.xml`. It is what most French and German small businesses actually exchange, and it needs no second file. The plain **XML** stays available underneath for platforms that ask for it bare.

**Sending it, without leaving the app.** The owner registers the workspace's platform in *Legal identity → **E-invoicing platform***: an **upload URL**, a **token or credential**, optionally the **Authorization header** shape and the **file field name**. Any platform that accepts an upload with a credential works — a *plateforme agréée*, a Peppol access point, a national platform. The token is stored server-side, never travels back to a phone, and the app can only tell you that one is set. Once configured, the e-invoice sheet leads with **Send to the platform**: the Factur-X document goes straight out, and the invoice's detail sheet records when it left, what the platform answered and the id it gave back. Every attempt is logged — accepted, refused or undelivered — because a document that *may* have left is worse than one that failed.

**A second leg, straight to the customer.** Reaching the government platform is not the same as reaching the buyer, and several customers run their own receiving service. So the same screen takes a **second destination** — the customer's endpoint, with its own URL, token, Authorization header shape and file field name — and the send sheet then offers both legs, each recording its own transmission history. It rides the **E-invoice delivery to the customer** feature, under *Invoices*; leave it off and only the platform leg exists, exactly as before.

**Rehearsing without risk.** The same screen takes **test endpoints** (the platform's UAT or a dev target: URL + token each) next to the production one. With the workspace's **developer mode** on (a workspace-wide setting only owners and admins can flip, under Settings → Advanced), sending offers the choice of environment, a test submission is marked as such on the invoice's transmission history, and the production endpoint is never used for a rehearsal — an unconfigured test environment simply refuses instead of falling back.

DesKilo still transmits nothing on its own account: it produces the document and hands it to the platform you chose. Mandate calendars keep moving: check your own tax administration before the deadline that concerns you.

### 11c. The report editor — every document, four presets, five languages

The **Invoice PDF template** (pencil icon in the Invoices header, or *Workspace settings*) is a banded reporting tool for every document the app prints. Three report **bands** render onto the PDF — header, body (the invoice lines), footer — while the e-invoice XML is never touched.

- **One report per document**: chips switch between **Invoice · Proforma · Statement · Agreement · Payments · Workspace · Reminder levels**. The proforma falls back to the invoice bands until you customize it; a customized statement replaces the built-in monthly-bill PDF.
- **Per language**: a second chip row — *Default (all languages)* · EN · FR · DE · ES · IT — stores a translation overlay per document; a member's report prints in *their* language when a template exists for it, else in the workspace default.
- **Markup or Visual**: the **Markup** mode edits the bands as text — [Liquid](https://shopify.github.io/liquid/) conditions and loops (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) plus a simple line markup: `#` title, `##` section, `>` small print, `---` divider, `a | b` table row, `=` bold row, `::: … ||| … :::` side-by-side columns (the seller-left / client-right address block and the right-aligned totals of a French facture — the shipped templates follow that exact structure), `![name]` an image from the workspace's **image library** (*Insert an image*). The **Visual** mode is a page-true design surface in the professional-designer tradition (Crystal Reports, Docentric): the three bands are edited **on a white A4 page** at the document's own margins, in the document's exact print typography — same font, sizes, colors and right-aligned amount columns as the generated PDF — with labeled band strips, dashed page-break guides where the PDF will paginate, and a zoom control (fit width, 75/100/150 %). `{{ tokens }}` stay highlighted; tap a line to edit it in place, add lines, move them, insert data fields from a palette. A **Design ↔ Preview** toggle merges your unsaved bands with your live (or sample) data through the real report engine on the same page — fields out, values in.
- **Templates gallery** (*Templates*): four ready-made presets for every document — **Classic · Simple · Detailed · Formal letter** — pick one and extend it. Every invoice preset already carries the statutory mentions (§11a).
- **Quick preview** renders the result instantly in the app — your newest invoice, or simulated sample data when none exists (watermarked *sample data*) — no PDF round-trip; **Preview** produces the PDF; **Reset to default** hands back the built-in layout as a working example. A broken template never blocks a document — the built-in layout takes over; the void watermark, digital signature, annex and page numbers stay fixed.
- **Full-screen designer** (flag *Report designer*): the editor opens as its **own page**, in Visual mode, with **Undo / Redo** and **Save** in the toolbar. Tap an element and it is edited **in its own typography** — the title in title size, the small print small. The **+** under the active element inserts a **typed element** below it (title, section, text, small print, table row, divider, spacer, image, columns, logic); the **{ }** button opens a **searchable field picker** grouped by document, member, amounts, legal mentions and loops; **long-press and drag** a line to reorder it, or send it to **another band** from its menu. An image carries its **size** (small, medium, large) and **alignment** (left, centre, right), written as `![name|l|center]`. *Templates* and *Reset* ask before replacing a layout you have; leaving with unsaved work asks too. When a template does not render, the preview **says which band and why** instead of a generic error. On a wide screen **design and preview sit side by side**, and the page counts how many pages the document will print on. The three structural documents — **Chart of accounts · Member badges · Space QR cards** — have their own chips.

Template variables (invoice family): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (each with `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — and the legal set: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

![](assets/help/images/report-designer-markup.jpg)

*The Markup mode: the three bands as text, the variable legend, the per-document and per-language chips.*

![](assets/help/images/report-designer-design.jpg)

 

![](assets/help/images/report-designer-preview.jpg)

*The Visual mode — Design edits labeled bands on the true A4 page; Preview merges your unsaved bands with live data through the real engine.*

### 11d. The report suite & the document library

- **Financial agreement** — every standing price that applies to a member: subscription, extra half-day, services, packages, accessory supplements and the whole-space prices, **desks and tables included**. Owners/admins send it from a member's action sheet; every member can quick-view/download/share their own from *Finances → Documents*.
- **Payments report** — everything you paid, declared or had validated in a month: your little balance sheet, self-service on the same row.
- **Workspace report** — identity, floor-plan counts, availability, features and prices: *Workspace settings → Workspace report*.
- **Document library** — *Settings → Documents*: the workspace's statutes, user guides, financial statements and meeting minutes, LINKED from whatever system you already use — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud or any https link (the drive keeps managing its own access; the app never stores foreign credentials). Every entry has a **visibility role**: every member, admins and owners, or owners only — enforced server-side, so a member never even downloads a list containing board documents. Admins and owners curate with the + button; a *Document library* feature toggle gates the whole thing.

![](assets/help/images/documents-library.jpg)

 

![](assets/help/images/documents-add-dialog.jpg)

*The document library, and adding a document: title, link, storage, category, visible by.*

### 11e. Automatic payment reminders

With **Automatic payment reminders** on (Features, child of *Payment reminders*) and the switch **Automatic reminders** in the reminder rules (Invoices → Reminder rules), the dunning levels apply themselves: every morning — and whenever an owner or admin opens Finances — an **open** invoice whose waiting period has run (the *days until the first reminder* from its issue date, then the *days between reminders* after the previous one) gets its next level recorded. The member sees a **Payment reminder** alert in Événements ("Reminder 2: invoice X — amount still due") and receives a push; their Invoices face reads *overdue by N days*. Levels never exceed the configured count; a matched invoice is never reminded; switching the rule off leaves reminders a manual action, one tap per invoice as before.

### 11f. Regrouping invoices (settlement)

**One document instead of three.** A member on the split billing cycle (§11) can hold a subscription invoice, an end-of-month invoice and last month's leftover at once. **Regroup into one invoice** (merge icon in the Invoices header, feature *Regroup invoices*) folds a member's open, unpaid invoices into one **settlement** invoice carrying their sum. The sources are **not cancelled**: they stay in the archive exactly as issued, each pointing at the settlement that now carries its balance, and the settlement lists every source with its positions. From then on the settlement is what is owed, paid and reminded; a source can no longer be cancelled, replaced or matched on its own. VAT is not restated — each source already declared its own tax, so the settlement's lines carry 0 % and name the invoices that carry it.

**Validated like any payment.** A settlement is an *invoice payment* event: where the owner put a rule on that domain (§7) it waits for the validators; a **reject** — or an expiry — cancels the settlement document and releases its sources, which are owed separately again. **Cancelling** a settlement (*Mark erroneous*) releases its sources the same way.

**Regrouped invoices fold under the regrouping one (#831).** The regrouping invoice now carries **every line of the invoices it replaces**, grouped under their numbers, with their VAT — it is complete on its own, and it is the one that is owed, chased, matched and closed. The regrouped invoices leave the open list, the archive and the member's list as peers and **nest under the regrouping invoice** ("Regrouped in INV-…"), in the hub and on the member's side. Opening one shows a banner saying so; every operation on it is off; the one thing left is its **PDF, stamped with the number it was regrouped in**. For the accountant, the regrouping document is transparent: every export and the VAT declaration carry the original invoices, and the payment received on the regrouping is allocated to them, oldest first — each original is lettered exactly as if it had been paid on its own. In the app, an original reads "Paid through INV-…" once its regrouping is paid. When you download, share or preview a regrouping invoice, it asks whether to attach the invoices it replaced: attached, each follows on its own pages, after the new one and never running into it, stamped as regrouped.

### 11g. The month-close wizard

The three assistants — **month close**, **regroup into one invoice**, **distribute an expense** — share one shape (#872): numbered steps across the top, the step's content, then **Back · i / n · Next** and a closing action on the last step. Learn it once; every toolbar entry is named *Assistant · …*.

The **month-close wizard** (flag *Invoicing wizard*; the wand in the Invoices header, or the card on top of *To invoice*) strings the whole invoicing work into **one guided process** with a step rail: **Review** (which run, which period, what is pending), **Issue** (the run's invoices in one batch — members already covered show as done, untick anyone to leave them out), **Send** (share or download each PDF), **Remind** (everything overdue by your reminder rules, recorded and pushed in one tap, the letter one tap per row), **Payments** (confirm or reject what members declared; **register** a bank or cash payment for a member — they confirm it from their side), **Match** (every open invoice against the member's credit; rows with credit are ready), **Close** (regroup a member's several invoices into one, write off a remainder, refund a credit note — each through validation) and **Summary** (what the run did, and what is still open with whose move it is). Two runs: **Start of month** for the subscriptions paid ahead (the wizard suggests it from your advance window), **End of month** for the usage, consumption and extra charges of the month that just closed.

### 11h. Shared expenses, distributed

**Distribute an expense** (flag *Shared expenses*; the split icon in the Invoices header) takes one shared cost — a cleaning bill, an internet upgrade, a broken chair — and splits it over the members: **equal** shares, **pro rata of the subscription** percentage, **pro rata of usage** (half-days used in the period), or a **custom key** typed per member. Every share is previewed, the cents add up exactly, and nothing is booked until you confirm. The shares are booked as adjustment lines on the period you choose, so they appear on each member's **next usage invoice** (the end-of-month run of the wizard, §11g). Flip **Reversal** to give money back instead: the same split books **credits**, which net against the month's charges and, when they exceed them, derive a **credit note** the workspace refunds (§11). A distribution is an event of its own kind: with a validation rule on *Shared expense* it waits for the quorum and books once confirmed; without one the issuer's decision stands. The history under the form shows every distribution and where it stands.

### 11i. Usage: what each booking actually cost

**Usage** (flag *Usage records*; a face of the Finances tab) shows the month's counted bookings, one card each, with three numbers kept deliberately apart: the window **booked**, the time you were actually **present**, and what of it is **billed**. Booking is the commitment; presence is the fact.

Two rules follow from that, and the cards say both out loud. A booking **nobody checked into bills in full** — not turning up is not a discount. And a booking you **left early** bills in full too, until somebody else agrees otherwise: the card offers **Bill the time I was here**, which asks for the unused time to stop counting. You never decide that request yourself; it goes to whoever your *Early departure* validation rule names, and if there is no rule it stands at once. Accepted, the booking's own end moves to the moment you checked out, so the statement, the half-day cap and the invoice all follow — and the card keeps saying what the billed time **was**, so both numbers stay readable side by side.

You see your own records; whoever may see the workspace's money sees everyone's. An admin or owner can **remove** a record, and where a *Usage record removal* rule is configured the member concerned is the one who validates it.

### 11j. Taking a report design out, and bringing it back

**Export this design** (flag *Export and import report designs*, in the report editor) writes the open report's layout to one JSON file. **Import a design** reads one back.

The file is not a bare dump. Beside the three bands it carries a `howToEdit` block naming what each band is for, the Liquid syntax, every markup line the renderer accepts, the image sizes and alignments, and the full list of placeholders — enough that a person, or a tool such as Claude, can open it, change the layout and hand it back without guessing. That block is regenerated on every export, so editing it does nothing and cannot corrupt a design; only `kind`, `language` and `design` are read on the way in.

Every report has this — invoice, proforma, statement, financial agreement, payments report, workspace report, chart of accounts, member badges, space QR cards and each reminder level — and a report added to DesKilo later gets it automatically.

An import is **refused with the reason** when the file is not readable JSON, is not a DesKilo design, was written by a newer version, is for a report this workspace does not have, or belongs to a **different** report — a design is never silently retargeted. An accepted import lands in the editor, not in the workspace: nothing changes until you press **Save**, so you can preview it first and leave without keeping it.

## 12. Settings & profile

Your personal screen, top to bottom:

![](assets/help/images/settings-personal.jpg)

*The personal block: profiles, photo, region & formats, WhatsApp, status, default booking period, address, help, badge.*

![](assets/help/images/settings-admin.jpg)

*For owners, the Administration section follows — every admin screen of §8 starts here.*

![](assets/help/images/settings-preferences.jpg)

*Preferences and Advanced: language, theme, front-camera scan, push status, developer mode.*

![](assets/help/images/settings-about.jpg)

*About: version, author, the open-source licence, the privacy policy, bug reports, and how to support the project.*

![](assets/help/images/profiles.jpg)

 

![](assets/help/images/region-formats.jpg)

 

![](assets/help/images/linked-accounts.jpg)

 

![](assets/help/images/settings-language.jpg)

*Four of the personal screens: Profiles, Region & formats, Linked accounts, and the Language chooser.*

![](assets/help/images/settings-whatsapp-dialog.jpg)

 

![](assets/help/images/settings-status-dialog.jpg)

 

![](assets/help/images/settings-address-dialog.jpg)

 

![](assets/help/images/settings-default-period-dialog.jpg)

*The four personal dialogs: WhatsApp number, status line, postal address, default booking period.*

![](assets/help/images/settings-theme-dialog.jpg)

 

![](assets/help/images/settings-photo-sheet.jpg)

 

![](assets/help/images/developer-screen.jpg)

*Theme, the photo sheet, and the Developer trace screen.*

**Privacy & data (#719)** — who can see your data, who did, export, erasure, the policy. See §14.

**Region & formats (#711).** How *you* read what the workspace shows: **numbers & dates** in a region of your choice (`fr_CH`, `en_GB`, `de_AT` … independent of the app language), the **clock** (24h, 12h, or whatever that region does), and whether times show in the **workspace's zone** — the one bookings are made in, and the default — or **your device's**, labelled wherever the two differ. A preview line shows the three choices added up. The currency is always the workspace's; only its spelling is yours. Stored on your profile, so it follows you across devices.

- **Profiles** (§1) and your **photo** (tap to change — pick or remove).
- **Members** — a shortcut into the directory; **WhatsApp** — your number, visible to fellow members only if you set it; **Status** — a free line (40 characters) shown in the directory; **Address** — your postal address (printed on your invoices), country and optional VAT number.
- **Help** — the built-in guide, in your language; **My badge** (§8); **Linked accounts** — attach a Google sign-in to your email account; **Documents** — the workspace's document library (§11d).
- **Preferences** — **Language** (system default or one of five), **Theme** (system / light / dark), **Default booking period** (the window the booking sheets open on, so your usual half-day or from–to is already filled in), **Scan with the front camera** (for wall tablets), and **Show help hints again** — which brings back every contextual tip you dismissed. Those tips are small carousels on the forms themselves: swipe forward and back through several *astuces* per screen, each with a *Learn more* link that jumps straight to the matching section of this guide. Your WhatsApp number lives up in this screen too (§6).
- **Advanced** — the push-notification status of this device, the workspace-wide **Developer mode** switch and the **Developer** trace screen (§8 payments).
- **About** — the app version, the author (Florian DITTGEN), the open-source licence (0BSD) with the source on GitHub, the privacy policy, a bug-report/feature link, and how to **support the project** (PayPal, Revolut).
- **Sign out**.

### 11k. Your own texts, per language (#880)

Some wording is yours, not the design's: a greeting, a seasonal note, a legal paragraph, the name of the bank. The **Texts** panel at the foot of the report designer holds them as `key → value`. **Add a text** asks for a key (letters, digits, underscores — `greeting`), then you write the value; any band or positioned layout prints it with the placeholder `text.greeting` between double braces, offered by the field picker under **Your texts**. Change the value and every document changes — the design is untouched. With a language chip selected the panel edits that language's values; an empty one falls back to the default language's, exactly as documents do. A key nobody filled in prints nothing (and a condition on it stays false). An exported layout file carries the texts of its language in a `<texts>` element; importing brings them back.

### Your own server — point the app at your community's Supabase

By default the app talks to its own server, and nothing here needs your attention. But DesKilo's backend is part of the source code — the schema, the row-level-security policies and the edge functions — so a community can run **its own Supabase project** and keep every byte on it. **Settings → Advanced → Server** switches this device over, with no rebuild:

1. **Create a project** at supabase.com — the free tier is enough to start.
2. **Install the schema**: run the SQL files in `supabase/migrations` from the source repository, in order.
3. **Copy the credentials**: in the Supabase dashboard, *Project Settings → API keys* holds the **Project URL** and the **publishable key** (the publishable key is meant to ship in a client; the server's row-level security is what protects the data).
4. **Enter them** in Settings → Server — paste each field, press **Test the connection**, then **Save**.

The test says which part is wrong rather than just failing: *could not reach that address*, *the key was refused*, or *the tables are missing* — that last one means the project answered but step 2 has not been done yet.

**Members don't type any of this.** Once the owner's device is on the community's server, the **QR button** on that screen shows a code; every member scans it in their own Settings → Server and lands on the same instance.

Switching signs you out and takes effect when the app is next opened — the session belonged to the other server. **Use the app's server** returns to the default at any time.

## 13. Notifications

Check-in reminders, pending confirmations, expense decisions — and when an admin **removes one of your reservations** (overrule), you and the admins are notified. Delivery is local-first; server pushes arrive out of the box on Android, iPhone/iPad, the browser and macOS (Firebase Cloud Messaging) — *Settings → Advanced* shows whether push is active on this device. The app-icon badge shows your pending-confirmations count **plus your unread messages** — on Android, iPhone/iPad, the macOS Dock, the Windows taskbar, and installed web apps. Member messages are announced **once per device with the sender and the full text** — including anything sent while the app was closed, announced the moment you next open it. That announcement is always raised **locally, by the app itself**: the pushed payload never carries a name, a time or a word of the message (§6), so what travels over the network says only that something arrived. A conversation you **muted** (§16) stays silent: nothing is announced for it, though it still counts on its row and on the badge.

## 14. Privacy

**Consent (#751).** The first time an account opens the app — and again whenever this text changes — a consent screen shows the whole of it: what is processed, what is never done, who can see what, who is responsible, how long, your rights, and where to read it again. Nothing else is reachable until you tick *I have read this and I accept* — the acceptance (version and date) is recorded on your account and follows you across devices. Read it again anytime in **Settings → Privacy & data → Your data, your rights**, here in the help, or on the project wiki.

Minimal data: name, email, plan, bookings, ledger. You control your photo, your status and whether your phone number is visible in the directory; on the plan a seat of yours shows an initial, or your photo where the owner enabled member photos. Kiosk badges are stored only as hashes — a lost badge is revoked, not guessed. No tracking, no third-party analytics. Financial history is anonymized, not deleted, on account erasure (bookkeeping retention).

**GDPR (#719).** DesKilo is built for the EU General Data Protection Regulation: EU-hosted data, no tracking or analytics, access limited by role and enforced on the server, and four rights you exercise yourself in **the shield button in the top bar (Privacy & data)**: **who can see my data** (the rule per category and the people it currently names), **who accessed my data** (a server-written log of every read of your finances or messages by someone else — never skippable), **export my data** (one JSON file, art. 20) and **leave with erasure** (art. 17: your bookings are cancelled, your messages blanked, your profile cleared; accounting records are kept under the legal retention named in the policy, referenced by an id, not a name). Messages are readable only by the people in the conversation, whatever their role; invoices and payments only by you and those with the finance permission.

## 15. Platforms

Android (Google Play), iPhone/iPad, desktop — **macOS** (a DMG: drag DesKilo into Applications) and **Windows** (an MSI installer) built from every release — and the **browser**: the same app, nothing to install, at the address your workspace publishes. Your data follows your account, so a desk booked on a phone shows up in a browser tab a second later.

The browser does more than you might expect: **Web NFC works** in Chromium browsers on Android over HTTPS, which is one way a chair tag gets configured from a phone browser — the installed **Android and iPhone apps read tags directly**, so that is usually the easier route. What it cannot do is scan a QR code with the camera the way the kiosk does. Everything else — plan, bookings, members, money, invoices, PDF downloads — is the same app. On first launch of the macOS DMG, right-click the app and choose *Open*: the build is not yet notarised by Apple, so a plain double-click gets a Gatekeeper warning.

## 16. Messages
The **Messages** tab is your workspace's messaging centre: every conversation in one list, the most recent at the top, people and groups together. A row shows the last message, when it arrived, and how many you have not read. Tap the **pencil** to start something new.

**People or a group, one sheet.** Pick a single person for a private chat; pick two or more and a **name field appears** — that is a group. The name is **unique in your workspace**, so nobody has to guess which *Team* they are writing to; if it is taken the app says so and you change one word.

**Telling them apart at a glance.** A person shows their photo in a circle. A group shows a **square badge** with a group symbol, and — until someone writes in it — how many members it has.

**Inside a conversation.** Messages read oldest to newest as chat bubbles, with emojis and **reference links** live: a reservation link opens that reservation, a space link opens its booking sheet, each with a *Show on plan* jump. The composer sits below. **Long-press a bubble to delete** it, confirmed first. Your own messages carry a check next to the time: **grey = delivered**, **blue = read**.

**Keeping the list in order.** Chips above the list narrow it to **All**, **Unread** or **Archived**. **Long-press a row** to **pin** it to the top, **mute** it, **mark it unread** to come back to it later, or **archive** it — an archived conversation leaves the list, keeps its history and comes back by itself when someone writes in it. A pin and a crossed bell on the row say which is which.

**A conversation is a page.** It opens full height with a back arrow, and its address can be shared or bookmarked. Messages sit under **day separators**, so a bubble shows the time alone; **Load earlier messages** at the top fetches older history. What you type but do not send stays as a **draft** for that conversation. **Swipe right** to quote a message and tap the quoted block in a reply to jump to the original; **swipe left** to take back a message of yours that nobody has read yet. The **paperclip** attaches a reservation or a space, and a counter appears as you near the length limit.

**Starting one.** Tap the pencil, then tap a person — the chat opens at once. Flip the **Group** switch to pick several people and give the group its name.

**Tap the name at the top.** In a private chat it opens the other person's **profile** — today's booking, whether they are checked in right now, their status, and how to reach them. In a group it opens the **member list**, where a group admin can add or remove people, and anyone can leave. Leaving never strands a group without an admin.

**Search** (the magnifier) looks in three places at once: **people**, **groups**, and the **words inside messages**. A result takes you straight to the person, the group, or the message.

**No photos or files.** Messages carry text, plus links to a reservation or a space. That is deliberate: a coworking app is not a file host.

**Notifications.** A message you *receive* alerts you and counts on the **Messages** tab; opening the conversation clears it. Messages no longer appear in the bell — that is for confirmations and workspace events. The one exception is an **all-admins broadcast**, which has no conversation to live in and stays there.

![](assets/help/images/messages-discussions.jpg)

*The conversation list: people and groups together, unread counts, the pencil to start something new.*

![](assets/help/images/messages-conversation.jpg)

*A private chat: bubbles oldest to newest, the grey/blue read receipts on your own messages.*

![](assets/help/images/messages-conversation-links.jpg)

*A group message carrying a reservation link and a space link — both live, both with a Show-on-plan jump.*
