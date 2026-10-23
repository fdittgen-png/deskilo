# ADR 0047 — The setup guide: levels per process, outcome milestones, one status

**Status:** accepted · **Date:** 2026-10-22 · **Refs:** #2864, #2866, #2865, #2867, #2868, #2869, #2873, #2876

## Context
A workspace owner meets setup in five places that do not know about each
other: the creation stepper (4 steps, ending on Reserve), the readiness card
"Setting up this space" (`workspace_readiness`, 0399), the local-setup card
(`workspace_local_readiness`, 0280), the tip carousel on settings, and the
offline questionnaire `web/setup.html`. Readiness only knows two meanings of
"required" (a first booking, invoicing); choosing what the space should do
means 143 feature switches; nothing says "you are done for what you chose".
`docs/design/setup-wizard-redesign.md` proposed a redesign; the owner's
requirements and two external reviews (2026-10-22) sharpened it. This ADR
fixes the contracts every child of #2864 builds on.

## Decision

### 1. Three contracts, not one
- **The step catalogue** — one canonical definition, generated to
  `contracts/setup/steps.json`: step id, group, applicable levels and
  conditions, milestone, dependencies, completion evidence, actor, route and
  the domain command it uses, risk and reversibility, help anchor, estimate,
  test fixture. The app, the MCP, the help and `web/setup.html` read it.
- **The runtime setup status** — `workspace_setup_status(p_workspace_id)` on
  the server, computed from the applied configuration and the operator's
  facts. It is the only source that may say a step is ready. The app and the
  MCP read it; `workspace_readiness` stays as a compatibility view until its
  readers have moved.
- **The offline preparation page** (`web/setup.html`) prepares and previews a
  configuration without a server and exports the file the import applies
  (#2331). It never claims that a live workspace is ready.

### 2. Draft, applied configuration and readiness are three things
A **draft** holds unfinished answers per step and workspace, on the server,
readable only by those who may configure. Only the existing **domain
commands** apply configuration, with their own validation, permissions and
read-set conflict check (0245); the guide is not a second configuration
engine. **Readiness** is computed from what was applied. "Saved" is shown
only after the server confirmed.

### 3. Completeness = presets + a level per process
The owner states facts in plain questions — the kind of organisation, whether
members book directly, whether members owe money, whether the app issues
legal invoices, whether members pay online, the country. The guide
recommends a level per process and says why. The three money questions stay
apart: statements without invoices, invoices without online payment and any
other combination are valid.

| Process (owner-facing) | Levels |
|---|---|
| Bookings | simple · rooms and resources · measured |
| Members and community | basic · organised |
| Money | none · statements · invoices (+ online payments as an add-on) |
| Tax and accounting | none · VAT · VAT, accounting and e-invoicing (needs Money = invoices) |
| Purchases and premises | none · expenses · full |
| Presentation | basic · branded · public |
| Operations and insight | basic · insight · advanced (environments, deployments, transfer) |
| Assistant | off · on |

- **Levels are data**: `supabase/templates/profiles/*.json`, each level a
  list of feature keys on top of the core base, expanded by
  `tool/build_builtin_templates.dart`. A contract test proves every level
  respects `featureManifest.requires`, levels of one process nest, and every
  selectable feature of the catalogue belongs to exactly one level.
- **Presets are level vectors**: Essentiel = simple, basic, statements,
  none, none, basic, basic, off (statements without invoices or VAT);
  Standard = rooms and resources, organised, invoices, none or VAT from the
  answers, expenses, branded, insight, off; Complet = every process at its
  highest level, the assistant as the owner chooses.
- Applying a preset or a level previews the change (`planProcessChange`) and
  applies it only on acceptance (`applyProcessChange`); it never silently
  overwrites a level the owner customised. Lowering a level keeps the data
  (`DeactivationMode.keepDependants`). `/features` stays the expert view.
- **Legal obligations are derived, never asked**: e-invoicing obligations,
  VAT thresholds and their dates come from the reviewed tax reference data
  for the country, shown with their source; where no confirmed row exists the
  guide says so and names the accountant's or operator's action. The
  countries where invoices can actually be issued stay enforced on the server.

### 4. Outcome milestones
**Bookable** → **Ready for money** → **Ready to invoice** → **Live**. Each
is a server condition over the status, never "configuration saved". A
milestone the chosen levels do not need is not shown. Progress counts the
required steps of the next milestone ("3 of 5 needed to take bookings"),
never a total of optional or inapplicable steps. **Live** needs an explicit
confirmation after a check-answers review (#2876).

### 5. Step groups and completion
Groups **Open** (Bookable), **Run** (Ready for money), **Grow** (Ready to
invoice), **Launch** (Live). States: ready · needs configuration · blocked by
a prerequisite · waiting for an operator or provider · not applicable ·
deferred by the owner. A step the system can verify becomes ready only from
its evidence — never by acknowledgement or dismissal. "Mark as done" exists
only for steps the server cannot verify. A deferred step is never counted as
done and blocks a milestone only if it is required for it.

### 6. Surfaces
`/setup` is the hub: the one next action for the chosen milestone first, then
relevant steps, then deferred or blocked steps with their reason, then
optional capabilities collapsed. Steps outside the chosen levels are not
listed; "Add more to your space" leads to the levels. With the guide on, the
two settings cards and the tip carousel are replaced by one resume banner on
settings, Reserve, Overview and Attention. Every step is pre-filled from the
country, the template or the demo where a sensible value exists, so most
steps are "check and confirm", with a preview built from the app's own
widgets.

### 7. The flag
`WorkspaceFeature.setupGuide`: core tier, default on, process
operations › configuration, owner beta until the newcomer evidence (#2874).
Off: today's cards, Get-started line and routes behave exactly as before.

### 8. Assistant (MCP)
Setup operations carry an explicit permission each (no fallback). Reads come
first. A write is a proposal stored with the configuration revision it was
computed from; the app shows the exact change; the owner confirms or cancels;
the server revalidates against the current revision and permission and only
then applies. A stale proposal is re-previewed, never applied; cancelling
changes nothing. Secrets (payment and e-invoicing credentials) are never tool
inputs. `mark_setup_step` cannot complete a verifiable step.

### 9. Demo and sample data
Demo deep links take `space`, `persona` and `to` from an allow-list of in-app
routes; the demo explains itself first. Sample data lives only in a test
twin, every generated record carries a generation batch id, and clearing
removes exactly that batch. Neither ever makes a space live, invites a real
person or calls a production provider.

## Consequences
- Every child of #2864 cites the section it implements; a change to these
  contracts is a new ADR.
- The redesign document (`docs/design/setup-wizard-redesign.md`) stays as the
  background; where it differs (a greyed list of every step, profiles chosen
  first, the obligation date asked of the owner), this ADR wins.
- The epic closes on the end-to-end scenarios listed in #2864 (Essentiel
  booking, paid coworking with a passing test invoice, interrupt and resume,
  safety, sample data and launch), with accessibility and the five languages
  across all of them.
