-- SPDX-License-Identifier: 0BSD
-- 0184 — #992: the system columns are the core's — owned, never forged.
--
-- 0183 added the six and stamped what was missing. This makes them the
-- server's alone: on INSERT the creation stamp is always now() and the
-- caller, whatever the row said; on UPDATE the creation stamp is kept
-- from the stored row and the modification stamp is always now() and
-- the caller; company_id and site_id are always recomputed from the
-- row's own keys. Two constraints state the invariants: a row is never
-- modified before it was created, and a row that belongs to a workspace
-- always says which one. A client value for any of the six is ignored.

create or replace function public.system_columns_stamp()
returns trigger language plpgsql as $fn$
declare
  j jsonb := to_jsonb(new);
  patch jsonb := '{}'::jsonb;
begin
  if tg_op = 'INSERT' then
    patch := patch || jsonb_build_object(
      'created_datetime', now(), 'created_by_user', auth.uid());
  else
    -- The creation stamp never moves.
    patch := patch || jsonb_build_object(
      'created_datetime', old.created_datetime,
      'created_by_user', old.created_by_user);
  end if;
  patch := patch || jsonb_build_object(
    'modified_datetime', now(), 'modified_by_user', auth.uid());
  if tg_table_name = 'workspaces' then
    patch := patch || jsonb_build_object('company_id', j->'id');
  elsif j ? 'workspace_id' then
    patch := patch || jsonb_build_object('company_id', j->'workspace_id');
  end if;
  if tg_table_name = 'sites' then
    patch := patch || jsonb_build_object('site_id', j->'id');
  elsif tg_table_name = 'members' then
    patch := patch || jsonb_build_object('site_id', j->'home_site_id');
  elsif j ? 'level_id' then
    patch := patch || jsonb_build_object('site_id',
      (select l.site_id from public.levels l where l.id = (j->>'level_id')::uuid));
  end if;
  new := jsonb_populate_record(new, patch);
  return new;
end;
$fn$;

-- The helper now states the invariants too, and its backfill only
-- touches rows the default stamped later than their true creation.
create or replace function public.ensure_system_columns(p_table text)
returns void language plpgsql as $fn$
declare
  has_created_at boolean;
  has_workspace boolean;
  has_level boolean;
begin
  execute format('alter table public.%I add column if not exists created_datetime timestamptz not null default now()', p_table);
  execute format('alter table public.%I add column if not exists modified_datetime timestamptz not null default now()', p_table);
  execute format('alter table public.%I add column if not exists company_id uuid', p_table);
  execute format('alter table public.%I add column if not exists site_id uuid', p_table);
  execute format('alter table public.%I add column if not exists created_by_user uuid', p_table);
  execute format('alter table public.%I add column if not exists modified_by_user uuid', p_table);
  select exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = p_table and column_name = 'created_at'),
         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = p_table and column_name = 'workspace_id'),
         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = p_table and column_name = 'level_id')
    into has_created_at, has_workspace, has_level;
  execute format('alter table public.%I disable trigger user', p_table);
  if has_created_at then
    execute format('update public.%I set created_datetime = created_at, modified_datetime = created_at where created_at is not null and created_datetime > created_at', p_table);
  end if;
  if p_table = 'workspaces' then
    execute 'update public.workspaces set company_id = id where company_id is distinct from id';
  elsif has_workspace then
    execute format('update public.%I set company_id = workspace_id where company_id is distinct from workspace_id', p_table);
  end if;
  if p_table = 'sites' then
    execute 'update public.sites set site_id = id where site_id is distinct from id';
  elsif p_table = 'members' then
    execute 'update public.members set site_id = home_site_id where site_id is distinct from home_site_id';
  elsif has_level then
    execute format('update public.%I t set site_id = l.site_id from public.levels l where l.id = t.level_id and t.site_id is distinct from l.site_id', p_table);
  end if;
  execute format('alter table public.%I enable trigger user', p_table);
  execute format('drop trigger if exists zz_system_columns_stamp on public.%I', p_table);
  execute format('create trigger zz_system_columns_stamp before insert or update on public.%I for each row execute function public.system_columns_stamp()', p_table);
  -- The invariants.
  execute format('alter table public.%I drop constraint if exists system_columns_order', p_table);
  execute format('alter table public.%I add constraint system_columns_order check (modified_datetime >= created_datetime)', p_table);
  execute format('alter table public.%I drop constraint if exists system_company_present', p_table);
  if has_workspace or p_table = 'workspaces' then
    execute format('alter table public.%I add constraint system_company_present check (company_id is not null)', p_table);
  end if;
end;
$fn$;
revoke execute on function public.ensure_system_columns(text) from public, anon, authenticated;

do $all$
declare t record;
begin
  for t in select table_name from information_schema.tables
            where table_schema = 'public' and table_type = 'BASE TABLE'
            order by table_name loop
    perform public.ensure_system_columns(t.table_name);
  end loop;
end;
$all$;
