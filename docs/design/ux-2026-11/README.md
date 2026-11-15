# Target layouts for the November 2026 UX review

This folder holds target-layout mockups for the DesKilo app, drawn as static HTML and CSS (no script, no web font, no external resource) with synthetic Demo data. They specify layout and wording for Flutter widgets that already exist; they are not a new visual style. Tracking issue: #4051.

Status of everything here: **target layout, not implemented, not tested with users.** A line marked *Hypothesis* on a sheet still has to be checked with a task walk.

## How to read a sheet

Open `index.html`, then a sheet in `sheets/`. Each sheet has, top to bottom: the title; the review captures it answers (numbers; the captures themselves contain browser chrome and stay local); the issue that implements it; BEFORE (a clean capture rendered from the tree where one exists, otherwise a short description of what the capture shows); AFTER desk (1440×900) and AFTER phone (390×844); state variants; “What changes and why”, where every line is marked **Observed** (seen in a capture), **Decided** (a decision of the brief) or **Hypothesis**; and “Built from”, the existing Flutter components. “Open question” notes mark what the mockup does not decide.

`renders/` holds one PNG per sheet for viewing on GitHub. `before/` holds the tree captures reused as “before” images (fixture data, not the Demo, except where a sheet says otherwise). `coverage.md` is the route, size, persona, state and test coverage matrix.

Visual direction: calm neutral surfaces, one teal accent `#0F766E`, 4 px grid, 8/12 px radii, system font stack, 14 px base, amounts right-aligned with tabular figures, light theme only, status always text plus symbol.

## Sheets

| Sheet | Review captures | Issue | Status |
|---|---|---|---|
| [A1](sheets/A1-shell.html) Shell and page header | 07, 12, 14, 19 | #4057, #4056, #4060, #4019 | target layout, not implemented, not tested with users |
| [A2](sheets/A2-privacy.html) Privacy and the task assistant inside the business shell | 20, 21, 26 | #4057 | target layout, not implemented, not tested with users |
| [B1](sheets/B1-records.html) Records page (documents as the example) | 19, 05, 07, 10, 28, 29, 30 | #4059 (invoices); documents leaf to be filed; #4035 done | target layout, not implemented, not tested with users |
| [C1](sheets/C1-invoices-overview.html) Invoices overview | 07, 28, 29 | #4059 | target layout, not implemented, not tested with users |
| [C2](sheets/C2-issue-invoice.html) Issuing an invoice | 08, 09 | #4058 | target layout, not implemented, not tested with users |
| [D1](sheets/D1-calendar-week.html) Calendar week with a booking selected | 02, 03, 04 | #4054, #4056; #4021 done | target layout, not implemented, not tested with users |
| [D2](sheets/D2-calendar-phone.html) Calendar on a phone with Decisions and the Alerts view | 27, 31 | #4055, #4056; #4021 done | target layout, not implemented, not tested with users |
| [E1](sheets/E1-supplier-bill.html) Supplier bill form (Add purchase) | 11, 08, 16 | #4058 (form pattern); supplier-bill leaf to be filed | target layout, not implemented, not tested with users |
| [F1](sheets/F1-bank-matching.html) Bank matching with the confirmation | 13 | #4053 | target layout, not implemented, not tested with users |
| [F2](sheets/F2-accounting-overview.html) Accounting overview | 12 | to be filed (accounting overview leaf) | target layout, not implemented, not tested with users |
| [G1](sheets/G1-members.html) Member page and members directory | 05, 06 | directory search and member-page leaves to be filed | target layout, not implemented, not tested with users |
| [G2](sheets/G2-me-finances.html) Me home and My finances | 22, 30 | Me-card leaf and statement-tile leaf to be filed | target layout, not implemented, not tested with users |
| [G3](sheets/G3-conversation.html) Conversation | 25 | #4060 | target layout, not implemented, not tested with users |
| [G4](sheets/G4-task-assistant.html) Task assistant | 26 | #4057 (shell); assistant leaf to be filed | target layout, not implemented, not tested with users |
| [G5](sheets/G5-setup-head.html) Setup head | 15, 16 | setup leaf to be filed | target layout, not implemented, not tested with users |
| [G6](sheets/G6-discovery.html) Discovery | 23, 24 | #3554, #2832 (public profiles); advanced-action leaf to be filed | target layout, not implemented, not tested with users |
