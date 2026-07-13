# User Guide

Everything a member, admin, or owner needs to use DesKilo. *Version française : [Guide utilisateur](Guide-utilisateur).*

## 1. Getting started

### Create an account

Open the app and sign up with your email, a password (8+ characters), and a display name. You can show or hide the password while typing with the eye button.

### Create a workspace — or join one

After signing in you land on the welcome screen with two paths:

- **Create a workspace** — you become its **owner**. Pick a name, country (drives the default currency), and time zone. You'll then draw your floor plan in the editor (§7).
- **Join a workspace** — type the **workspace ID** someone shared with you, or tap **Scan QR code** and point the camera at the invite QR pinned to your space's wall. You join with the role the invite carries (§2).

One account can belong to several workspaces; switch between them in **Settings → Profiles**. Everything in the app is scoped to the active workspace.

## 2. Roles & invitations

DesKilo has three additive roles:

| Role | Can |
|---|---|
| **Member** | Check in/out, reserve, submit expenses, see and manage their own events and ledger |
| **Admin** | Everything a member can, plus: act *for anybody* (reservations, payments, expenses — subject to confirmation, §6), approve expenses, configure booking rules |
| **Owner** | Everything an admin can, plus: edit the physical workspace, define plans and prices, manage roles and workspace settings |

**Every invitation is bound to a role.** On the owner's *Workspace ID & QR* screen there are two invites, each with its own QR code and code:

- **Member invite** — the workspace ID itself. Print it, pin it to the wall, share it freely: whoever scans or types it joins as a plain member.
- **Admin invite** — a separate secret code, visible to owners only. Share it only with people who should manage the workspace: whoever uses it joins as an admin.

**There is no owner invite — by design.** Ownership can only be granted by an existing owner, in *Members & plans*. A workspace always keeps at least one owner: the app refuses to demote or remove the last one.

The QR encodes a link that names the role it grants (`deskilo://join?role=…`). Tampering with the link changes nothing — the server derives the role from the secret code itself.

## 3. The floor plan (Plan tab)

The plan shows the active level of your space: offices, desks, and seats, color-coded — **free**, **reserved**, **occupied**, **mine**, **blocked**. Occupied seats show who's there (each member controls their own visibility in Settings).

- **Walk-up check-in**: tap a free seat → the sheet suggests *now* until the workspace default end → confirm. If someone reserved that seat later, your end time is capped and you're told.
- **Check-in on a reservation**: your reservation opens a check-in window (default 15 min before start). Check in from the plan or the reminder notification. If you don't show up, the seat is **auto-released** after the configured delay and you're notified.
- **Check-out**: manual, or automatic at the reservation end / closing time.
- **Time scroller**: drag the timeline under the plan to see occupancy at any future moment; the *Now* button returns to live.
- Seats can carry **accessories** (monitor, standing desk…), some with a per-half-day supplement that shows up on your statement.

## 4. Reservations

Open the **Reserve** hub (center button) or tap a seat on the plan at a future time.

- Reservations follow the workspace **granularity rule**: half-days, full days, or free start/end times — the owner picks one.
- The **week view** shows a seat × day grid for the whole week — find a free seat at a glance.
- The **calendar** tab lists your own reservations by month/week/day.
- Reservations respect the workspace's **open weekdays** and **closure days**, and the booking rules (advance horizon, max duration, cancellation deadline — set by the owner in *Availability*).
- Cancelling after the deadline still counts as usage — the app tells you before you confirm.

## 5. Members directory (Members tab)

See who's part of your community:

- Each member card shows their **custom status** ("in Berlin till Friday…"), and a **reservation chip**: checked-in seat, reserved now, or their next upcoming reservation.
- **Swipe** a member (or open their detail sheet) to message them on **WhatsApp**.
- The **group button** opens your community's WhatsApp group (set by the owner in workspace settings).
- Set your own status and phone visibility in **Settings**.

## 6. Events & confirmations (bell icon)

The events feed is the audit trail of your workspace: reservations created/changed/cancelled, payments recorded, expenses submitted/approved, adjustments. Members see their own events; admins and owners see everyone's.

**The confirmation protocol:** whenever an admin does something *for somebody else* — books a seat for you, records your payment, cancels your reservation — it stays **pending until you confirm**. Pending items are pinned on top with accept/reject buttons and you get a notification. Actions you take on yourself never need confirmation.

## 7. For owners: the editor & settings

- **Editor** (app bar): draw your space on a grid — add levels, outline offices, place desks, stamp seats (a seat is a 6×4 slot with an orientation), assign chair types and amenities, block seats for maintenance. Deleting anything with future reservations makes you resolve them first.
- **Workspace ID & QR**: your role-bound invites (§2). You can replace the generated workspace ID with a memorable one (4–20 letters/digits).
- **Availability**: open weekdays, closure days, booking granularity, and the rules engine.
- **Features**: switch whole modules (events tab, services, …) on or off per workspace.
- **Members & plans**: assign subscription percentages, pause/exit members, grant or revoke admin and owner roles.
- **Billing**: plans on the quota + overage model, fee bands, overage rates.
- **Import/export**: the whole floor-plan configuration travels as an XML file — back it up, template it, or migrate a self-hosted instance.

## 8. Money (Money tab)

Your ledger answers *what do I owe, what am I owed*:

- **Charges**: monthly subscription (a percentage plan), overage half-days, service consumption, accessory supplements.
- **Credits**: approved expenses, recorded payments, adjustments.
- **Statements**: monthly, with **paid / partially paid / unpaid** status, exportable as a **PDF bill**.
- **Recording a payment**: DesKilo tracks payments, it does not process them. Pay by transfer/cash as your community prefers, then record it ("I paid") — the admin confirms; or the admin records it ("received") — you confirm. Unpaid statements show the workspace's **payment instructions**, and can open the owner's **PayPal.me** link directly.
- **Expenses**: bought coffee for the space? Submit the expense with amount and description. Another admin approves it (no self-approval), and the amount is credited against your next statement.
- **Services**: owner-defined extras (lockers, printing…) whose consumption lands on your statement.

## 9. Notifications

Check-in reminders, no-show releases, pending confirmations, expense decisions. Delivery is local-first; on Android the F-Droid flavor uses **UnifiedPush** (e.g. ntfy) instead of Google services — no Firebase anywhere.

## 10. Privacy

Minimal data: name, email, plan, bookings, ledger. You control whether your name shows on the floor plan and whether your phone number is visible in the directory. No tracking, no third-party analytics. Financial history is anonymized, not deleted, on account erasure (bookkeeping retention).

## 11. Platforms

Android (Google Play and F-Droid), iPhone/iPad, and desktop — macOS and Windows — from the same app. Your data follows your account.
