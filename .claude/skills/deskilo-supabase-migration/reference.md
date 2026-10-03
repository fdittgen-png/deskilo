# deskilo-supabase-migration — reference

Idioms and incidents behind the ritual, grouped by topic.

## Anchored patches

```
select pg_get_functiondef(p.oid) into v_def … where proname = 'create_invoice';
v_new := pg_temp.anchor_replace(v_def, E'exact text\n', new_text);
if v_new is null then raise exception 'NNNN: anchor missing'; end if;
execute v_new;
```
- `pg_temp.anchor_replace` (defined at the top of the migration, as in 0227/0230)
  tries the exact text first, then the same text with every whitespace run
  matched as whitespace — the migration FILES and the hosted bodies wrap lines
  differently, and the replay from empty is what catches it. Anchor on the piece
  that carries the meaning (the call, the message), not the whitespace around it.
- A silent no-op ships a broken document — always assert. An anchor that ends in
  `))` closes MORE than the expression you mean: 0169 appended `, 'site', …` behind
  the parenthesis that also closed `jsonb_build_object(` and every detailed invoice
  failed for a day (#960, fixed by 0175).
- plpgsql compiles a statement when it is first REACHED: the harness executes every
  branch the patch touches (for `create_invoice`, a DETAILED invoice
  `p_detailed => true`, not only the plain one).
- On dev, patch in place the same way and check `md5(prosrc)` against the file;
  for a long generated migration that changed after the apply, patch the one
  changed line rather than re-applying ~95 KB. A long generated file is best applied
  by a subagent told to paste it verbatim, then verified by md5 of its `$registry$` bodies.
- An anchored patch of an OLD long-patched function (`calendar_items`,
  `export_my_data`, `create_invoice`) always means the one CI-artifact copy of
  `contract.txt` (`contract_predict` exit 2).

## SQL idioms

- **Backfills and triggers.** The hosted database refuses
  `set_config('session_replication_role', …)`. Wrap a backfill in
  `alter table … disable trigger user` / `enable trigger user` — BEFORE the update:
  an AFTER trigger that fired queues events and `enable trigger` then fails with
  "pending trigger events". Creating the trigger after the backfill avoids the dance.
- **Trigger order is alphabetical.** A stamp that must see the final row is named
  `zz_…` (`zz_system_columns_stamp`); a guard that must judge first keeps its name.
  The six system columns are the server's: the stamp overwrites what a client sends.
- **Reserved words.** `returns table (key text, row jsonb)` is a syntax error —
  name it `data`. In `update … set x = …`, `array_agg(x)` over an aliased `x`
  collides with the column ("aggregate functions are not allowed in UPDATE"); use a
  helper (`public.jsonb_text_array(jsonb)`).
- **Harness expressions.** `jsonb_array_elements(x) t` → read `t.value->>`, never
  `t->>`. `members` has no `created_at`; pick the owner with `status = 'active' … limit 1`.
  `foreach … in array array[[a,b],[c,d]]` cannot assign two scalars — use parallel
  arrays and an index. Rows inserted in one transaction share `now()`: select a row
  by a property, never `->0` over `order by created_at`; a staleness "revision" is
  `md5(to_jsonb(row)::text)`, not `modified_datetime`.
- **A capability token between functions:** `perform set_config('deskilo.deploying',
  from || ':' || to, true)` (transaction-local) plus a guard
  `public.deploying_touches(ws)` lets `deploy_entities` pass the transfer's own
  `has_permission` checks without granting anything.
- **Storage objects are not the database's to move.** A function returns
  `copy_jobs` `[{from, to}]` and the client copies with
  `storage.from(bucket).copy(from, to)`; paths keep their structure under the target
  prefix (`regexp_replace(path, '^[^/]+', target)`); diffs compare by file name.
  `storage.objects` is readable for a preview (`report_image_names`).
- **Copying rows across workspaces:** `insert into t select (jsonb_populate_record(null::t,
  (to_jsonb(row) - 'id' - 'workspace_id' - <system columns>) || jsonb_build_object('id', gen_random_uuid(), 'workspace_id', target))).*`.

## Security idioms

- **`anon` having execute is usually harmless and never acceptable.** Bodies
  re-check `auth.uid()` / `has_permission()` / `is_member_of()`, so `anon` is
  refused — the SECOND line of defence; the grant is the first. 99 of 260 functions
  were executable by `anon` (#1048) because `CREATE OR REPLACE` preserves the ACL;
  `export_floor_plan` was the one that forgot its internal check.
- **Put a reading rule in ONE definer function and make the policy call it.**
  `can_read_member_note(…)` answers only for `auth.uid()`, so it may be granted to
  `authenticated`; the select policy, the delete policy and every definer reader ask
  the same question. An inline policy query on `conversation_participants` recurses
  into that table's own policy; the definer function breaks the cycle.
- **A column on `profiles` can never be private** — every space mate `select *`s a
  profile (0002). A field whose audience may be "nobody" lives in its own no-access
  table, projected by a definer RPC.
- **An operator function takes no verdict.** An activation that accepts "checks
  passed" can be forged by its caller: take the identifiers of what was inspected
  and a fingerprint the database recomputes; refuse on any difference (0312
  `operator_activate_mcp_runtime`).

## Deleting a workspace

Three guards refuse, in order: `protect_last_owner` on the members cascade,
`invoices are immutable`, then a RESTRICT FK from `event_decisions` → `members`
(checked immediately, so the workspace's own cascade never reaches through it):

```sql
alter table members  disable trigger user;   -- and invoices, reservations,
alter table invoices disable trigger user;   -- ledger_entries, events
delete from event_decisions where event_id in (select id from events where workspace_id = any(ids));
-- then the workspace-scoped children that reference events with NO ACTION or
-- SET NULL: invoice_match_payments, invoice_matches, invoice_reminders,
-- invoice_transmissions, expense_repartitions, expense_occurrences,
-- expense_schedules, price_negotiations, quota_extensions, usage_records,
-- ledger_entries, events
delete from reservations where workspace_id = any(ids);
update invoices set replaces_invoice_id = null, settled_by_invoice_id = null
  where workspace_id = any(ids);        -- the self-referencing chain
delete from invoices where workspace_id = any(ids);
delete from members  where workspace_id = any(ids);
delete from workspaces where id = any(ids);   -- the rest cascades
```
Stand the guards down for the delete and bring them straight back. Read the FK
graph first: `select conrelid::regclass, confdeltype from pg_constraint where
contype='f' and confrelid='members'::regclass` (`c` cascade, `r` restrict now,
`a` end of statement, `n` null). `profiles.default_workspace_id` is SET NULL —
count those people in the harness and report them.

## pgTAP probe (running a test file on dev, rolled back)

- No local Docker runner: replay the file's exact shape through one rolled-back
  `execute_sql`. `create extension if not exists pgtap with schema extensions` INSIDE
  the probe's `do` block works and rolls back with it.
- The probe loop: `foreach s in array array[$s$…$s$, …] loop begin … exception when
  others then <log>; end; end loop;`, collect `not ok` lines, end with
  `raise exception 'PROBE failed=% log=%', num_failed(), v_log` (`__tresults__` does
  not exist in this pgTAP — `num_failed()` does). Per-statement subtransactions keep
  `set local role`.
- Two EXECUTE forms: `if s ilike 'select%' then execute s into v; else execute s; end if;`
  — `execute … into` on an insert/update/delete fails ("INTO used with a command that
  cannot return data") and the seed silently never happens.
- The runner is a script, not a hand edit: split the file into statements (track
  `$$` parity), wrap each in `$s$…$s$`; when the file's bodies use only `$$`/`$q$`,
  one tag `$x$` carries the whole probe. Never `set local role` in a file that seeds
  by direct insert.
- A multi-scene file accumulates state: a scene that ended every connection of a
  person forces a later scene to consent again.
- **Inject a fault inside the test, never in a deployed function**: save
  `pg_get_functiondef(fn)`, replace ONE anchor (refuse unless it occurs exactly once:
  `(length(def) - length(replace(def, anchor, ''))) / length(anchor)`), probe,
  `execute` the saved text back. `97_mcp_conformance_journey.sql`
  (`pg_temp.inject` / `pg_temp.restore`) is the worked example. A dropped unique
  index is recreated only after deleting the rows the fault let in.
- Red first can reveal a second defect: keep both directions (positive and negative
  controls) in the file.
- Read the state words before asserting them: `my_database_capabilities` says
  `requested` (not `pending`); consent scopes take `target_ceiling = workspace` from
  their operations.
- A second installation cannot live in one database (`installation_identity` is a
  singleton): model it as a foreign id and epoch, and say in the header that SQL claim
  injection proves no OIDC/OAuth.

## MCP fixtures (pgTAP and `scripts/db_race`)

- Every acting user needs a Google identity (`auth.identities` row, provider
  `'google'`), an `amr` claim with method `oauth` in `request.jwt.claims`, AND an
  identity binding (`select public.finalize_identity_binding();`). A missing binding
  answers `no_identity` and silently skips the lock under test.
- `mcp_time_arg` accepts only `Z` or `±HH:MM` offsets; psql prints `+02`, so emit
  fixture instants as ISO-Z: `to_char(t at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')`.
- Fixture traps: `profiles.whatsapp` must match `^\+[0-9]{6,19}$` (a failed fixture
  update silently leaves display names empty and fails unrelated assertions).
