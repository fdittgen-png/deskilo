-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0226 (#1312) — the schema says which version it is, and the SQL itself
-- says so.
--
-- Until now "how current is this instance" was answered by COUNTING rows
-- of `supabase_migrations.schema_migrations` against a floor of 200. That
-- count means nothing on either kind of project:
--
--   * the dev project records 227 rows for 225 files, with timestamp
--     versions (`20260916194931 member_statement_reads_reservations`) and
--     names that are not the file names — and 0224 was applied without
--     being recorded at all;
--   * an instance built before #1314 recorded nothing, so it counted 0.
--
-- Only one signal is true however the SQL arrived — the CLI, the MCP
-- `apply_migration`, the new-instance wizard, a `psql` restore: a value
-- the migration writes about itself, in its own transaction. If the
-- migration rolls back, so does its marker.
--
-- ## The contract
--
--   * `public.deskilo_schema_version` — one row, forced by
--     `id boolean primary key check (id)`.
--   * `public.deskilo_schema_version()` answers it. SECURITY INVOKER on
--     purpose: the doctor alarms on anon-callable definers, and a
--     version is not a secret — the app asks it before anybody signs in.
--   * `public.set_deskilo_schema_version(n)` is for migrations only;
--     nobody but the migration role may execute it. It never lowers the
--     marker, so re-running an old file by hand cannot make an instance
--     look older than it is.
--   * **Every migration after this one ends with
--     `select public.set_deskilo_schema_version(NNNN);`** carrying its own
--     number. `test/lint/migration_version_marker_test.dart` refuses one
--     that does not, and — with the same lint — a second line,
--     `-- risk: additive | transforming | destructive`, under the licence.
--
-- The app compares the marker with the highest migration its bundle
-- carries: lower means the server needs an update, higher is supported
-- (OPERATIONS.md § Version compatibility).

create table if not exists public.deskilo_schema_version (
  id boolean primary key default true check (id),
  version int not null check (version > 0),
  updated_at timestamptz not null default now()
);

select public.ensure_system_columns('deskilo_schema_version');

alter table public.deskilo_schema_version enable row level security;

drop policy if exists deskilo_schema_version_read on public.deskilo_schema_version;
create policy deskilo_schema_version_read on public.deskilo_schema_version
  for select to anon, authenticated using (true);

revoke all on public.deskilo_schema_version from public, anon, authenticated;
grant select on public.deskilo_schema_version to anon, authenticated;

create or replace function public.deskilo_schema_version()
returns int
language sql
stable
security invoker
set search_path = public
as $$
  select version from public.deskilo_schema_version where id;
$$;

revoke execute on function public.deskilo_schema_version() from public, anon, authenticated;
grant execute on function public.deskilo_schema_version() to anon, authenticated;

create or replace function public.set_deskilo_schema_version(p_version int)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_version is null or p_version <= 0 then
    raise exception 'schema version must be a positive migration number, got %', p_version;
  end if;
  insert into public.deskilo_schema_version (id, version, updated_at)
  values (true, p_version, now())
  on conflict (id) do update
    set version = greatest(public.deskilo_schema_version.version, excluded.version),
        updated_at = case
          when excluded.version > public.deskilo_schema_version.version then now()
          else public.deskilo_schema_version.updated_at
        end;
end;
$$;

revoke execute on function public.set_deskilo_schema_version(int) from public, anon, authenticated;

select public.set_deskilo_schema_version(226);
