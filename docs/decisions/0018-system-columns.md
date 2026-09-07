# ADR 0018 — Six system columns on every table, owned by the server, read as one value

**Status:** accepted · **Date:** 2026-09-07

## Context

Every table carried whatever bookkeeping its author thought of:
`created_at` on most, `created_by_name` on a few, nothing on the
junctions. Nothing said who last touched a row, nothing tied a row to
its workspace except the foreign key that happened to be there, and a
client could write any of it. The owner asked (#992) for six technical
columns on every table, for this project and every next one:
creation and modification date-time and user, the company (workspace)
and the site.

## Decision

1. **Six columns, snake_case, on every table** of the public schema:
   `created_datetime`, `modified_datetime`, `company_id`, `site_id`,
   `created_by_user`, `modified_by_user`. Additions beside what a table
   already has — `created_at`, `workspace_id`, `created_by` stay,
   readers keep working.
2. **The server owns them.** One trigger, `system_columns_stamp()`
   (`zz_` so it fires after every guard), runs BEFORE INSERT OR UPDATE
   on every table: on insert the creation stamp is now() and the
   caller, whatever the row said; on update the creation stamp is kept
   from the stored row; the modification stamp is always now() and the
   caller; `company_id` and `site_id` are derived from the row's own
   keys (`workspace_id`, `id`, `home_site_id`, `level_id`). A client
   value for any of the six is ignored — not refused, ignored, so no
   caller has to learn a new error. Two check constraints state the
   invariants: `modified >= created`, and a workspace-bound row names
   its workspace.
3. **One helper adds them:** `ensure_system_columns('<table>')` —
   columns, backfill, trigger, constraints. Migration 0183 ran it over
   every table; every `create table` from now on calls it in the same
   migration, and a lint refuses one that forgets.
4. **The app reads them as one value object.** `SystemColumns`
   (`lib/core/data/system_columns.dart`): immutable, equal by value,
   with a Null Object for unstamped rows and a tolerant factory that
   never fails a read. Every entity mapped from a row implements
   `SystemStamped` and receives `system: SystemColumns.fromRow(row)`;
   a lint checks every row mapper. The client never writes the six:
   a lint refuses a payload key naming one. A breach of the invariant
   found on read goes to the trace through an observer hook wired once
   at start-up, never trusted silently.

## Consequences

- Audit, tenancy and site scoping have one answer on every table, and
  the instance bundle carries the helper to every new project.
- Guards that compare whole rows must subtract the six
  (`system_column_names()`); `invoices_immutable()` does.
- A backfill runs with the table's user triggers disabled, so history
  is not re-stamped with the migration's clock — and a migration
  cannot use `session_replication_role` on the hosted database.
- The six are not yet shown anywhere; a record's "created by / last
  modified by" line is one widget away, reading `entity.system`.
