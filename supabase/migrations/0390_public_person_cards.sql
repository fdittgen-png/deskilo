-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0390 -- #2211: the public profile is read from a projection, not through a
-- definer function. 0389 let `anon` execute `public_person`, a SECURITY
-- DEFINER function -- the one thing the schema guarantees forbid (no definer
-- function in public is executable by anon). Public data follows the house
-- pattern of `public_workspace_cards` (0305): a table holding exactly what
-- is public, readable by anyone, written only by the server.
--
-- `public_person_cards` holds one row per PUBLISHED person: the name, the
-- profession and the bio. Triggers keep it in step: publishing or
-- withdrawing (account_public_profiles), renaming (profiles.display_name)
-- and editing the about text (account_about). No row = not public; the
-- reader cannot tell unknown from unpublished from withdrawn.

create table public.public_person_cards (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  profession text not null default '',
  bio text not null default ''
);
select public.ensure_system_columns('public_person_cards');
alter table public.public_person_cards enable row level security;
revoke all on public.public_person_cards from public, anon, authenticated;
grant select (user_id, name, profession, bio) on public.public_person_cards to anon, authenticated;
create policy published_people on public.public_person_cards
  for select to anon, authenticated using (true);
create policy mcp_delegated_deny on public.public_person_cards as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- Brings [p_user]'s card in line with what they published.
create or replace function public.refresh_public_person_card(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user is null then return; end if;
  if exists (select 1 from public.account_public_profiles where user_id = p_user) then
    insert into public.public_person_cards (user_id, name, profession, bio)
    select p_user, coalesce(p.display_name, ''), coalesce(a.profession, ''), coalesce(a.bio, '')
      from public.profiles p
      left join public.account_about a on a.user_id = p.id
     where p.id = p_user
    on conflict (user_id) do update
      set name = excluded.name, profession = excluded.profession, bio = excluded.bio;
  else
    delete from public.public_person_cards where user_id = p_user;
  end if;
end;
$$;
revoke execute on function public.refresh_public_person_card(uuid) from public, anon, authenticated;

create or replace function public.public_person_card_sync()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'profiles' then
    perform public.refresh_public_person_card(coalesce(new.id, old.id));
  else
    perform public.refresh_public_person_card(coalesce(new.user_id, old.user_id));
  end if;
  return null;
end;
$$;
revoke execute on function public.public_person_card_sync() from public, anon, authenticated;

create trigger public_person_card_on_publish
  after insert or delete on public.account_public_profiles
  for each row execute function public.public_person_card_sync();
create trigger public_person_card_on_about
  after insert or update or delete on public.account_about
  for each row execute function public.public_person_card_sync();
create trigger public_person_card_on_name
  after update of display_name on public.profiles
  for each row execute function public.public_person_card_sync();

-- Whoever published before this migration has a card.
select public.refresh_public_person_card(user_id) from public.account_public_profiles;

-- The definer reader goes: the card is the public door.
drop function public.public_person(uuid);

-- The subject-access export carries my card.
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0390: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'public_person_cards', (select coalesce(jsonb_agg(to_jsonb(k)), '[]'::jsonb) from public.public_person_cards k where k.user_id = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(390);
