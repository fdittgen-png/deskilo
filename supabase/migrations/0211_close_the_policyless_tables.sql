-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0211 — #1226: a table with no policy grants nothing either.
--
-- Found by the first pgTAP test that ever ran against this database.
-- Four tables have row-level security enabled and NO policy at all:
--
--   badge_auth_attempts    the rate-limit trail behind badge sign-in
--   einvoice_credentials   platform credentials for e-invoicing
--   payment_credentials    the PSP secrets
--   push_config            the FCM service account
--
-- RLS with no policy denies everything, so none of them leaks today.
-- But all four carried SELECT, INSERT, UPDATE and DELETE for `anon` and
-- `authenticated` — Supabase's default privileges on a new table in
-- `public`, never revoked because the policy layer happened to be doing
-- the work. The safety was one `create policy` away from ending, on the
-- four tables in the schema that hold secrets.
--
-- Two layers that agree is the point: the grant says no, and the policy
-- says no. Reaching these rows stays what it already is — a
-- `SECURITY DEFINER` function, or the service role inside an edge
-- function, both of which are unaffected by a grant to `anon`.
revoke all on table public.badge_auth_attempts from anon, authenticated;
revoke all on table public.einvoice_credentials from anon, authenticated;
revoke all on table public.payment_credentials from anon, authenticated;
revoke all on table public.push_config from anon, authenticated;
