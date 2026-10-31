-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (a new unpublished table, filled from profiles.last_seen_at; the heartbeat
-- and the projections move to it; profiles.last_seen_at stays, unwritten,
-- for apps that still read it -- its drop is a later contract step)
--
-- 0616 (#3123, PERF-5 of the performance audit) -- the presence heartbeat
-- stops writing the published profiles table. touch_last_seen updated
-- profiles every two minutes per online person; profiles is published
-- and bound unfiltered, so Realtime checked RLS once per subscriber per
-- beat, and every client refetched the directory's profiles: O(online^2).
-- The heartbeat now writes public.presence, which is NOT published; the
-- two projections read it, and the app refreshes presence on its own
-- schedule (once per heartbeat interval, while in front).

create table public.presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_seen_at timestamptz not null default now()
);
select public.ensure_system_columns('presence');

alter table public.presence enable row level security;
-- Read only through the definer projections; written only by touch_last_seen.
revoke all on public.presence from anon, authenticated;
create policy mcp_delegated_deny on public.presence as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy personal_native_session on public.presence as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

insert into public.presence (user_id, last_seen_at)
select p.id, p.last_seen_at
  from public.profiles p
 where p.last_seen_at is not null
   and exists (select 1 from auth.users u where u.id = p.id)
on conflict (user_id) do nothing;

-- The subject-access exports keep returning the heartbeat: both read the
-- presence row beside the profile (anchored on the profile line).
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  -- An anchor names one place: it occurs exactly once, or nothing is patched.
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
begin
  select pg_get_functiondef('public.export_my_data(uuid)'::regprocedure) into v_def;
  v_patched := pg_temp.anchor_replace(v_def,
    $a$'profile', (select to_jsonb(p) - 'pin_hash' from public.profiles p where p.id = v_me.user_id),$a$,
    $a$'profile', (select to_jsonb(p) - 'pin_hash' from public.profiles p where p.id = v_me.user_id),
    'presence', (select to_jsonb(pr) from public.presence pr where pr.user_id = v_me.user_id),$a$);
  if v_patched is null then
    raise exception '0616: export_my_data profile anchor missing';
  end if;
  execute v_patched;

  select pg_get_functiondef('public.export_my_personal_data_v1()'::regprocedure) into v_def;
  v_patched := pg_temp.anchor_replace(v_def,
    $a$'profile', (select to_jsonb(p) - 'pin_hash' from public.profiles p where p.id = v_me),$a$,
    $a$'profile', (select to_jsonb(p) - 'pin_hash' from public.profiles p where p.id = v_me),
    'presence', (select to_jsonb(pr) from public.presence pr where pr.user_id = v_me),$a$);
  if v_patched is null then
    raise exception '0616: export_my_personal_data_v1 profile anchor missing';
  end if;
  execute v_patched;
end
$migration$;

create or replace function public.touch_last_seen()
returns void language sql security definer set search_path = public as $fn$
  insert into public.presence (user_id, last_seen_at)
  values (auth.uid(), now())
  on conflict (user_id) do update set last_seen_at = excluded.last_seen_at;
$fn$;
revoke execute on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated;

create or replace function public.account_projection(p_user uuid, p_fields text[])
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('user_id', p_user)
    || case when 'identity' = any(p_fields) then jsonb_build_object('identity',
         jsonb_build_object('name', coalesce(p.display_name, ''),
                            'avatar_path', p.avatar_path)) else '{}'::jsonb end
    || case when 'about' = any(p_fields) then jsonb_build_object('about',
         jsonb_build_object('profession', coalesce(a.profession, ''),
                            'bio', coalesce(a.bio, ''))) else '{}'::jsonb end
    || case when 'contact_channels' = any(p_fields) then jsonb_build_object('contact_channels',
         jsonb_build_object('whatsapp', coalesce(p.whatsapp, ''),
                            'email', coalesce(p.email, ''))) else '{}'::jsonb end
    || case when 'presence' = any(p_fields) then jsonb_build_object('presence',
         jsonb_build_object('last_seen_at', pr.last_seen_at,
                            'status_text', coalesce(p.status_text, ''))) else '{}'::jsonb end
  from (select 1) one
  left join public.profiles p on p.id = p_user
  left join public.account_about a on a.user_id = p_user
  left join public.presence pr on pr.user_id = p_user;
$fn$;
revoke execute on function public.account_projection(uuid, text[]) from public, anon, authenticated;

create or replace function public.member_profile_projection(p_subject uuid, p_purposes text[])
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('id', p.id, 'purposes', to_jsonb(p_purposes))
    || case when 'community' = any(p_purposes) then jsonb_build_object('community',
         jsonb_build_object(
           'display_name', coalesce(p.display_name, ''),
           'avatar_path', p.avatar_path,
           'whatsapp', coalesce(p.whatsapp, ''),
           'status_text', coalesce(p.status_text, ''),
           'last_seen_at', pr.last_seen_at)) else '{}'::jsonb end
    || case when 'operational' = any(p_purposes) then jsonb_build_object('operational',
         jsonb_build_object(
           'courtesy', coalesce(p.courtesy, ''),
           'first_name', coalesce(p.first_name, ''),
           'last_name', coalesce(p.last_name, ''),
           'company', coalesce(p.company, ''),
           'street', coalesce(p.street, ''),
           'postal_code', coalesce(p.postal_code, ''),
           'city', coalesce(p.city, ''),
           'country_code', coalesce(p.country_code, ''),
           'phone', coalesce(p.phone, ''),
           'email', coalesce(p.email, ''),
           'vat_id', coalesce(p.vat_id, ''),
           'legal_id', coalesce(p.legal_id, ''),
           'address', coalesce(p.address, ''),
           'preferred_locale', coalesce(p.preferred_locale, ''))) else '{}'::jsonb end
  from public.profiles p
  left join public.presence pr on pr.user_id = p.id
  where p.id = p_subject;
$fn$;
revoke execute on function public.member_profile_projection(uuid, text[]) from public, anon, authenticated;


select public.set_deskilo_schema_version(616);
