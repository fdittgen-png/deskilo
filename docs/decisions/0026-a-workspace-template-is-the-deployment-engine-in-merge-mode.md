# ADR 0026 — A workspace template is the deployment engine in merge mode

**Status:** accepted · **Date:** 2026-09-17

## Context

Until #1276 a workspace template was a floor plan and nothing else
(`workspace_templates.floor_plan`, 0196/0199). The configuration that
makes a coworking space *work* — hours and booking rules, tariffs and fee
schedules, validation rules, the role matrix, reminders, closure days,
number formats, the lexicon, the feature profile — could not travel.

The dev/prod deployment engine (0185–0190, #990) already knew every one
of those as an entity (`deployable_entities()`), could export them
(`export_entities`), compare them (`preview_deployment`) and write them
(`import_workspace_configuration`, `merge_floor_plan`). A second engine
for templates would have been a second definition of what a workspace's
configuration *is*, and the two would drift.

But the writer could not be reused as it was. **A deployment is a
mirror**: it makes production equal to development, so it deletes the fee
bands, closure days, validation policies and documents the payload does
not name, and deactivates the packages, services, plans, accessories and
VAT rates it does not name. Applying "the French coworking rules" to a
space that already runs must never do that.

## Decision

**A template is a stored, sanitized snapshot of the deployment engine's
entities, applied through the same writers in merge mode.**

1. **One writer, two modes** (0219, 0230).
   `import_workspace_configuration(ws, configuration, p_mode default
   'mirror')`. Mirror is unchanged and remains the default, so every
   deployment means what it meant. Merge never deletes and never
   deactivates, and it never collides:
   - a **fee schedule** is replaced whole. Its bands partition 0–100 %
     together, and interleaving two schedules makes the band lookup
     ambiguous;
   - **closure days and documents** are added when absent;
   - **validation policies** are updated by event type;
   - the target **keeps its own default VAT rate**;
   - the **floor plan** merges by name, and the stripped plan carries no
     prices, so a matching desk keeps its own.

2. **Publication is a positive allow-list, enforced server-side** (0229).
   `template_publication_rules()` classifies every deployable entity.
   - An entity with no rule is denied, so a new entity is unpublishable
     until somebody decides.
   - Denied for good: sites and their addresses, payment instructions,
     invitation texts, document links and designs.
   - Identity travels without address, VAT id, legal id, exemption
     reason, VAT account, legal mentions or WhatsApp group.

   The client cannot skip the stripping, because it happens in
   `save_workspace_as_template`.

3. **Groups are the vocabulary.** Each entity declares a `group` and a
   `merge_policy` in `deployable_entities()`. A template is applied per
   group, and the preview reports per group: `new`, `change`, `matching`
   or `needs_attention` (with a reason), each with its items.

4. **One comparison** (0230). `configuration_change_set(to, snapshot,
   entities, mode)` authorizes nothing and no client can call it. Its
   callers authorize:
   - `preview_deployment` with `may_deploy`. Its output was proven
     identical on every live pair, except that number series are now
     keyed by journal instead of reported as removed and re-added;
   - `preview_workspace_template` with `manageConfiguration` on the
     target and a readable template.

   In merge mode the change-set reports only what the writer will do, so
   a second application previews as `matching` throughout.
   `apply_workspace_template` stores the same change-set on its record.

5. **Compatibility is server-side and fails closed.** A template carries
   `schema_version` and `template_version`, and one function lists the
   snapshot formats this server applies. `template_compatibility` gives
   one verdict:
   - `not_supported` for an unknown format or entity;
   - `partial` only when the caller chose groups and so excluded the
     unknown entities;
   - otherwise `supported`.

   Apply refuses on `not_supported`, and the target is unchanged.

6. **Provenance is a sibling table.**
   `workspace_template_applications` records the template, its versions,
   the groups, the entities, the change-set and what the target held
   before, so an application is reversible the way `rollback_deployment`
   reverses a deployment. `deployments` could not hold it: its pair
   columns are `NOT NULL` and describe a dev↔prod pair.

## Consequences

- A template and a deployment cannot disagree about what configuration
  is. A new entity added for deployment is immediately a candidate for
  templates, and unpublishable until classified.
- The mirror is protected by its default, and by `32_template_change_set.sql`
  asserting that the mode-less import still deletes.
- Merge semantics live in the writer, so they are enforced for every
  caller, including the client's configuration import if it ever passes
  `merge`.
- A fee schedule is the one setting a template overwrites as a whole. The
  preview flags it as `needs_attention` whenever the target already has a
  different schedule.
- The anchored patches that built merge mode read the hosted function
  bodies, which wrap lines differently from the bodies a replay builds.
  They go through a whitespace-tolerant `pg_temp.anchor_replace` (0227,
  0230) so the migrations replay from empty.
- The UI half (the publish flow, group choice and preview) is #1280. It
  consumes `preview_workspace_template` and never computes a difference
  itself.
