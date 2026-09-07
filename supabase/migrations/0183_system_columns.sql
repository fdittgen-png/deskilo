-- SPDX-License-Identifier: 0BSD
-- 0183 — #992: system columns on every table.
--
-- Six technical columns the core relies on, on every table of the public
-- schema, existing and future: created_datetime, modified_datetime,
-- company_id (the workspace), site_id, created_by_user, modified_by_user.
-- One trigger stamps them on every write; one helper adds them to a
-- table together with the trigger and the backfill. Every CREATE TABLE
-- from now on calls ensure_system_columns() in the same migration — a
-- lint pins it. Existing columns (created_at, workspace_id, created_by…)
-- stay: the six are additions, never replacements.

-- The six, as one list every guard can subtract.
create or replace function public.system_column_names()
returns text[] language sql immutable as $fn$
  select array['created_datetime', 'modified_datetime', 'company_id', 'site_id',
               'created_by_user', 'modified_by_user'];
$fn$;

create or replace function public.system_columns_stamp()
returns trigger language plpgsql as $fn$
declare
  j jsonb := to_jsonb(new);
  patch jsonb := '{}'::jsonb;
begin
  if tg_op = 'INSERT' then
    if j->>'created_datetime' is null then
      patch := patch || jsonb_build_object('created_datetime', now());
    end if;
    if j->>'created_by_user' is null then
      patch := patch || jsonb_build_object('created_by_user', auth.uid());
    end if;
  end if;
  patch := patch || jsonb_build_object('modified_datetime', now(), 'modified_by_user', auth.uid());
  if tg_table_name = 'workspaces' then
    patch := patch || jsonb_build_object('company_id', j->'id');
  elsif j ? 'workspace_id' and j->>'workspace_id' is not null then
    patch := patch || jsonb_build_object('company_id', j->'workspace_id');
  end if;
  if tg_table_name = 'sites' then
    patch := patch || jsonb_build_object('site_id', j->'id');
  elsif tg_table_name = 'members' and j->>'home_site_id' is not null then
    patch := patch || jsonb_build_object('site_id', j->'home_site_id');
  elsif j ? 'level_id' and j->>'level_id' is not null and j->>'site_id' is null then
    patch := patch || jsonb_build_object('site_id',
      (select l.site_id from public.levels l where l.id = (j->>'level_id')::uuid));
  end if;
  new := jsonb_populate_record(new, patch);
  return new;
end;
$fn$;

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
  -- The backfill runs with every user trigger silent: the guards
  -- (invoices are immutable) would refuse the columns they never knew,
  -- and no AFTER trigger queues an event that would block the ALTER
  -- TABLE below.
  execute format('alter table public.%I disable trigger user', p_table);
  if has_created_at then
    execute format('update public.%I set created_datetime = created_at, modified_datetime = created_at where created_at is not null', p_table);
  end if;
  if p_table = 'workspaces' then
    execute 'update public.workspaces set company_id = id where company_id is null';
  elsif has_workspace then
    execute format('update public.%I set company_id = workspace_id where company_id is null', p_table);
  end if;
  if p_table = 'sites' then
    execute 'update public.sites set site_id = id where site_id is null';
  elsif p_table = 'members' then
    execute 'update public.members set site_id = home_site_id where site_id is null and home_site_id is not null';
  elsif has_level then
    execute format('update public.%I t set site_id = l.site_id from public.levels l where l.id = t.level_id and t.site_id is null', p_table);
  end if;
  execute format('alter table public.%I enable trigger user', p_table);
  -- zz_: BEFORE triggers fire in name order; the stamp goes last, after
  -- every guard has judged the row.
  execute format('drop trigger if exists zz_system_columns_stamp on public.%I', p_table);
  execute format('create trigger zz_system_columns_stamp before insert or update on public.%I for each row execute function public.system_columns_stamp()', p_table);
end;
$fn$;
revoke execute on function public.ensure_system_columns(text) from public, anon, authenticated;

-- The invoice guard compares whole rows; the stamp must not count.
create or replace function public.invoices_immutable()
returns trigger language plpgsql as $fn$
declare
  o jsonb := to_jsonb(old) - public.system_column_names();
  n jsonb := to_jsonb(new) - public.system_column_names();
begin
  if tg_op = 'UPDATE'
     and old.voided_at is null
     and new.voided_at is not null
     and (o - 'voided_at' - 'voided_by_name') = (n - 'voided_at' - 'voided_by_name') then
    return new;
  end if;
  -- #804 — the settlement back-pointer, set once…
  if tg_op = 'UPDATE'
     and old.settled_by_invoice_id is null
     and new.settled_by_invoice_id is not null
     and (o - 'settled_by_invoice_id') = (n - 'settled_by_invoice_id') then
    return new;
  end if;
  -- #816 — …and cleared once, when the settlement did not stand.
  if tg_op = 'UPDATE'
     and old.settled_by_invoice_id is not null
     and new.settled_by_invoice_id is null
     and (o - 'settled_by_invoice_id') = (n - 'settled_by_invoice_id') then
    return new;
  end if;
  raise exception 'invoices are immutable';
end;
$fn$;

-- Every table of the public schema, existing today.
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
