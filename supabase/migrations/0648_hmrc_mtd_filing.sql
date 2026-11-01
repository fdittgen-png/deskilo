-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two nullable columns on accounting_connections and two service-only
-- functions; no row moves)
--
-- 0648 (#2470) -- the consumer slice of the HMRC MTD VAT submission.
--
-- 1. A per-connection LEASE before a provider refresh. HMRC's refresh tokens
--    are single-use, so two writers (the refresh action and the delivery
--    path) must never call the token endpoint for one connection at the
--    same time: the second would be refused for a token the first just spent
--    and could clear the first's newer pair. The writer that wants to refresh
--    claims the lease; everyone else waits and re-reads. A lease is a holder
--    and an expiry, so a crashed writer frees it by itself.

alter table public.accounting_connections
  add column refresh_lease_holder text,
  add column refresh_lease_until timestamptz;

-- True when [p_holder] now holds the lease of a live connection: nobody held
-- it, the previous hold ran out, or [p_holder] already held it. The hold is
-- 5 to 60 seconds.
create or replace function public.claim_accounting_refresh_lease(
  p_connection_id uuid, p_holder text, p_seconds integer
) returns boolean language plpgsql security definer set search_path = public as $fn$
declare
  v_claimed uuid;
begin
  if char_length(btrim(coalesce(p_holder, ''))) not between 8 and 100 then
    raise exception 'a lease holder is 8 to 100 characters' using errcode = '22023';
  end if;
  update public.accounting_connections c
     set refresh_lease_holder = p_holder,
         refresh_lease_until = now() + make_interval(secs => least(greatest(coalesce(p_seconds, 30), 5), 60))
   where c.id = p_connection_id and c.revoked_at is null
     and (c.refresh_lease_until is null or c.refresh_lease_until < now()
          or c.refresh_lease_holder = p_holder)
  returning c.id into v_claimed;
  return v_claimed is not null;
end;
$fn$;
revoke execute on function public.claim_accounting_refresh_lease(uuid, text, integer)
  from public, anon, authenticated;
grant execute on function public.claim_accounting_refresh_lease(uuid, text, integer) to service_role;

-- Gives the lease back; a holder that no longer holds it changes nothing.
create or replace function public.release_accounting_refresh_lease(
  p_connection_id uuid, p_holder text
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  update public.accounting_connections c
     set refresh_lease_holder = null, refresh_lease_until = null
   where c.id = p_connection_id and c.refresh_lease_holder = p_holder;
end;
$fn$;
revoke execute on function public.release_accounting_refresh_lease(uuid, text)
  from public, anon, authenticated;
grant execute on function public.release_accounting_refresh_lease(uuid, text) to service_role;

select public.set_deskilo_schema_version(648);
