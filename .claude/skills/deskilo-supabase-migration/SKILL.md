---
name: deskilo-supabase-migration
description: Writing and applying a Supabase migration or RPC change for DesKilo — the rolled-back live harness with impersonated JWT claims, patching long function bodies at asserted anchors, dropping an overload before adding a defaulted parameter, the permission catalog in set_role_permissions, system columns on every new table, backfills with triggers disabled, transaction-local settings as capability tokens, copy jobs for storage objects, SPDX header, apply_migration, live verification. Trigger whenever a task touches supabase/migrations or an RPC.
---
# Supabase migrations in DesKilo

Project `zwzbynivewivvjmripeb`; migrations numbered `NNNN_name.sql` in
`supabase/migrations/` (next number: see memory "migrations through").
Every file starts with `-- SPDX-License-Identifier: 0BSD` (lint).

## 1. Harness BEFORE apply — always
Run the DDL + a `do $harness$ … raise exception 'HARNESS_RESULTS …' $harness$`
block through `execute_sql`: the exception rolls everything back and the
message carries the assertions. Impersonate users with
`perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role','authenticated')::text, true);`
Pick fixtures by name (`workspaces.name ilike 'COWORKONTI%'`), never by id.
Test the negative paths in nested `begin … exception when others then v_err := sqlerrm; end;`.
Only then `apply_migration` with the SAME SQL (plus the header comment),
then a `select` that proves columns/functions/triggers exist.

## 2. Patching a long function you do not own
```
select pg_get_functiondef(p.oid) into v_def … where proname = 'create_invoice';
v_anchor := E'exact text\n'; if position(v_anchor in v_def) = 0 then raise exception 'NNNN: anchor missing'; end if;
execute replace(v_def, v_anchor, new_text);
```
A silent no-op ships a broken document — always assert the anchor.
An anchor that ends in `))` closes MORE than the expression you mean:
0169 appended `, 'site', …` behind the parenthesis that also closed
`jsonb_build_object(` and every detailed invoice failed for a day
(#960, fixed by 0175). plpgsql compiles a statement when it is first
REACHED, so the harness must execute every branch the patch touches —
for create_invoice that means a DETAILED invoice (`p_detailed => true`)
in the rolled-back transaction, not only the plain one.

## 3. Overloads
Adding a parameter WITH a default to an existing function creates a
second overload; 4-arg calls become ambiguous. `drop function if exists
public.f(uuid, boolean, text, text);` first, then `create function`.

## 4. Registries on the SQL side
- `events_type_check` + `validation_policies_event_type_check`: both
  constraints list every event type — extend both, seed the policy row
  per workspace, and the client's FOUR places (AGENT_RULES).
- `set_role_permissions` has a literal `v_catalog text[]` — a new
  `WorkspacePermission` MUST be added there (0155) or the roles screen
  cannot save; `roles_screen_test` reads the LATEST migration carrying
  that array. `has_permission` admin defaults are a literal list too.
- `invoices_no_mutation` trigger: lift only for test data, re-arm.
- Decisions apply through an AFTER UPDATE trigger on `events`, never a
  branch in `respond_to_event` (0151 idiom).

## 5. Client mirror
Wire keys shared with the client are pinned by tests (`personal_info_test`
pins Dart renderings equal to the SQL harness output). When a rendering
exists twice (SQL + Dart), change both and keep the pin.

## 6. Lessons of 2026-09-07 (0180–0190)
- **Every `create table` is followed by `select public.ensure_system_columns('<table>');`**
  in the same migration (#992, lint `system_columns_test`). The six
  columns are the server's: the `zz_system_columns_stamp` trigger
  overwrites whatever a client sends. A guard that compares whole rows
  (`invoices_immutable`) must subtract `public.system_column_names()`.
- **Backfills and triggers.** The hosted database refuses
  `set_config('session_replication_role', …)`. Wrap a backfill in
  `alter table … disable trigger user` / `enable trigger user` — and do
  it BEFORE the update: an AFTER trigger that fired queues events and
  `ALTER TABLE … enable trigger` then fails with "pending trigger
  events". Creating a trigger after the backfill avoids the dance.
- **Trigger order is alphabetical.** A stamp that must see the final row
  is named `zz_…`; a guard that must judge first keeps its name.
- **Reserved words.** `returns table (key text, row jsonb)` is a syntax
  error — `row` is reserved; name it `data`. In an `update … set x = …`,
  `array_agg(x)` over an aliased `x` collides with the column → "aggregate
  functions are not allowed in UPDATE"; put the aggregate in a helper
  (`public.jsonb_text_array(jsonb)`).
- **Harness expressions.** `jsonb_array_elements(x) t` → read `t.value->>`,
  never `t->>` (that is the row, "text ->> unknown"). `members` has no
  `created_at`; pick the owner with `status = 'active' … limit 1`.
  `foreach … in array array[[a,b],[c,d]]` cannot assign to two scalars —
  use two parallel arrays and an index.
- **A capability token between functions:** `perform set_config('deskilo.deploying',
  from || ':' || to, true)` (transaction-local) and a guard
  `public.deploying_touches(ws)` — lets `deploy_entities` pass the
  transfer's own `has_permission` checks without granting anything.
- **Storage objects are not the database's to move.** A function returns
  `copy_jobs` `[{from, to}]` and the client copies with
  `storage.from(bucket).copy(from, to)`; paths keep their structure under
  the target prefix (`regexp_replace(path, '^[^/]+', target)`); the diff
  compares by file name, never by prefix. `storage.objects` is readable
  for a preview (`report_image_names`).
- **Copying rows across workspaces:** `insert into t select (jsonb_populate_record(null::t,
  (to_jsonb(row) - 'id' - 'workspace_id' - <system columns>) || jsonb_build_object('id', gen_random_uuid(), 'workspace_id', target))).*`.
- **Anchored catalog extensions and test pins:** a test that extracts
  `v_catalog text[] := array[…]` by regex from "the latest catalog
  migration" breaks when the extension is an anchored patch (0185) —
  concatenate the base file's array with the patch file's text.
- **Restating vs patching:** an applied migration's file is never
  rewritten; if a later fix needs a whole-function text (0184's
  `ensure_system_columns`), it is a new migration.
