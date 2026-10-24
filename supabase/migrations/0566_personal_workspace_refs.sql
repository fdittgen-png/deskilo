-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- Transforming: adds a network reference beside three existing workspace
-- pointers and backfills it from the workspace's own birth record (0559);
-- the primary keys of workspace_favorites and
-- account_field_audience_spaces move from the local workspace id to that
-- reference, and their local workspace id becomes optional. No row is
-- deleted, no existing value changes, and the user triggers of the three
-- tables are stood down for the backfill so the modification stamps do
-- not move. Re-running the backfill writes nothing (it fills nulls only).
--
-- 0566 (#2563 C1) -- the personal account names a workspace by its
-- qualified reference, so it can live on a personal home (P) that hosts no
-- workspace.
--
-- A personal home keeps three pointers to workspaces: the default one
-- (`profiles`, 0090), the spaces a chosen audience is limited to
-- (`account_field_audience_spaces`, 0315) and the favourites
-- (`workspace_favorites`, 0376). Each held a local `workspace_id` with a
-- foreign key into `workspaces` -- a row a personal home does not have.
-- Each now also carries the workspace's network id
-- (`<installation id>:<local id>`, #2561), the one name that stays
-- distinct when two installations hold the same local UUID:
--
--   * written by the server: a row that names a LOCAL workspace by its id
--     gets that workspace's stored network id (a client value is
--     replaced, as 0559 replaces it on the workspace itself);
--   * a reference that names a workspace of THIS installation by network
--     id is mapped to the local id, and refused when no such workspace
--     exists -- an unknown local reference is never guessed;
--   * a reference to another installation keeps no local id: a foreign
--     UUID is never read as a local one.
--
-- The legacy UUID interfaces stay as they are on a combined installation
-- (`set_visibility(text, text, uuid[])`, `set_workspace_favorite`,
-- `profiles.default_workspace_id`): their rows get the reference through
-- the same stamp. Nothing here widens an audience or decides access --
-- the evaluator of 0315/0387 is unchanged, and a reference to another
-- installation matches no local membership, so it authorizes nothing
-- until #2563 C2's verified relationship facts exist.
--
-- Three readers, for the caller only, first-party sessions only:
--   my_personal_workspace_refs_v1()  the workspaces I am related to or
--       saved, with the relationship status as the installation knows it,
--       how fresh that knowledge is, and a label only where I may read
--       one -- never a role or a permission;
--   my_visibility_network_v1()       my_visibility with the chosen spaces
--       named by network id, and the home that holds the choices;
--   export_my_personal_data_v1()     the account part of export_my_data,
--       with no workspace: it runs on a personal home.

-- ── the shape of a reference ─────────────────────────────────────────
create or replace function public.workspace_network_ref_valid(p_ref text)
returns boolean language sql immutable set search_path = public as $fn$
  select p_ref ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
$fn$;
revoke execute on function public.workspace_network_ref_valid(text) from public, anon, authenticated;

-- The local workspace a reference names, or null when it names another
-- installation. A reference to THIS installation without a workspace is
-- refused: the caller named something that does not exist here.
create or replace function public.local_workspace_of_ref(p_ref text)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare v_id uuid;
begin
  if p_ref is null then return null; end if;
  if not public.workspace_network_ref_valid(p_ref) then
    raise exception 'malformed workspace reference' using errcode = '22023';
  end if;
  if split_part(p_ref, ':', 1) <> public.installation_id()::text then
    return null;
  end if;
  select w.id into v_id from public.workspaces w where w.network_id = p_ref;
  if v_id is null then
    raise exception 'unknown workspace reference' using errcode = '22023';
  end if;
  return v_id;
end;
$fn$;
revoke execute on function public.local_workspace_of_ref(text) from public, anon, authenticated;

-- The server writes the reference of a saved row: a local workspace id
-- gives its stored network id; a reference alone is mapped to the local
-- id when it names this installation, and keeps none when it does not.
create or replace function public.personal_workspace_ref_stamp()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.workspace_id is not null then
    select w.network_id into new.workspace_network_id
      from public.workspaces w where w.id = new.workspace_id;
  else
    new.workspace_id := public.local_workspace_of_ref(new.workspace_network_id);
  end if;
  return new;
end;
$fn$;
revoke execute on function public.personal_workspace_ref_stamp() from public, anon, authenticated;

-- ── the chosen spaces of an audience ─────────────────────────────────
alter table public.account_field_audience_spaces
  add column if not exists workspace_network_id text;
alter table public.account_field_audience_spaces disable trigger user;
update public.account_field_audience_spaces s
   set workspace_network_id = w.network_id
  from public.workspaces w
 where w.id = s.workspace_id and s.workspace_network_id is null;
alter table public.account_field_audience_spaces enable trigger user;
alter table public.account_field_audience_spaces
  alter column workspace_network_id set not null;
alter table public.account_field_audience_spaces
  drop constraint if exists account_field_audience_spaces_ref_shape;
alter table public.account_field_audience_spaces
  add constraint account_field_audience_spaces_ref_shape
  check (workspace_network_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
alter table public.account_field_audience_spaces
  drop constraint if exists account_field_audience_spaces_pkey;
alter table public.account_field_audience_spaces
  add constraint account_field_audience_spaces_pkey
  primary key (user_id, field, workspace_network_id);
alter table public.account_field_audience_spaces
  alter column workspace_id drop not null;
-- A reference to another installation belongs to no workspace here, so it
-- has no company (0428's precedent for a platform row): the invariant now
-- binds the rows that do name a local workspace.
alter table public.account_field_audience_spaces drop constraint if exists system_company_present;
alter table public.account_field_audience_spaces add constraint system_company_present
  check (workspace_id is null or company_id is not null);
alter table public.account_field_audience_spaces
  drop constraint if exists account_field_audience_spaces_local_key;
alter table public.account_field_audience_spaces
  add constraint account_field_audience_spaces_local_key
  unique (user_id, field, workspace_id);
comment on column public.account_field_audience_spaces.workspace_network_id is
  '#2563 -- the chosen space by its network id (installation id : local id); '
  'workspace_id is set only when that space is hosted here.';
drop trigger if exists personal_workspace_ref_stamp on public.account_field_audience_spaces;
create trigger personal_workspace_ref_stamp
  before insert or update of workspace_id, workspace_network_id
  on public.account_field_audience_spaces
  for each row execute function public.personal_workspace_ref_stamp();

-- ── the favourites ───────────────────────────────────────────────────
alter table public.workspace_favorites
  add column if not exists workspace_network_id text;
alter table public.workspace_favorites disable trigger user;
update public.workspace_favorites f
   set workspace_network_id = w.network_id
  from public.workspaces w
 where w.id = f.workspace_id and f.workspace_network_id is null;
alter table public.workspace_favorites enable trigger user;
alter table public.workspace_favorites
  alter column workspace_network_id set not null;
alter table public.workspace_favorites
  drop constraint if exists workspace_favorites_ref_shape;
alter table public.workspace_favorites
  add constraint workspace_favorites_ref_shape
  check (workspace_network_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
alter table public.workspace_favorites
  drop constraint if exists workspace_favorites_pkey;
alter table public.workspace_favorites
  add constraint workspace_favorites_pkey primary key (user_id, workspace_network_id);
alter table public.workspace_favorites
  alter column workspace_id drop not null;
-- A reference to another installation belongs to no workspace here, so it
-- has no company (0428's precedent for a platform row): the invariant now
-- binds the rows that do name a local workspace.
alter table public.workspace_favorites drop constraint if exists system_company_present;
alter table public.workspace_favorites add constraint system_company_present
  check (workspace_id is null or company_id is not null);
-- set_workspace_favorite's `on conflict (user_id, workspace_id)` keeps
-- its arbiter.
alter table public.workspace_favorites
  drop constraint if exists workspace_favorites_local_key;
alter table public.workspace_favorites
  add constraint workspace_favorites_local_key unique (user_id, workspace_id);
comment on column public.workspace_favorites.workspace_network_id is
  '#2563 -- the favourite by its network id (installation id : local id); '
  'workspace_id is set only when that space is hosted here.';
drop trigger if exists personal_workspace_ref_stamp on public.workspace_favorites;
create trigger personal_workspace_ref_stamp
  before insert or update of workspace_id, workspace_network_id
  on public.workspace_favorites
  for each row execute function public.personal_workspace_ref_stamp();

-- ── the default workspace ────────────────────────────────────────────
-- A preference, never an access decision (pgTAP 264): nothing authorizes
-- by it. The legacy column keeps working; whichever of the two a writer
-- changes, the server derives the other.
alter table public.profiles
  add column if not exists default_workspace_network_id text;
alter table public.profiles disable trigger user;
update public.profiles p
   set default_workspace_network_id = w.network_id
  from public.workspaces w
 where w.id = p.default_workspace_id and p.default_workspace_network_id is null;
alter table public.profiles enable trigger user;
alter table public.profiles
  drop constraint if exists profiles_default_workspace_ref_shape;
alter table public.profiles
  add constraint profiles_default_workspace_ref_shape
  check (default_workspace_network_id is null
         or default_workspace_network_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
comment on column public.profiles.default_workspace_network_id is
  '#2563 -- the default workspace by its network id; default_workspace_id '
  'is set only when that space is hosted here.';

create or replace function public.profiles_default_workspace_ref()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if tg_op = 'UPDATE'
     and new.default_workspace_id is not distinct from old.default_workspace_id
     and new.default_workspace_network_id is not distinct from old.default_workspace_network_id then
    return new;
  end if;
  if new.default_workspace_id is not null
     and (tg_op = 'INSERT' or new.default_workspace_id is distinct from old.default_workspace_id) then
    select w.network_id into new.default_workspace_network_id
      from public.workspaces w where w.id = new.default_workspace_id;
  elsif tg_op = 'INSERT'
     or new.default_workspace_network_id is distinct from old.default_workspace_network_id then
    new.default_workspace_id := public.local_workspace_of_ref(new.default_workspace_network_id);
  else
    -- The local id was cleared (by its writer or by the workspace's
    -- deletion): the reference it stood for goes with it.
    new.default_workspace_network_id := null;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.profiles_default_workspace_ref() from public, anon, authenticated;
drop trigger if exists profiles_default_workspace_ref on public.profiles;
create trigger profiles_default_workspace_ref
  before insert or update of default_workspace_id, default_workspace_network_id
  on public.profiles
  for each row execute function public.profiles_default_workspace_ref();

-- ── my_visibility lists local spaces only ────────────────────────────
-- 0315's reader, restated whole: its `workspaces` are local ids, so a
-- choice of a space on another installation (no local id) is not listed
-- there; my_visibility_network_v1 lists every choice by reference.
create or replace function public.my_visibility()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'fields', (select jsonb_object_agg(f, jsonb_build_object(
                 'audience', public.account_audience_of(v_me, f),
                 'workspaces', coalesce((select jsonb_agg(s.workspace_id order by s.workspace_id)
                                           from public.account_field_audience_spaces s
                                          where s.user_id = v_me and s.field = f
                                            and s.workspace_id is not null), '[]'::jsonb)))
                 from unnest(array['identity', 'about', 'contact_channels', 'presence']) f),
    'reachability', jsonb_build_object(
                 'audience', public.account_audience_of(v_me, 'reachability'),
                 'workspaces', coalesce((select jsonb_agg(s.workspace_id order by s.workspace_id)
                                           from public.account_field_audience_spaces s
                                          where s.user_id = v_me and s.field = 'reachability'
                                            and s.workspace_id is not null), '[]'::jsonb)),
    'about', coalesce((select jsonb_build_object('profession', a.profession, 'bio', a.bio)
                         from public.account_about a where a.user_id = v_me),
                      jsonb_build_object('profession', '', 'bio', '')));
end;
$$;
revoke execute on function public.my_visibility() from public, anon;
grant execute on function public.my_visibility() to authenticated;

-- ── the readers ──────────────────────────────────────────────────────
-- The home that answers: this installation and its roles (0559).
create or replace function public.personal_home_descriptor()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('installation_id', i.installation_id, 'roles', to_jsonb(i.roles))
    from public.installation_identity i;
$fn$;
revoke execute on function public.personal_home_descriptor() from public, anon, authenticated;

-- Every workspace I am related to here or saved a reference to. A
-- relationship is read from this installation's own membership row
-- (`freshness` = local, its status verbatim); a reference to another
-- installation has no verified relationship yet (`freshness` =
-- unavailable, no status) -- #2563 C2 brings the facts. The label is the
-- workspace's name only where I may read it here (a member, or a listed
-- space); never a role, a permission or another person.
create or replace function public.my_personal_workspace_refs_v1()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid := auth.uid();
  v_home text := public.installation_id()::text;
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'home', public.personal_home_descriptor(),
    'refs', coalesce((
      select jsonb_agg(jsonb_build_object(
               'network_id', x.ref,
               'installation_id', split_part(x.ref, ':', 1),
               'workspace_id', split_part(x.ref, ':', 2),
               'hosted_here', split_part(x.ref, ':', 1) = v_home,
               'label', case when m.status is not null or w.visibility_set_at is not null
                             then w.name end,
               'status', m.status,
               'freshness', case when split_part(x.ref, ':', 1) = v_home
                                 then 'local' else 'unavailable' end,
               'is_default', x.ref = (select p.default_workspace_network_id
                                        from public.profiles p where p.id = v_me),
               'is_favorite', exists (select 1 from public.workspace_favorites f
                                       where f.user_id = v_me and f.workspace_network_id = x.ref),
               'audience_fields', coalesce((select jsonb_agg(s.field order by s.field)
                                              from public.account_field_audience_spaces s
                                             where s.user_id = v_me
                                               and s.workspace_network_id = x.ref), '[]'::jsonb))
             order by x.ref)
        from (select w0.network_id as ref
                from public.members m0 join public.workspaces w0 on w0.id = m0.workspace_id
               where m0.user_id = v_me
              union
              select f.workspace_network_id from public.workspace_favorites f where f.user_id = v_me
              union
              select s.workspace_network_id from public.account_field_audience_spaces s where s.user_id = v_me
              union
              select p.default_workspace_network_id from public.profiles p
               where p.id = v_me and p.default_workspace_network_id is not null) x
        left join public.workspaces w on w.network_id = x.ref
        left join lateral (select m1.status from public.members m1
                            where m1.workspace_id = w.id and m1.user_id = v_me
                            order by case m1.status when 'active' then 0 when 'paused' then 1
                                                    when 'pending' then 2 else 3 end
                            limit 1) m on true), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.my_personal_workspace_refs_v1() from public, anon;
grant execute on function public.my_personal_workspace_refs_v1() to authenticated;

-- my_visibility with the chosen spaces named by network id. The audience
-- words are 0315's, read by the same account_audience_of: one evaluator.
create or replace function public.my_visibility_network_v1()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare v_me uuid := auth.uid();
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'home', public.personal_home_descriptor(),
    'fields', (select jsonb_object_agg(f, jsonb_build_object(
                 'audience', public.account_audience_of(v_me, f),
                 'workspace_refs', coalesce((select jsonb_agg(s.workspace_network_id order by s.workspace_network_id)
                                               from public.account_field_audience_spaces s
                                              where s.user_id = v_me and s.field = f), '[]'::jsonb)))
                 from unnest(array['identity', 'about', 'contact_channels', 'presence']) f),
    'reachability', jsonb_build_object(
                 'audience', public.account_audience_of(v_me, 'reachability'),
                 'workspace_refs', coalesce((select jsonb_agg(s.workspace_network_id order by s.workspace_network_id)
                                               from public.account_field_audience_spaces s
                                              where s.user_id = v_me and s.field = 'reachability'), '[]'::jsonb)),
    'about', coalesce((select jsonb_build_object('profession', a.profession, 'bio', a.bio)
                         from public.account_about a where a.user_id = v_me),
                      jsonb_build_object('profession', '', 'bio', '')));
end;
$fn$;
revoke execute on function public.my_visibility_network_v1() from public, anon;
grant execute on function public.my_visibility_network_v1() to authenticated;

-- The account part of export_my_data, with no workspace: what this
-- installation holds about me as a person. Each workspace exports its own
-- records (export_my_data(workspace) on the installation that hosts it).
-- Other people appear only where they are part of my own record (the
-- other side of my conversation); no relationship of anyone else.
create or replace function public.export_my_personal_data_v1()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare v_me uuid := auth.uid();
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'format', 'deskilo.personal-export',
    'version', 1,
    'exported_at', now(),
    'home', public.personal_home_descriptor(),
    'profile', (select to_jsonb(p) - 'pin_hash' from public.profiles p where p.id = v_me),
    'personal_preferences', (select d.preferences from public.directory_people d
                               join public.profiles p on p.person_id = d.id where p.id = v_me),
    'account_about', (select to_jsonb(a) from public.account_about a where a.user_id = v_me),
    'account_contact_settings', (select to_jsonb(s) from public.account_contact_settings s where s.user_id = v_me),
    'account_field_audience', (select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb)
                                 from public.account_field_audience a where a.user_id = v_me),
    'account_field_audience_spaces', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
                                        from public.account_field_audience_spaces s where s.user_id = v_me),
    'account_public_profiles', (select coalesce(jsonb_agg(to_jsonb(k)), '[]'::jsonb)
                                  from public.account_public_profiles k where k.user_id = v_me),
    'public_person_cards', (select coalesce(jsonb_agg(to_jsonb(k)), '[]'::jsonb)
                              from public.public_person_cards k where k.user_id = v_me),
    'account_blocks', (select coalesce(jsonb_agg(to_jsonb(k)), '[]'::jsonb)
                         from public.account_blocks k where k.blocker = v_me),
    'account_conversations', (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
                                from public.account_conversations c where v_me in (c.user_a, c.user_b)),
    'account_messages', (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
                           from public.account_messages m
                           join public.account_conversations c on c.id = m.conversation_id
                          where v_me in (c.user_a, c.user_b)),
    'account_group_members', (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
                                from public.account_group_members m where m.user_id = v_me),
    'account_group_messages', (select coalesce(jsonb_agg(to_jsonb(g)), '[]'::jsonb)
                                 from public.account_group_messages g where g.author_id = v_me),
    'message_reactions', (select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
                            from public.message_reactions r where r.user_id = v_me),
    'message_stars', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
                        from public.message_stars s where s.user_id = v_me),
    'workspace_favorites', (select coalesce(jsonb_agg(jsonb_build_object(
                                 'workspace_network_id', f.workspace_network_id,
                                 'workspace_id', f.workspace_id,
                                 'created', f.created_datetime)), '[]'::jsonb)
                              from public.workspace_favorites f where f.user_id = v_me),
    'workspace_ratings', (select coalesce(jsonb_agg(jsonb_build_object(
                               'workspace_id', r.workspace_id, 'stars', r.stars,
                               'created', r.created_datetime)), '[]'::jsonb)
                            from public.workspace_ratings r where r.user_id = v_me),
    'public_directory_sources', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
                                   from public.public_directory_sources s where s.registered_by = v_me),
    'privacy_notice_acknowledgments', (select coalesce(jsonb_agg(jsonb_build_object(
                                            'version', pn.version, 'acknowledged_at', pa.acknowledged_at,
                                            'legacy', pa.legacy) order by pa.acknowledged_at), '[]'::jsonb)
                                         from public.privacy_notice_acknowledgments pa
                                         join public.privacy_notices pn on pn.id = pa.notice_id
                                        where pa.user_id = v_me and pn.space_id is null),
    'workspace_refs', public.my_personal_workspace_refs_v1() -> 'refs',
    'coverage', jsonb_build_object(
      'covers', 'your personal account on this installation, without any workspace',
      'not_covered', jsonb_build_array(
        jsonb_build_object('store', 'workspaces', 'note', 'each workspace exports its own records on the installation that hosts it'),
        jsonb_build_object('store', 'other_installations', 'note', 'a separate installation is a separate controller'),
        jsonb_build_object('store', 'device_caches', 'note', 'held on your own devices'),
        jsonb_build_object('store', 'operator_backups', 'note', 'restored only by the operator; ask the controller'))));
end;
$fn$;
revoke execute on function public.export_my_personal_data_v1() from public, anon;
grant execute on function public.export_my_personal_data_v1() to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(566);
