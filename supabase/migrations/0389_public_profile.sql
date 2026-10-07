-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0389 -- #2211: the public-profile tier. A signed-out visitor sees NOTHING of
-- a person (MESSENGER_VISIBILITY.md §2) unless the person publishes a public
-- profile on purpose. The publish step is one switch, `set_public_profile`;
-- what a published profile shows is fixed here and cannot be widened by
-- configuration: the name, the profession and the bio. Never the photo, the
-- contact channels, the presence, the spaces or the way to write to the person
-- -- those stay behind the audiences of 0315. Unpublishing removes the row, and
-- the page answers "profile unavailable" at once.
--
-- The only anonymous door is `public_person(user)`: it returns the three
-- fields of a published profile, or the same refusal for an unknown, an
-- unpublished and a withdrawn one, so nothing says which it was.

create table public.account_public_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  published_at timestamptz not null default now()
);
select public.ensure_system_columns('account_public_profiles');
alter table public.account_public_profiles enable row level security;
revoke all on public.account_public_profiles from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_public_profiles as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- Is my public profile published?
create or replace function public.my_public_profile()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return jsonb_build_object('published', exists (
    select 1 from public.account_public_profiles where user_id = auth.uid()));
end;
$$;
revoke execute on function public.my_public_profile() from public, anon;
grant execute on function public.my_public_profile() to authenticated;

-- Publish (true) or withdraw (false) my public profile.
create or replace function public.set_public_profile(p_publish boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_publish is null then raise exception 'invalid choice'; end if;
  if p_publish then
    insert into public.account_public_profiles (user_id) values (auth.uid())
    on conflict do nothing;
  else
    delete from public.account_public_profiles where user_id = auth.uid();
  end if;
end;
$$;
revoke execute on function public.set_public_profile(boolean) from public, anon;
grant execute on function public.set_public_profile(boolean) to authenticated;

-- What a visitor reads: the three published fields, for anyone, signed in or not.
create or replace function public.public_person(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  select jsonb_build_object(
           'name', coalesce(p.display_name, ''),
           'profession', coalesce(a.profession, ''),
           'bio', coalesce(a.bio, ''))
    into v
    from public.account_public_profiles pp
    join public.profiles p on p.id = pp.user_id
    left join public.account_about a on a.user_id = pp.user_id
   where pp.user_id = p_user;
  if v is null then raise exception 'profile unavailable'; end if;
  return v;
end;
$$;
revoke execute on function public.public_person(uuid) from public;
grant execute on function public.public_person(uuid) to anon, authenticated;

-- The subject-access export carries my publication.
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0389: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'account_public_profiles', (select coalesce(jsonb_agg(to_jsonb(k)), '[]'::jsonb) from public.account_public_profiles k where k.user_id = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(389);
