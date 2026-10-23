-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #2942 — anon and authenticated keep only the table privileges a policy
-- or a client path uses, and a new table starts without the rest.
--
-- Supabase's default privileges hand `anon` and `authenticated`
-- SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER and
-- MAINTAIN on every table `postgres` creates in `public`. Migrations
-- since 0211 close their own tables (`revoke all … ; grant select …`),
-- but 52 older tables still carried the whole set. Row-level security
-- refuses every write their policies do not allow, so nothing is
-- reachable today. TRUNCATE, however, is not subject to row-level
-- security, and MAINTAIN takes table locks: both widen the blast radius
-- of any future interface that runs SQL as the caller.
--
-- Decision list (inventory of the dev project at schema version 562):
--
-- 1. TRUNCATE, REFERENCES, TRIGGER, MAINTAIN — revoked from anon and
--    authenticated on every table of `public` (52 tables held them).
--    No client path truncates, declares a foreign key, creates a trigger
--    or maintains a table; foreign-key checks and referential actions
--    run as the table owner.
--
-- 2. INSERT, UPDATE, DELETE for anon — revoked on every table (50 held
--    them). No policy names anon. The permissive write policies that
--    apply to `public` (and so to anon) all reduce to `auth.uid()`:
--    `is_owner_of`, `workspaces_permitting`, `has_permission`,
--    `can_read_member_note`, `id = auth.uid()`, `members.user_id =
--    auth.uid()`. Without a user none of them can ever be true.
--
-- 3. Writes for authenticated — revoked where no permissive policy for
--    that command exists (only the restrictive `mcp_delegated_deny`
--    and a SELECT policy) and no client writes the table. `lib/`,
--    `packages/` and the edge functions were searched for
--    `.from('<table>').insert|update|upsert|delete`; the two edge
--    function writers (`invoice_transmissions`, `payment_intents`) use
--    the service-role client. Every other writer is a SECURITY DEFINER
--    function running as the owner; the only invoker functions that
--    write a table here are `ensure_system_columns` (not executable by
--    clients) and `save_workspace_settings` (UPDATE workspaces, kept).
--      INSERT, UPDATE, DELETE revoked (31 tables): conversation_participants,
--        conversations, data_access_log, deployments, event_decisions,
--        events, expense_occurrences, expense_repartitions,
--        expense_schedules, invitations, invoice_match_payments,
--        invoice_matches, invoice_reminders, invoice_transmissions,
--        invoices, ledger_entries, managed_identities, member_badges,
--        number_sequences, payment_intents, platform_access_log,
--        platform_admins, price_negotiations, quota_extensions,
--        reservations, sites, usage_records, vat_declarations,
--        vat_rates, workspace_template_grants, workspace_templates
--      INSERT, UPDATE revoked, DELETE kept (member_notes_delete): member_notes
--      INSERT revoked, UPDATE + DELETE kept (owner policies): members, workspaces
--      INSERT, DELETE revoked, UPDATE kept (profiles_update): profiles
--      All writes kept (a permissive ALL policy and a client writer,
--        17 tables): accessories, charging_stations, closure_days,
--        credit_products, desks, fee_bands, levels, offices, packages,
--        plan_images, plans, push_endpoints, seat_accessories, seats,
--        services, validation_policies, workspace_documents
--
-- 4. SELECT is untouched. `public` has no views or materialized views.
--
-- 5. New tables: the default privileges of `postgres` in `public` stop
--    granting TRUNCATE, REFERENCES, TRIGGER and MAINTAIN to anon and
--    authenticated, and stop granting anon any write. A table meant for
--    anon writes says so with its policy and an explicit grant. SELECT
--    and the writes of authenticated stay in the defaults, so the
--    existing `revoke all … ; grant …` convention is unchanged;
--    `ensure_system_columns` adds columns and grants nothing.
--
-- `00_schema_guarantees`-style assertions: pgTAP 267.

revoke truncate, references, trigger, maintain on all tables in schema public from anon, authenticated;

revoke insert, update, delete on all tables in schema public from anon;

revoke insert, update, delete on table
  public.conversation_participants,
  public.conversations,
  public.data_access_log,
  public.deployments,
  public.event_decisions,
  public.events,
  public.expense_occurrences,
  public.expense_repartitions,
  public.expense_schedules,
  public.invitations,
  public.invoice_match_payments,
  public.invoice_matches,
  public.invoice_reminders,
  public.invoice_transmissions,
  public.invoices,
  public.ledger_entries,
  public.managed_identities,
  public.member_badges,
  public.number_sequences,
  public.payment_intents,
  public.platform_access_log,
  public.platform_admins,
  public.price_negotiations,
  public.quota_extensions,
  public.reservations,
  public.sites,
  public.usage_records,
  public.vat_declarations,
  public.vat_rates,
  public.workspace_template_grants,
  public.workspace_templates
from authenticated;

revoke insert, update on table public.member_notes from authenticated;
revoke insert on table public.members, public.workspaces from authenticated;
revoke insert, delete on table public.profiles from authenticated;

alter default privileges for role postgres in schema public
  revoke truncate, references, trigger, maintain on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke insert, update, delete on tables from anon;

select public.set_deskilo_schema_version(9999);
