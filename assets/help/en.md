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

### Profiles — one account, several spaces

One account can belong to several workspaces. **Settings → Profiles** lists them all: each row shows the space's name, **your role there** (Member, Admin, Owner) and its workspace ID. The **check mark** marks the profile you are currently in; the **star** marks your **default** — the profile the app opens with, on every device and even after a reinstall (the choice is stored with your account). Tap a row to switch, **+ Add a profile** to join yet another space. Everything in the app is scoped to the active workspace.

### Finding your way around

The app has up to five destinations along the bottom: **Messages** (§16), **Calendar** (§5), the big central **Reserve** button (§4), **Members** (§6) and **Money** (§9). Messages and Reserve are always there; Calendar, Members and Money come and go with their feature (§8). **Messages is the inbox**: your conversations and the events & confirmations feed (§7) are its two faces, and the **bell** in the app bar jumps straight to the second with a count of what awaits you. The **gear** that opens **Settings** (§12) is in every header. On phones held sideways and on tablets, most screens switch to a **split layout** — controls in a side panel, content filling the rest.

**Everything stays live.** Whatever anyone changes — a booking, a new member, a setting — is pushed to every connected device within seconds, including the one that made the change. No restart, no pull-to-refresh.

## 2. Roles & invitations

DesKilo has three additive roles and a co-ownership flavour on top of them, plus a device account:

| Role | Can |
|---|---|
| **Member** | Check in/out, reserve, submit expenses, see and manage their own events and ledger |
| **Admin** | Everything a member can, plus: act *for anybody* (reservations, payments, expenses — subject to confirmation, §7), approve expenses, issue kiosk badges |
| **Owner** | Everything an admin can, plus: edit the physical workspace, define plans and prices, manage roles, kiosk devices, and workspace settings |
| **Co-owner** | *Active*: the owner's permissions right now, plus automatic succession. *Passive*: a successor-in-waiting with no extra permissions today |
| **Kiosk** | A wall-mounted tablet account (§10) — shows the plan only; real members act through it with a badge |

Part of this is not carved in stone: the owner retunes **nine administration permissions** in the **Role management** matrix (§8) — manage roles, manage members, validation policies, workspace settings, issue invoices, view finances, documents, services, approve expenses. What the matrix does *not* govern is the everyday stuff — checking in, reserving, acting for another member, editing the space — which stays where the table above puts it, gated by the features and the per-member switches instead.

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
- **Time scroller**: pick a from→to window (or Morning / Afternoon / Full day, depending on the workspace granularity) to see occupancy at any future moment.
- Seats can carry **accessories** (monitor, standing desk…), some with a per-half-day supplement that shows up on your statement.
- Bookings count against your **monthly days** (§9) — the app blocks or bills you past your plan, depending on what the owner configured for you. One exception: a booking lying **wholly outside the working hours** may be free or exempt, depending on the workspace's outside-hours policy (§4b).

## 4. Reservations (Reserve hub)

Open the **Reserve** hub (center button). Along the top: two rows of controls. The first says **what** you are looking at: the four **view buttons** and, on the plan, the **map / list** switch. The second says **when**: the **date chip**, a **Now** button once you have browsed away from today, and the same granularity-dependent window controls the plan itself uses (§3 — day-part chips, a *Full day* chip, or from → to). The **floor chips** (*All floors*, or one per level) sit on the plan itself, and the **QR scan** button (§4a) sits in the app bar, beside the editor and the bell. Then four views:

- **Plan** — the floor plan filtered to your chosen window; tap a free seat to book it.
- **Day** — every seat as a timeline row for the selected day (08:00 → 17:00 or your workspace's hours, the red line marking *now*); tap a free stretch to book, tap your own block to see its details.
- **Week** — a seat × day grid for the whole ISO week, a day strip (*Mon 3 … Sun 9*) on top; each cell holds the day's half-day slots with the occupant's initial. Find a free half-day at a glance and tap it to book.
- **Month** — an availability calendar: every day shows its **free-desk count** (e.g. *10/12*); tap a day to drop into its Day view.

**One place at a time — by default**: the workspace sets how many overlapping reservations one member may hold, and that number is **1** unless the owner raises it (§8). At 1, booking or checking in somewhere else while one is running is refused; checking in closes any earlier check-in whose booking already ended either way. Admins and owners can **overrule**: tapping an occupied or reserved seat offers *Remove reservation (overrule)* — the reservation is removed and the member and all admins are notified through the events feed.

Reservations follow the workspace **granularity rule** (§8 Availability) — half-days, full days, real hours (exact from–to times with the half/full-day windows as shortcuts), or free start/end times on the owner's slot grid. Half and full days cover the workspace's configured **working hours** (default 8:00–17:00 with the half-day boundary at 12:00). They respect the **open weekdays** and **closure days**, and the booking rules (advance horizon, minimum and maximum duration). **A booking always ends on the day it starts** — nothing crosses midnight; a stay that continues tomorrow is tomorrow's booking, made tomorrow (§4b). Repeating needs? Book a **series** (daily, weekdays, weekly) — closed days and conflicts are skipped and reported.

**Deleting a past or checked-in booking is a request, not an action.** A booking whose start has passed — or where you already checked in — cannot be cancelled directly: the sheet offers **Request deletion** instead. An owner or admin decides the one question that matters for billing: was the check-in simply forgotten (the booking stays on the record), or was it never used (it is removed)? The request appears on the Events feed with your optional reason; future untouched bookings keep the normal one-tap cancel. This whole path rides the **Booking deletion requests** feature: with it off, a started or checked-in booking has neither a cancel button nor a request — it simply stays on the record.

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

- **Mine / Everyone** — your own bookings, or the whole community's; every member has this toggle, since the plan and the Reserve hub's week grid already show everybody's occupancy. The dots under a day tell you at a glance: **red** = you have a booking, **blue** = other members do, **both dots** = both. Today is ringed.
- The **shape toggle** beside it switches the lower half between an **agenda list** (each reservation as a card: time window, member, space) and a **day timeline** (seats × the hours of the selected day). The seats × *days* week grid lives in the Reserve hub (§4), not here.
- The **floor chips** (*All floors* / per level) filter the **timeline**.
- Tap a day in the month grid to load it below. In landscape the calendar and the detail use the split layout.

## 6. Members directory (Members tab)


**Tap a member for their profile (#704).** Their photo, role and status; what they have booked and whether they are checked in right now; and **Contact** — the opt-in WhatsApp number for everyone, the **e-mail address and plan share for admins**. Where you may see the figures — **your own always, somebody else's with the *View finances* permission** — the profile also carries **Money**: the net position (who owes whom), the open invoices with what is left on each, the payments already in, and the month being consumed right now. The same card the Money tab shows, so the two can never disagree.

See who's part of your community:

- Each member card shows their **photo** (or initial), **role chip** (Admin, Owner), **custom status** ("in Berlin till Friday…"), an **online / last-seen** indicator (*Online*, *10 min*, *2 d*) and a **reservation chip**: checked-in seat, *Reserved now*, or next upcoming reservation.
- Tap a member for their **detail sheet** — role, presence, their **upcoming reservations**, and **Messages**.
- **Messages**: a per-member **conversation thread** (up to 500 characters per message) — open it from the **Messages** tab (§16), the member's sheet or their directory profile, read the whole exchange as chat bubbles and send from the same place. Every message reaches the other side twice over: a **push** that carries no content at all (*"You have a new message"* — by privacy design), and, once the app is running, a local notification that does show your name and text. In *Settings*, once you share a WhatsApp number, you can also opt to **receive your messages on WhatsApp**: the text arrives as the messenger reads it, each reservation/space reference as a tappable web link, plus a DesKilo link that **opens the app directly on the conversation**. The owner wires the channel **in the app** (*Settings → WhatsApp channel*): a guided sheet explains the three Meta steps — create a free app on developers.facebook.com with the WhatsApp product, copy the permanent access token and the phone number ID from API setup — and stores both per workspace (write-only; WhatsApp only delivers within the recipient's 24-hour service window). The full text is always readable in the **Messages** tab, for the recipient and the sender (the push itself carries no content, by privacy design). Admins get a **Notify all admins** megaphone — in *Members & plans* (Settings → Administration), not on the Members tab, which has no app bar of its own — reaching every admin including the owner. Toggleable via the *Member notifications* feature. While composing, two chips let you **link a reservation or live check-in — yours or any other member's** — or **a space** (seat, table, room or level) — the reference shows as a tappable link on both sides: a reservation link opens that reservation, a space link opens the space’s booking sheet, perfect for discussing a future booking.
- The **message icon** on a card messages that member on **WhatsApp** (if they shared their number); the **group button** opens your community's WhatsApp group (set by the owner).
- Set your own photo, status, and phone visibility in **Settings** (§12).
- Admins and owners additionally see each member's **email** under the name — plain members don't: member-to-member contact stays the opt-in WhatsApp number.

## 7. Events & confirmations (Messages → Events)

**Where it lives.** The feed is the second face of the **Messages** tab, and the **bell** in every app bar is a shortcut straight onto it, carrying the count of what awaits you. One place holds the alerts, so reading one there is reading it everywhere.

The events feed is the audit trail of your workspace: reservations created/changed/cancelled, payments recorded, invoices paid, expenses submitted, extra-days requests, role changes, deletion requests. Members see their own events; admins and owners see everyone's. **Filter chips** (All · Reservation · Payment · Expense · …) narrow the list — your choice is remembered — and a **Group by** menu folds the feed into groups by type, day or member (tap the group symbol to return to the flat list); each row carries its status icon — an **hourglass** while pending, a **green check** once confirmed — and money events show *who validated them and when* right on the row.

**Waiting for your confirmation:** whenever an admin does something *for somebody else* — books a seat for you, records your payment, demotes an admin — it stays **pending until confirmed**. Pending items are pinned on top with a red ✕ and a green **Accept** button, and you get a notification. Actions you take on yourself never need confirmation.

**Messages moved.** Member messages now live in their own **Messages** tab (§16), not here — a message in two places is one you can mark read in one and still see unread in the other. This feed keeps the one message kind that has no conversation to live in: a **broadcast to all admins**.

**Validation quorum:** for money matters and role changes the owner defines *who* must approve and *how many* approvals are needed. **Nobody validates their own event** — only another person can (one owner-configured exception, for reservation deletions, below); where no other validator exists, the request simply waits. After 7 days without an answer, what happens depends on which way the request cuts. A request **you submitted** for yourself — a deletion, extra half-days, an invoice write-off — **expires**: nothing costly is ever granted silently. Something an admin **did for you** — created or modified a booking, recorded a payment — **auto-confirms** instead, because it already happened and the feed only asked you to acknowledge it; a booking an admin made for you is then granted and consumes your quota.

The owner tunes this per **domain** in **Settings → Validation rules** — thirteen cards, one per event type, each inheriting from the **default rule** until edited: *Default rule, Payment, Expense, Service, Extra half-days, Booking deletion, Role change, New member, Reservation, Whole-space reservations, Invoice payment, Adjustment* and *Outstanding write-off*. A rule sets the number of required validations, *which* admins may validate (all, or named ones), and whether the owner must always sign off. The **Booking deletion** rule carries two more switches — *admins delete without validation* and *owners delete without validation*, both **off by default** — the single, deliberate exception to "nobody validates their own event": that requester's own deletion request settles itself and stays marked **auto-validated** in the feed. They apply to reservation deletions and to nothing else.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*Left: one rule per domain, inheriting from the default. Right: editing a rule — required validations, allowed validators, owner sign-off.*

## 8. For owners: the editor & settings

All administration lives under **Settings → Administration** — *Workspace* (the workspace settings), *Workspace ID & QR*, *Members & plans*, *Role management*, *Availability*, *Billing*, *Payment instructions*, *Services*, *Validation rules*, *Billing & reports* (the invoicing hub with the report editor and reminder rules in its header), *Features*, and the feature-gated entries (*Accessories*, Online payments, RFID/NFC badges…). One rule to know: **a feature's settings entry only appears while that feature is enabled** — switch *Online payments* off in **Features** and its configuration screen disappears with it (and comes back when you re-enable it). The **Features** entry itself is always there, so you can always switch a module back on.

**Country, currency, time zone (#711).** The country picker now covers the 32 countries the app can declare tax in (EU-27, Switzerland, Norway, the UK, the US and Canada). Currency is a **picker** of the codes the app can format — each with its symbol, and each with the right number of decimals: a yen has none, a dinar has three, and every amount, invoice and online payment respects that. Time zone is a **searchable list** of the IANA zones the clock can actually install; a typo can no longer save.

![](assets/help/images/settings-administration.jpg)

### The space editor

Open the **editor** from the Reserve hub's app bar (crossed tools icon). The **Space editor** screen lists your floors — drag to reorder, the **layers icon** marks a level *Bookable as a whole*, the **⋮ menu** renames or deletes, **+ Add a floor** extends the building. Open a floor to draw it on the grid with the bottom toolbar — **Select · Office · Table · Seat · Image · Erase**:

- An **office** gets a name, an optional *Bookable as a whole* switch and a **price per half-day**.
- A **table** gets a name, the same whole-table option and its own **price per half-day**.
- A **seat** gets a name, a **seating direction** (↑ → ↓ ←), an optional **chair type**, its **accessories** (each may carry a per-half-day supplement) and a **Blocked (maintenance)** switch.
- **Image** places a resizable illustration; the photo icon in the app bar sets the level's **background photo**.
- Deleting a space that has history is the **owner's** call, and with *Delete spaces with history* on (the default) it just works: bookings that referenced the space keep a text snapshot of what it was, and any still-reserved booking on it is cancelled automatically. Switch the feature off and a space with future reservations has to be emptied by hand first.

### Workspace ID & QR

Your role-bound invites (§2): member invite = the workspace ID (replace it with a memorable one, copy it, share the QR as PNG), admin invite = single-use personal codes.

### Availability

- **Open weekdays** — chips Mon…Sun.
- **Booking granularity** — one of: *free time range*, *5 / 15 / 30 / 60-minute slots*, *half-days (morning & afternoon)*, *full days only*, or *real hours* (exact from–to, with half/full-day shortcuts).
- **Working hours** — day start, half-day boundary, day end (default 08:00 / 12:00 / 17:00). Half-day and full-day slots everywhere — reservations, check-in and billing — follow these hours; under *real hours* you also set how many hours bill as a half and a full day.
- **Closure days** — dated exceptions, added with **+**.
- **Booking policies** — four entries that relax or tighten the rules of §4b (the section rides the *Booking policies* feature); the two switches are both **off by default**:
  - **Allow past bookings** — members may backfill a booking that already ended (yesterday and earlier). Off, such bookings are refused; booking a window earlier the *same day* is always allowed either way. Switch it on for spaces that record attendance after the fact.
  - **Admins may check members out** — an admin can end a member's running check-in. Off, check-out is strictly personal. Useful where staff closes the room in the evening.
  - **Outside the opening hours** — one question, four mutually exclusive answers, the same on every granularity: *what may happen outside the working day?* **Off** — nothing: no booking ahead, no walk-up, and a booking spilling past the day's end (or starting before it opens) is refused too. **Spontaneous only** — the walk-up check-in stays possible at **either edge of the day**, the early arrival before opening as much as the evening overtime to midnight, while reserving ahead outside the hours is refused; this is where the old **Minute bookings within working hours** switch went, and workspaces that had it on read as this (that switch allowed only the evening walk-up — the mode is named for spontaneity, not for the evening, so the morning walk-in is allowed too). **Free** — allowed, never counted and never charged (pure presence information). **Charged** (the **default**) — counted like ordinary usage, except on a day where the member already holds a regular inside-hours booking, when the outside part rides free.
  - **Simultaneous reservations per member** — how many overlapping bookings one member may hold, check-ins included. **1** by default: one place at a time. An owner or admin can grant a single member a higher allowance in *Members & plans* (never for themselves), and that personal permission wins over this number.

  Below them sits **Booking limits** — three numbers the server has always enforced and that the app can now set:

  - **Advance booking horizon** — how many days ahead a booking may start (default **90**); beyond it the booking is refused by name.
  - **Minimum duration** — the shortest booking accepted (default **30 minutes**), on every granularity. It is exactly why an 11:45 arrival for the 12:00 half-day boundary is refused as too short.
  - **Maximum duration** — the longest accepted (default **24 hours**). Since a booking ends on the day it starts, a full day is the ceiling and the picker offers nothing above it.

  Set a minimum above the maximum and the screen says so, because the server checks each bound on its own and would simply refuse every booking without explaining why.

  The two **auto-validation** switches — *admins delete without validation*, *owners delete without validation* — are not here: they live with the validation rules (§7), off by default, and reach reservation deletions only.

### Features

Switch whole modules on or off per workspace — each toggle carries its description right on the screen: calendar tab, events tab, notification feed grouping, money tab, services, accessory supplements, online payments, invoices, admins issue invoices, invoice PDF template, payment reminders (dunning), VAT management, VAT declarations, e-invoice delivery to the customer, PDF export, series booking, booking for others, push notifications, admins may block seats, table/desk & level reservations, admins may assign levels, kiosk mode, RFID/NFC badges, QR badges, kiosk member photos, members directory, WhatsApp integration, space QR codes, chair NFC tags, member photos on the plan, co-owners, auto check-in/out, data export (Excel), working hours, booking policies, member notifications, document library, member reports, booking deletion requests, role management, plan-object deletion, contextual help hints, and interface animations. Switching a module off removes *all* of its screens and buttons for every member.

The list is **hierarchical**: a feature that needs another sits indented under it with a *Requires…* note, and is greyed out while its parent is off — *Money* carries services, accessory supplements, online payments and invoicing; *Invoices* carries the admin delegation, the PDF template, the payment reminders, VAT management (with the declarations beneath it again) and the customer e-invoice delivery; *Kiosk mode* carries three children — RFID/NFC badges, QR badges and kiosk member photos; *Table/desk & level reservations* carries *admins may assign levels*; *Members directory* carries the WhatsApp integration; *Events tab* carries the feed grouping. Switching a parent off takes its whole subtree out of the app; the child's stored choice comes back untouched when the parent returns.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

### Members & plans

Tap a member to open their **management sheet** — every per-member action in one place: **Send the financial agreement** (§11d), **Messages**, **Add a service** (service, quantity, billing month → *submit for confirmation*), **Subscription** (their percentage), **When the days run out** (the over-consumption policy, §9), **Reservation limit** (how many **open** reservations the member may hold in total, whenever they fall), **Simultaneous reservations** (how many bookings may **overlap in time** — the personal allowance that overrides the workspace number, §4b; two different caps, so read the labels), **May reserve a whole desk, office or level**, **Badges** (§10), **Name admin** (validated, §7), **Co-ownership**, **Turn into a kiosk** — or **Revert the kiosk to a member** on a device account — **Approve** or **Reject** a pending membership, and **Pause the membership**. Each row shows the member's **email** under the name.

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
- **Desk transparency** — the slider that lets a background photo show through drawn desks.
- **Invoice PDF template** and **Reminder rules** — shortcuts to the report editor and the dunning configuration (§11).
- **Exports** — *Export the space (XML)* (settings + floor plan, no personal data — back it up, template it, migrate an instance), *Export the configuration (PDF)* (a full snapshot: settings, members, plan), *Workspace report* (everything about the space through the report engine's « workspace » template), *Space QR codes (PDF)* (one credit-card QR per seat, desk, office and level, ten per A4), *Export the data (Excel)* (one workbook: reservations, payments, invoices, members, plan — one tab each), *Import the space (XML)* (restores settings and floor plan; replaces the current plan). Every export lands in your device's **Downloads** folder.
- **The setup questionnaire** — <https://fdittgen-png.github.io/deskilo/setup.html>: a standalone page (Mac, PC or phone; answers save automatically in the browser) that walks a new owner through **every subject with predefined choices** — identity (country incl. Norway, currency, timezone, workspace language, desk transparency and the per-language invitation templates), availability — granularity, working hours, closure days and **all four booking policies** (past bookings, admin check-out, the outside-hours mode and the simultaneous-reservations number), plus the hour-to-half-day conversion under *real hours* —, the floor plan, **all 43 feature toggles** at their real defaults, billing tiers and subscription levels, day packs, services and accessories, payment instructions, **legal identity and VAT** (organization type, regime, the country's usual rates — Switzerland's 3.8 % accommodation rate, Norway, the Canadian provinces, with the honest US sales-tax note —, invoice mentions, reminder rules, the declaration period, and the e-invoicing endpoints including the customer's own delivery service), the role → permission matrix, the default validation rule **with a card per domain and the two auto-validation switches**, and the members to invite with their per-member settings (over-consumption policy, whole-space right, simultaneous allowance, reservation limit). **Export the XML** and the app imports settings, accessories and floor plan directly (*Import the space (XML)*); the file's `<setup>` section carries everything else to finish the configuration. The page can also **reload** a previously exported file to continue editing — including one written before a setting existed, which simply comes back with that setting at its default. One caution the page repeats: the exported file is plain text, so fill in a platform token only if you are answering privately; otherwise leave those blank and type them in the app, where they go straight to the server and never come back.
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

1. Open **Settings → RFID / NFC badges** (owner only). Switch **Enable NFC badge check-in** on, and read the **device status** line — it distinguishes *ready*, *NFC turned off in Android settings*, and *no NFC hardware*. Android phones and tablets with NFC, and **iPhones**, can read a tag; iPads have no NFC hardware at all.
2. Give each member a card: **Members & plans → the member → Badges → Register a card**, then hold their card to the device. Any card with a readable chip works (MIFARE, NTAG…). Members can also do it **themselves**: **Settings → My badge** mints their printable QR badge and registers their own card — no admin needed.
3. Use them at a **kiosk** (§10): the member taps the card to reserve or check in. Revoke a lost card from the same Badges dialog; **swipe a revoked badge to the right to delete it** for good (after a confirmation).

Badges belong to **one workspace** — the dialog names which one you're registering into, so register the card under the workspace whose kiosk will read it. The same physical card can serve you in several workspaces. A badge QR saved **as PDF** prints ten credit-card copies on one A4 page — spares included.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

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

### 9a. Once the month is invoiced, the invoice decides

- Your bill shows an **invoice card** — number, state, total, what's paid, what remains — and the month reads **settled** as soon as the invoice is paid, its remainder cancelled, or its credit note refunded, even when the settling payment was recorded in a later month. A **partially paid** invoice keeps the month outstanding at exactly the **remaining** amount (that's also what *Pay online* charges). A **credit note** month shows what the workspace owes you back — nothing to pay on your side.
- **Your account** — when you hold spare credit (an avoir, or payments left over from a past month), the Finances tab shows your real cross-month position above the bill: **credit on account**, every **open invoice** with its remaining amount, refunds the workspace owes, and the resulting **net position**. Your credit can settle open invoices — the workspace applies it when matching payments (imputation). Months before your membership began owe nothing and never read outstanding.

### 9b. Quick view, save, share — every report

Every report in the app — the bill, invoices, proformas, credit notes, your self-service documents — offers the same three actions: **Quick view** (see the rendered document on screen before any PDF exists), **Download PDF** (save locally) and **Share PDF** (hand it to any app — WhatsApp, mail, …).

**Reports speak the reader's language:** a document prints in the **member's** language when a template exists for it, otherwise in the **workspace language**, and failing both in the **language of the workspace's country** (§11 templates per language). Where that country has no single language, the app does not guess — it refuses and asks you to *set the workspace language first*.

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

An invoice in DesKilo is generated, never composed: its positions are **derived exclusively from the month's tracked data** — subscription, overage, supplements, services, packages — minus the month's payments and credits, so the bottom line **is the balance due**. Each document snapshots the workspace's and the member's postal addresses (set yours in **Settings → Address**; the workspace address is in the workspace settings) and is **digitally signed** at issue — it never changes afterwards. A **detailed annex** (the month's ledger and attendance) can be attached with one switch when issuing.

Issuers open **Finances → Invoices** and land on a three-tab hub under a live summary strip (*N to invoice · N open · X outstanding · N to refund · Y*):

- **To invoice** — every member whose previous month has billable data and no invoice yet, with what the month adds up to: issue per member (with a preview of the derived positions) or **Invoice all** in one sweep — which asks for confirmation first, naming the count, the month and the total. The **New invoice** button opens the same sheet for any member and month — member picker, ‹ month ›, the derived positions, the balance, the **detailed annex** switch and **Issue the invoice** (a green *Invoice issued.* snack confirms). **One active invoice per member and month** — a month only becomes invoiceable again after its invoice was cancelled. The issue sheet opens on the **completed month** (the moment its numbers stop moving); pick the running month instead and it warns you, because that month can only be invoiced once.
- **Open** — issued invoices awaiting settlement, oldest first; anything waiting longer than 30 days turns red, in the card and in the summary strip. Every action is an icon with a tooltip (cancel · proforma · reminder · mark as paid). **Tap a card to read the invoice.** **Send a reminder** records the reminder and shares the PDF with a message — the card shows *Reminded ×N*. **Mark as erroneous** cancels the invoice for correction (an explicit dialog warns the action is irreversible): it moves to the archive struck through, and a **replacement** re-derives the same month from the corrected data, referencing the original. **Mark as paid** matches a real payment (below). **A partial payment does not close an invoice**: it stays on Open, badged *Partially paid* with the remaining amount, until the outstanding remainder is explicitly **cancelled through the validation framework** — an admin/owner requests the write-off (with a reason), the validators confirm, and only then does the invoice move to the archive as *Partially paid · remainder cancelled*. **A NEGATIVE invoice is a credit note (avoir)** — the month's credits exceeded its charges, so the WORKSPACE owes the member: its PDF is titled *Credit note*, it gets no reminders and no member-payment matching; instead the card shows *To refund* with **Record the refund** — the payout books against the member's balance (validated like any settlement when a policy applies; a reject reopens it) and the document closes as *Refunded*. The summary strip separates the two directions of the payment process: *N open · X outstanding* counts positive invoices at their **remaining** value (a €500 invoice with €280 paid counts €220), while *N to refund · Y* totals the open credit notes the workspace still owes.
- **Archive** — closed invoices, filterable by member and month and sortable; cancelled invoices are **hidden by default** — the *Show cancelled* chip brings the correction trail back; the bar under the filters says how many invoices match and **Clear filters** brings the whole archive back. Each row carries its status chip (*Paid*, *Partially paid*, *Erroneous* struck through, credit notes with their negative amount), its month and its amount, with **Download PDF** right there. **Tap a row to open the invoice** — positions, balance, who it was billed to, where it stands (*Paid €300.00 on Aug 6*, *Reminded ×1 · last reminder…*, *Annex: 5 entries, 10 check-ins*), which invoice it replaces or was replaced by, its signature — and every action it still allows, spelled out: **Quick view**, **Download PDF**, **Share PDF**, export the **e-invoice (XML)**, remind, mark as paid, mark erroneous, issue a replacement.

**Marking as paid means matching a real payment — or applying a credit.** The dialog lists the member's registered payments — recorded transfers and confirmed online payments — and you map the invoice to one of them; there is no amount to type (no registered payment yet? the dialog says so: *record it or confirm it first*). It also lists the member's **account credits** (credit-note excess): matching one imputes the avoir on the invoice, past months included — the standard alternative to a cash refund, for associations and companies alike. Each credit spends exactly once: one already deducted inside an issued invoice can never settle a second document. Paid **more**? Create a **credit note** for the excess (a credit on the member's ledger) or force-accept with a mandatory note. Paid **less**? Accept it with a mandatory note. Everyone with invoicing access is notified of paid invoices, and the owner can put an **Invoice payment** validation rule (§7) on them: the match then waits for the quorum — a reject reopens the invoice.

**A paid invoice is definitive.** Once matched it can never be cancelled, replaced or altered — corrections happen before payment, by cancelling the open invoice and issuing its replacement. A payment that did **not** cover the whole amount, accepted with a note, shows as **partially paid** rather than paid.

**Proforma.** Two of the hub's three tabs carry a proforma action: on **To invoice** it renders the month's derived positions as a quote — no number, no signature, stamped PROFORMA, and **nothing is issued**; on **Open** it re-renders the issued invoice as a payment request that cannot pass for the original. Both offer the quick-view / download / share triad.

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

Template variables (invoice family): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (each with `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — and the legal set: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

### 11d. The report suite & the document library

- **Financial agreement** — every standing price that applies to a member: subscription, extra half-day, services, packages, accessory supplements and the whole-space prices, **desks and tables included**. Owners/admins send it from a member's action sheet; every member can quick-view/download/share their own from *Finances → Documents*.
- **Payments report** — everything you paid, declared or had validated in a month: your little balance sheet, self-service on the same row.
- **Workspace report** — identity, floor-plan counts, availability, features and prices: *Workspace settings → Workspace report*.
- **Document library** — *Settings → Documents*: the workspace's statutes, user guides, financial statements and meeting minutes, LINKED from whatever system you already use — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud or any https link (the drive keeps managing its own access; the app never stores foreign credentials). Every entry has a **visibility role**: every member, admins and owners, or owners only — enforced server-side, so a member never even downloads a list containing board documents. Admins and owners curate with the + button; a *Document library* feature toggle gates the whole thing.

## 12. Settings & profile

Your personal screen, top to bottom:

**Privacy & data (#719)** — who can see your data, who did, export, erasure, the policy. See §14.

**Region & formats (#711).** How *you* read what the workspace shows: **numbers & dates** in a region of your choice (`fr_CH`, `en_GB`, `de_AT` … independent of the app language), the **clock** (24h, 12h, or whatever that region does), and whether times show in the **workspace's zone** — the one bookings are made in, and the default — or **your device's**, labelled wherever the two differ. A preview line shows the three choices added up. The currency is always the workspace's; only its spelling is yours. Stored on your profile, so it follows you across devices.

- **Profiles** (§1) and your **photo** (tap to change — pick or remove).
- **Members** — a shortcut into the directory; **WhatsApp** — your number, visible to fellow members only if you set it; **Status** — a free line (40 characters) shown in the directory; **Address** — your postal address (printed on your invoices), country and optional VAT number.
- **Help** — the built-in guide, in your language; **My badge** (§8); **Linked accounts** — attach a Google sign-in to your email account; **Documents** — the workspace's document library (§11d).
- **Preferences** — **Language** (system default or one of five), **Theme** (system / light / dark), **Default booking period** (the window the booking sheets open on, so your usual half-day or from–to is already filled in), **Scan with the front camera** (for wall tablets), and **Show help hints again** — which brings back every contextual tip you dismissed. Those tips are small carousels on the forms themselves: swipe forward and back through several *astuces* per screen, each with a *Learn more* link that jumps straight to the matching section of this guide. Your WhatsApp number and the *receive messages on WhatsApp* switch live up in this screen too (§6).
- **Advanced** — the push-notification status of this device, the workspace-wide **Developer mode** switch and the **Developer** trace screen (§8 payments).
- **About** — the app version, the author (Florian DITTGEN), the open-source licence (0BSD) with the source on GitHub, the privacy policy, a bug-report/feature link, and how to **support the project** (PayPal, Revolut).
- **Sign out**.

## 13. Notifications

Check-in reminders, pending confirmations, expense decisions — and when an admin **removes one of your reservations** (overrule), you and the admins are notified. Delivery is local-first; server pushes arrive out of the box on Android, iPhone/iPad, the browser and macOS (Firebase Cloud Messaging) — *Settings → Advanced* shows whether push is active on this device. The app-icon badge shows your pending-confirmations count **plus your unread messages** — on Android, iPhone/iPad, the macOS Dock, the Windows taskbar, and installed web apps. Member messages are announced **once per device with the sender and the full text** — including anything sent while the app was closed, announced the moment you next open it. That announcement is always raised **locally, by the app itself**: the pushed payload never carries a name, a time or a word of the message (§6), so what travels over the network says only that something arrived.

## 14. Privacy

Minimal data: name, email, plan, bookings, ledger. You control your photo, your status and whether your phone number is visible in the directory; on the plan a seat of yours shows an initial, or your photo where the owner enabled member photos. Kiosk badges are stored only as hashes — a lost badge is revoked, not guessed. No tracking, no third-party analytics. Financial history is anonymized, not deleted, on account erasure (bookkeeping retention).

**GDPR (#719).** DesKilo is built for the EU General Data Protection Regulation: EU-hosted data, no tracking or analytics, access limited by role and enforced on the server, and four rights you exercise yourself in **Settings → Privacy & data**: **who can see my data** (the rule per category and the people it currently names), **who accessed my data** (a server-written log of every read of your finances or messages by someone else — never skippable), **export my data** (one JSON file, art. 20) and **leave with erasure** (art. 17: your bookings are cancelled, your messages blanked, your profile cleared; accounting records are kept under the legal retention named in the policy, referenced by an id, not a name). Messages are readable only by the people in the conversation, whatever their role; invoices and payments only by you and those with the finance permission.

## 15. Platforms

Android (Google Play), iPhone/iPad, desktop — **macOS** (a DMG: drag DesKilo into Applications) and **Windows** (an MSI installer) built from every release — and the **browser**: the same app, nothing to install, at the address your workspace publishes. Your data follows your account, so a desk booked on a phone shows up in a browser tab a second later.

The browser does more than you might expect: **Web NFC works** in Chromium browsers on Android over HTTPS, which is one way a chair tag gets configured from a phone browser — the installed **Android and iPhone apps read tags directly**, so that is usually the easier route. What it cannot do is scan a QR code with the camera the way the kiosk does. Everything else — plan, bookings, members, money, invoices, PDF downloads — is the same app. On first launch of the macOS DMG, right-click the app and choose *Open*: the build is not yet notarised by Apple, so a plain double-click gets a Gatekeeper warning.

## 16. Messages
The **Messages** tab is your workspace's messaging centre: every conversation in one list, the most recent at the top, people and groups together. A row shows the last message, when it arrived, and how many you have not read. Tap the **pencil** to start something new.

**People or a group, one sheet.** Pick a single person for a private chat; pick two or more and a **name field appears** — that is a group. The name is **unique in your workspace**, so nobody has to guess which *Team* they are writing to; if it is taken the app says so and you change one word.

**Telling them apart at a glance.** A person shows their photo in a circle. A group shows a **square badge** with a group symbol, and — until someone writes in it — how many members it has.

**Inside a conversation.** Messages read oldest to newest as chat bubbles, with emojis and **reference links** live: a reservation link opens that reservation, a space link opens its booking sheet, each with a *Show on plan* jump. The composer sits below. **Long-press a bubble to delete** it, confirmed first. Your own messages carry a check next to the time: **grey = delivered**, **blue = read**.

**Tap the name at the top.** In a private chat it opens the other person's **profile** — today's booking, whether they are checked in right now, their status, and how to reach them. In a group it opens the **member list**, where a group admin can add or remove people, and anyone can leave. Leaving never strands a group without an admin.

**Search** (the magnifier) looks in three places at once: **people**, **groups**, and the **words inside messages**. A result takes you straight to the person, the group, or the message.

**No photos or files.** Messages carry text, plus links to a reservation or a space. That is deliberate: a coworking app is not a file host.

**Notifications.** A message you *receive* alerts you and counts on the **Messages** tab; opening the conversation clears it. Messages no longer appear in the bell — that is for confirmations and workspace events. The one exception is an **all-admins broadcast**, which has no conversation to live in and stays there.
