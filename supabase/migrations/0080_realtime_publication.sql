-- SPDX-License-Identifier: 0BSD
-- Push-driven freshness (#413). The supabase_realtime publication was
-- EMPTY — no table was ever published, so no change was ever pushed to
-- any client: adding a member needed an app restart, and a settings
-- change did not even refresh on the device that made it.
--
-- Publish the tables the app renders. postgres_changes respects RLS
-- (WALRUS) for INSERT/UPDATE — each subscriber only receives rows their
-- SELECT policy grants. DELETEs broadcast the primary key only (bare
-- uuids); the client treats every event as an invalidation signal, so
-- that is all it needs. Deny-all tables (payment_credentials,
-- member_badges, push_endpoints) are deliberately NOT published.

alter publication supabase_realtime add table
  public.reservations,
  public.members,
  public.workspaces,
  public.profiles,
  public.levels,
  public.offices,
  public.desks,
  public.seats,
  public.plan_images,
  public.events,
  public.event_decisions,
  public.ledger_entries,
  public.payment_intents,
  public.invoices,
  public.services,
  public.accessories,
  public.seat_accessories,
  public.closure_days,
  public.quota_extensions,
  public.fee_bands,
  public.packages,
  public.validation_policies;
