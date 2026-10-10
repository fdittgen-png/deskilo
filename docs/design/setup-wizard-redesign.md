<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# The setup wizard, redesigned for a person who has never run a coworking space

Status: proposal. Facts come from `docs/design/owner-setup-research.md` (read it for the code citations);
the matching guide for owners is `docs/guide/setup/` (the *Setup Guide*).
Defects found on the way are filed as #2331 (the wizard promises more than the app imports) and #2332
(configuration mistakes the guards do not catch).

## 1. Who the wizard is for, and what it must achieve

A future owner. They know their community — five freelancers around one table, an association with a room,
a company with two floors — and they do not know DesKilo's words (*granularity*, *half-day boundary*,
*validation domain*, *exigibility*, *UAT*). They arrive once, they are anxious about getting money and law
wrong, and they will not read a manual first.

The wizard succeeds when, in one sitting of about **20 minutes**, they have

1. a space they can **open to members** (a place, opening times, someone to approve people, an invitation);
2. a clear, honest list of **what remains** (money, legal identity, reports) with the reason and the order;
3. no configuration that **contradicts itself**, and no decision taken blindly that is **hard to undo**.

Everything beyond that is reachable, never in the way.

## 2. What is wrong today (measured on `web/setup.html`)

| Symptom | Consequence for a newcomer |
|---|---|
| Step 2 is **126 on/off switches** (45 on by default) named after the registry (*decisionSurface*, *validationScopes*) | The first real decision is the hardest one; the tiers (Core / Platform) are never explained |
| No starting point: the app has templates (`association_fr`, `tiny`) and onboarding uses them; the page ignores them | Blank-page problem; no example values |
| Features first, then place, money, roles, members | The page asks for decisions in the order of the registry, not of the person's life |
| 12 steps, 3 of which appear and disappear | "Step 5 of 12" changes under the reader |
| Money and legal assume a tariff, a VAT status, an accountant | No "I don't know yet", no "ask your accountant this" |
| No preview: floor plan is a table; no sample invoice, no member view | The owner cannot judge the result |
| Consistency checks only know the page's own rules | The server refuses what the page accepted (invoicing outside FR/DE, registered VAT without a rate, online payments without a provider) |
| **The import does not do what the page says** (#2331): name and `<setup>` are not applied; the roles and policies the app could import are written into `<setup>`; tariffs and everything in `<configuration>` only if `configurationTransfer` is already on | The owner re-types half of it, and finds out late |
| Secrets (e-invoice tokens) are asked in a plain-text file | Safe only if the owner reads the warning |

## 3. Principles

1. **Ask about the person, derive the switches.** Questions are intentions ("Will members pay you?"), the
   wizard turns the answers into features, and shows the result (and lets an expert change it).
2. **Start from a scenario**, not from a blank form: *A few places I share*, *An association with a room*,
   *A coworking that invoices*, *Start from nothing*. Each is a template with a visible "this sets up…" list.
3. **Three levels, in this order**: **Open** (a place, times, people) → **Run** (roles, tariffs, payments,
   notifications) → **Grow** (invoicing and VAT, reports, kiosk, analytics, assistants). Only Open is required
   to start; the others are offered when the answers make them relevant.
4. **Say what can't be undone.** A lock badge on every question whose answer becomes permanent after the first
   issued invoice or the first booking (country, currency, VAT regime, invoice numbering, workspace ID,
   floor-plan import), with the reason in one sentence. Everything else says "you can change this later".
5. **"I don't know yet" is a legal answer** with a safe default and the consequence stated ("no invoices from
   DesKilo until you tell us your legal identity").
6. **Run the real rules.** The page uses the same readiness vocabulary as the app (*Region rules, Resources,
   Pricing, Invitations, Payments, Roles & validation, Local setup*), so the owner recognises it afterwards,
   and the same refusals as the server (supported invoicing countries, rates, provider, quorum).
7. **Show, don't describe**: a drawn floor plan, a week view of the opening hours, a sample invoice with the
   owner's letterhead, the booking sheet as a member sees it, the invitation message in the language chosen.
8. **Teach in place.** Each step has *Why it matters*, *An example*, *What members will see* and a link to the
   exact section of the Setup Guide. A glossary tooltip for every term of art.
9. **Nothing leaves the browser** (as today). Save and resume, a draft file to share with an accountant.
10. **Mobile first**, five languages, keyboard and screen-reader complete, no animation that blocks.

## 4. The flow

```
 0  Welcome       What you'll end with · 20 minutes · [Explore the demo] [Resume my draft]
 ── OPEN ─────────────────────────────────────────────────────────────────────────────
 1  Your project  scenario cards · organisation (association / company / individual) · how many places
 2  The place     name · country (with what the app can do there) · currency · time zone · language
 3  The space     draw it: levels, rooms, desks (live plan) · whole-room booking
 4  The times     "Office hours" / "Half days" presets · open days · closure days · rules in plain sentences
 5  The people    who runs it (just me / me + a team / a board) · how people join (open / approved) ·
                  who approves (capacity check against the names entered) · first invitations
 ── RUN ──────────────────────────────────────────────────────────────────────────────
 6  The money     [if members pay] tariff presets · payment methods · reminders
 7  Telling people  what each feature notifies, to whom, by which channel · invitation text per language
 ── GROW ─────────────────────────────────────────────────────────────────────────────
 8  Invoices & tax [if you invoice] supported-country check · legal identity · VAT regime · numbering ·
                  "what to ask your accountant" card
 9  Documents     invoice and letter look (preset + preview) · languages · accountant exports
 10 Review        readiness cards (Blocking · Recommended · Optional) · "can't be undone" list ·
                  features derived from your answers (expert: edit)
 11 Finish        download the pack · "your first week" checklist with links into the app
```

Rules of the flow:

- The **rail is stable**: three levels with their steps; a step that does not apply is shown greyed with the
  reason, never removed. "Step n of N" never changes.
- **Open** can be completed alone and produces a usable space. **Run** and **Grow** each end with *You can stop
  here*.
- Every step has *Skip, decide later*, which records the consequence in the review.
- **Expert mode** keeps today's all-on-one-page view and the 126 switches, behind a clear toggle.

## 5. Three screens, drawn

### 5.1 Step 1 — your project

```
┌──────────────────────────────────────────────────────────────┐
│  What are you building?                          ● ○ ○ ○ ○ ○ │
│                                                              │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│  │ A few      │ │ An         │ │ A coworking│ │ Start from │ │
│  │ places I   │ │ association│ │ that       │ │ nothing    │ │
│  │ share      │ │ with a room│ │ invoices   │ │            │ │
│  │ 1 floor,   │ │ members,   │ │ tariffs,   │ │ every      │ │
│  │ no money   │ │ approvals  │ │ VAT, PDFs  │ │ choice mine│ │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘ │
│  This sets up: booking · members · approvals · calendar …    │
│  Is the space run by  (•) an association  ( ) a company  ( ) me │
│                                          [ Continue ]        │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 Step 3 — the space, drawn live

```
┌───────────────────────────────┬──────────────────────────────┐
│ Floors   [ + Add a floor ]    │   Ground floor               │
│  ▸ Ground floor   2 rooms     │  ┌──────────┐  ┌──────┐      │
│ Rooms    [ + Add a room ]     │  │ ▢ ▢ ▢ ▢  │  │ ▢ ▢  │      │
│  ▸ Open space   8 desks       │  │ Open     │  │Meeting│     │
│  ▸ Meeting      1 table 6 ▢   │  └──────────┘  └──────┘      │
│ ☐ Members may book the whole  │   14 places in total         │
│   room (price later)          │   What a member sees ▸       │
└───────────────────────────────┴──────────────────────────────┘
```

### 5.3 Step 10 — the review, in the app's own words

```
 Blocking (fix to open)        ✔ Region rules   ✔ Resources   ✖ Roles & validation
                                 "Two approvals are required but only you can approve" [Fix]
 Recommended                   ◔ Invitations   ○ Payment details
 Can't be undone later  🔒     Country · Currency · VAT regime · Invoice number format
 Decided later                 Legal identity — "no invoices from DesKilo until this is set"
```

## 6. Intent → configuration (the derivation layer)

A table in the repository, `web/setup_intents.json`, maps each answer to features and values; a test proves
every derived set respects `featureManifest.requires` and equals a template's `feature_profile` for the
scenario cards.

| Answer | Derived |
|---|---|
| Members pay | `moneyTab` → `subscriptionInvoices`/`usageInvoices` only if "I invoice from DesKilo" |
| I invoice from DesKilo | `invoicing`, `invoicePdfTemplate`; **requires** a supported country (FR, DE today), legal identity, VAT regime; otherwise the card says "issue invoices outside DesKilo; DesKilo keeps statements" |
| Approvals needed | validation preset (*Open join* / *Approve joins* / *Approve joins and bookings*) → policies per domain with a `required_count` ≤ validators entered |
| A tablet at the door | `kioskMode` + `nfcBadges`/`qrBadges` only if the owner has badges; asks for the kiosk member |
| Members chat | `memberNotifications` (+ children by choice) |
| Reminders for late payers | `dunning` → `paymentReminders`; says plainly that reminders run when an administrator opens Finances |
| Several buildings | `multiSite` + a site per building |

## 7. Consistency: the rules the page must run

All are taken from the server or the app (see the research note, §3). The page must refuse or warn *before* the
owner leaves the step:

1. Child feature without its parent chain (`REQUIRES`): tick the chain and name what came on.
2. **Invoicing outside the supported countries** → no `invoicing`, explain the manual path.
3. **Registered VAT** without at least one rate in force, or without a VAT id.
4. **`onlinePayments`** without a provider connection → keep off, explain the connection.
5. **Quorum**: `required_count` greater than the validators who exist after the people step (counting owner
   self-validation rules), per domain.
6. **Floor plan** with no seat, **opening days** with none open, a **tariff** that leaves a level uncovered.
7. **Numbering**: reset cadence not more frequent than the printed date; format preview with the next number.
8. **Whole-room booking** needs `levelBooking` and a price intent.
9. **Plan import** is refused once reservations exist: say it before offering "replace the plan".
10. **Notifications**: a feature that notifies through push needs the installation's Firebase set-up; the wizard
    says whether the owner's installation has it (unknown → "ask your operator").

## 8. Notifications, made visible (step 7)

A generated table, from the owner's own answers: **feature → event → who is told → channel → what the member can
change**. Example for an association that approves joins and enables messaging: *new join request* → validators
→ in-app feed (+ push if configured, generic text, no names); *reservation removed by an administrator* →
the member and administrators → feed + push; *new message* → participants (muted conversations are silent);
*check-in reminder* → the member, local notification 15 minutes before (on the device). The table also states
the limits the code has today: WhatsApp is a group link and personal numbers, not an automatic channel; there is
no application e-mail beyond account e-mails; payment reminders run when an administrator opens Finances.

## 9. Output: a pack, not just an XML

The finish step produces, from the answers:

1. **The file** (`deskilo-workspace.xml`) — only what the app applies (after #2331), plus an *applied / to type
   in the app / kept in the file only* list.
2. **Your first-week checklist** (printable): each remaining task with its section in the Setup Guide and a
   link into the app screen (`app:/route`).
3. **The invitation text** in each language chosen, ready to paste.
4. **Questions for your accountant**: legal form, VAT regime, numbering, exemption wording, e-invoicing — the
   facts the wizard could not decide for the owner.
5. **A brief for an assistant** (optional): a plain-text summary of the choices and the open questions, to paste
   into any assistant the owner trusts. DesKilo's own assistant (MCP) acts as a member and cannot configure a
   space, so the wizard does not pretend otherwise; the Setup Guide says what an assistant is good for here
   (drafting texts, explaining a report) and that every legal sentence is checked with an accountant.

## 10. Where it lives

- Short term: keep the static page (privacy, no account, works offline), restructure it, regenerate the
  catalogue and strings from the registries as today (`build_setup_l10n`), keep the drift gates.
- Medium term: an **in-app first-run wizard** that creates the space from the chosen scenario (template + local
  slots) and applies the answers directly, so no file round-trip exists. The static page remains for
  preparation with an accountant. This removes the whole class of defects in #2331.

## 11. Delivery plan (aggregate issues, one at a time)

| # | Slice | Done when |
|---|---|---|
| P0 | **Fix the contract** (#2331): per-answer destination, `configurationTransfer` no longer a hidden prerequisite, name and environment applied, round-trip test | export → import → read back |
| P1 | Scenario cards + the Open level + stable rail + review in readiness vocabulary | a stranger reaches a bookable space in 20 minutes (test with five newcomers) |
| P2 | Previews: live plan drawing, week view, member's booking sheet, invitation | each preview matches the app's rendering |
| P3 | Run level: tariff presets, payments, notifications table | notifications table equals the code's recipients |
| P4 | Grow level: supported-country check, legal identity, VAT, numbering, accountant questions | the server's issuing refusals can't occur after a clean review |
| P5 | The pack (checklist, invitation, accountant questions, assistant brief) + links from the Setup Guide | every step links to its guide section |
| P6 | In-app first-run wizard | no file round-trip for a new space |

## 12. How we know it works

- Time from the welcome page to a bookable space (target: 20 minutes), measured with five people who have never
  seen the product, observed, no analytics in the page.
- Findings at the review step that the server would later refuse (target: none).
- Support questions about "where do I set X": the Setup Guide answers each with one link.

## 13. Open questions for the owner of the product

1. Which flow is intended for a brand-new person: create in the app first, then import — or the page creates the
   space (needs P6)?
2. Is invoicing outside FR and DE a goal (it changes the wizard's country card)?
3. May the page link the Setup Guide on the project site, and may the guide's screenshots come from the demo?
4. Is the MCP assistant's status as documented in the user guide the truth (the capability ledger says roadmap)? *Answered 2026-10-10 (#2333): yes; the ledger now records MCP as shipped, off until an operator switches it on.*
