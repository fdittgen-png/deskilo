---
name: deskilo-supabase-migration
description: Writing and applying a Supabase migration or RPC change for DesKilo — the rolled-back live harness with impersonated JWT claims, patching long function bodies at asserted anchors, dropping an overload before adding a defaulted parameter, the permission catalog in set_role_permissions, SPDX header, apply_migration, live verification. Trigger whenever a task touches supabase/migrations or an RPC.
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
