-- SPDX-License-Identifier: 0BSD
--
-- #751 — the GDPR consent, recorded on the ACCOUNT. Every signed-in
-- user passes the consent screen once; the accepted policy VERSION is
-- stored with a server-side timestamp, so the acceptance follows the
-- account across devices and reinstalls, and a change of the policy
-- text (a new version string in the app) asks again. Nothing else in
-- the app is reachable until the current version is accepted.

alter table public.profiles
  add column if not exists privacy_accepted_version text,
  add column if not exists privacy_accepted_at timestamptz;

create or replace function public.accept_privacy_policy(p_version text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if coalesce(trim(p_version), '') = '' then raise exception 'version required'; end if;
  update public.profiles
     set privacy_accepted_version = p_version,
         privacy_accepted_at = now()
   where id = auth.uid();
  if not found then
    insert into public.profiles (id, privacy_accepted_version, privacy_accepted_at)
    values (auth.uid(), p_version, now());
  end if;
end;
$$;
revoke execute on function public.accept_privacy_policy(text) from public, anon;
grant execute on function public.accept_privacy_policy(text) to authenticated;
