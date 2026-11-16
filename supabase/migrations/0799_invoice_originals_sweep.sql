-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3985 -- the server removes the uploaded invoice PDFs that no recorded
-- original names. Since #3853 an issued invoice's PDF is uploaded to the
-- write-once bucket invoice-originals at <workspace>/<invoice>/<sha256>.pdf
-- before its original is recorded; an upload whose recording was refused
-- stays, and the file of an original whose invoice left with its business is
-- one no record names any more.
--
-- Removing a file cannot be undone, so:
--  * a file is a candidate only in that bucket, under the invoices' own
--    folder pattern, older than invoice_original_orphan_age(), and named by
--    NO column the schema stores a storage path in (storage_path_columns(),
--    the one list, pinned by test/lint/storage_path_columns_test.dart);
--  * the job reports by default: it counts and names what it would remove
--    and removes nothing. The setting records.invoice_originals_sweep
--    (platform) set to 'remove' by the operator switches removal on;
--  * at most invoice_original_sweep_cap() files per run; a file that cannot
--    be removed is named with its reason and left.
--
-- maintenance_runs: the installation's one maintenance record (a job's name,
-- when it ran, its counts and what it could not do with the reason), no
-- business, no client read. maintenance_state: a job's lease. One
-- maintenance secret serves every installation-wide job from now on: the
-- Edge secret MAINTENANCE_SECRET and the Vault secret
-- deskilo_maintenance_secret, the same value.
--
-- Operator, before the job does anything on a project: set both secrets and
-- deploy the maintenance function; to remove rather than report, set
-- records.invoice_originals_sweep to 'remove'.

-- ── rules ─────────────────────────────────────────────────────────────
-- A day: an upload is followed by its recording within the same request,
-- and a retry of the same file within minutes; a day leaves both alone.
create or replace function public.invoice_original_orphan_age()
returns interval language sql immutable set search_path = public as $fn$
  select interval '1 day';
$fn$;

-- At most this many files per run: a first run on an old installation is
-- spread over the following nights instead of one long removal.
create or replace function public.invoice_original_sweep_cap()
returns integer language sql immutable set search_path = public as $fn$
  select 200;
$fn$;

-- Every column the schema stores a storage object's path in, with the bucket
-- it names. A file named by ANY of them is never a candidate, whatever its
-- bucket: a free-text path is not trusted to name only its own bucket.
create or replace function public.storage_path_columns()
returns table (table_name text, column_name text, bucket text)
language sql immutable set search_path = public as $fn$
  values
    ('conversations', 'avatar_path', 'avatars'),
    ('invoice_originals', 'path', 'invoice-originals'),
    ('levels', 'background_path', 'floor-plans'),
    ('plan_images', 'storage_path', 'floor-plans'),
    ('profiles', 'avatar_path', 'avatars'),
    ('tax_exemption_certificates', 'file_path', 'documents');
$fn$;

revoke execute on function public.invoice_original_orphan_age() from public, anon, authenticated;
revoke execute on function public.invoice_original_sweep_cap() from public, anon, authenticated;
revoke execute on function public.storage_path_columns() from public, anon, authenticated;

-- ── the record ────────────────────────────────────────────────────────
create table public.maintenance_runs (
  id uuid primary key default gen_random_uuid(),
  job text not null check (job ~ '^[a-z][a-z0-9-]*$'),
  started_at timestamptz not null,
  finished_at timestamptz not null default now(),
  counts jsonb not null default '{}'::jsonb check (jsonb_typeof(counts) = 'object'),
  -- [{item, reason}]: what could not be done, by its name and a reason word.
  failures jsonb not null default '[]'::jsonb check (jsonb_typeof(failures) = 'array')
);
select public.ensure_system_columns('maintenance_runs');
create index maintenance_runs_job_idx on public.maintenance_runs (job, finished_at desc);

comment on table public.maintenance_runs is
  '#3985 -- the installation''s maintenance record: one row per run of an installation-wide job, its counts and what it could not do with the reason. Written by the service role through maintenance_finish_v1 only; no client reads it.';

alter table public.maintenance_runs enable row level security;
revoke all on public.maintenance_runs from public, anon, authenticated;
create policy mcp_delegated_deny on public.maintenance_runs as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- Installation-wide, no business: a personal surface, reached only by a
-- native session.
create policy personal_native_session on public.maintenance_runs as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

create table public.maintenance_state (
  job text primary key check (job ~ '^[a-z][a-z0-9-]*$'),
  lease_token uuid,
  lease_until timestamptz,
  last_attempt_at timestamptz
);
select public.ensure_system_columns('maintenance_state');

comment on table public.maintenance_state is
  '#3985 -- the lease of each installation-wide maintenance job and its last attempt. Written by the service role only.';

alter table public.maintenance_state enable row level security;
revoke all on public.maintenance_state from public, anon, authenticated;
create policy mcp_delegated_deny on public.maintenance_state as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- Installation-wide, no business: a personal surface, reached only by a
-- native session.
create policy personal_native_session on public.maintenance_state as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

-- ── the switch ────────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('records.invoice_originals_sweep', 'enum', '"report"'::jsonb, null, null, '', 'records', array['platform'], 'workspaceSettings', null, true, '["report","remove"]'::jsonb, 'invoice_originals_sweep_claim_v1 (#3985)', 'What the nightly maintenance does with an uploaded invoice PDF that no recorded original names, a day after its upload: report counts and names it in the maintenance record and removes nothing; remove deletes it from the store, which cannot be undone. A file a recorded original names is never touched.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── claim ─────────────────────────────────────────────────────────────
-- The sweep's lease for p_lease_seconds, its mode, and the files it would
-- remove: in invoice-originals, under <uuid>/<uuid>/<sha256>.pdf, older than
-- the age, named by no column of storage_path_columns(), oldest first, at most
-- the cap. Nothing when another run holds the lease.
create or replace function public.invoice_originals_sweep_claim_v1(p_lease_seconds integer)
returns table (lease_token uuid, mode text, candidates jsonb)
language plpgsql security definer set search_path = '' as $fn$
#variable_conflict use_column
declare
  v_token uuid := gen_random_uuid();
  v_named text;
  v_candidates jsonb;
begin
  if p_lease_seconds is null or p_lease_seconds < 1 then
    raise exception 'a lease is required' using errcode = '22023';
  end if;
  insert into public.maintenance_state (job) values ('invoice-originals-sweep')
  on conflict do nothing;
  update public.maintenance_state
     set lease_token = v_token,
         lease_until = now() + make_interval(secs => p_lease_seconds),
         last_attempt_at = now()
   where job = 'invoice-originals-sweep'
     and (lease_until is null or lease_until < now());
  if not found then
    return;
  end if;
  -- Every stored path, from every listed column.
  select string_agg(format('select %I::text as p from public.%I where %I is not null',
                           c.column_name, c.table_name, c.column_name), ' union all ')
    into v_named
    from public.storage_path_columns() c;
  execute format($q$
    select coalesce(jsonb_agg(jsonb_build_object('name', o.name, 'created_at', o.created_at)
                              order by o.created_at, o.name), '[]'::jsonb)
      from (select o.name, o.created_at
              from storage.objects o
             where o.bucket_id = 'invoice-originals'
               and o.name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{64}\.pdf$'
               and o.created_at < now() - public.invoice_original_orphan_age()
               and not exists (select 1 from (%s) n where n.p = o.name)
             order by o.created_at, o.name
             limit public.invoice_original_sweep_cap()) o
  $q$, v_named) into v_candidates;
  return query
  select v_token,
         case when (public.setting_value(null, 'records.invoice_originals_sweep') #>> '{}') = 'remove'
              then 'remove' else 'report' end,
         v_candidates;
end;
$fn$;
revoke execute on function public.invoice_originals_sweep_claim_v1(integer) from public, anon, authenticated;
grant execute on function public.invoice_originals_sweep_claim_v1(integer) to service_role;

-- ── finish ────────────────────────────────────────────────────────────
-- A job's run, from its lease's holder only (false otherwise: nothing is
-- written). p_counts: an object of counts; p_failures: [{item, reason}], the
-- item's name and a reason word only.
create or replace function public.maintenance_finish_v1(
  p_job text, p_lease_token uuid, p_started_at timestamptz, p_counts jsonb, p_failures jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $fn$
declare
  v_state public.maintenance_state;
begin
  if p_counts is null or jsonb_typeof(p_counts) <> 'object'
     or jsonb_typeof(coalesce(p_failures, '[]'::jsonb)) <> 'array' then
    raise exception 'counts and failures are required' using errcode = '22023';
  end if;
  select * into v_state from public.maintenance_state where job = p_job for update;
  if not found or v_state.lease_token is distinct from p_lease_token then
    return false;
  end if;
  insert into public.maintenance_runs (job, started_at, counts, failures)
  values (p_job, coalesce(p_started_at, now()),
          (select coalesce(jsonb_object_agg(k, greatest(coalesce((v #>> '{}')::integer, 0), 0)), '{}'::jsonb)
             from jsonb_each(p_counts) as e(k, v)
            where jsonb_typeof(v) = 'number'),
          (select coalesce(jsonb_agg(jsonb_build_object('item', f ->> 'item', 'reason', f ->> 'reason')), '[]'::jsonb)
             from jsonb_array_elements(coalesce(p_failures, '[]'::jsonb)) f
            where f ->> 'reason' ~ '^[a-z_]+$'));
  update public.maintenance_state set lease_token = null, lease_until = null where job = p_job;
  return true;
end;
$fn$;
revoke execute on function public.maintenance_finish_v1(text, uuid, timestamptz, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.maintenance_finish_v1(text, uuid, timestamptz, jsonb, jsonb) to service_role;

-- ── tick ──────────────────────────────────────────────────────────────
-- What the schedule runs: one post to the maintenance function naming the
-- job, or nothing when the functions URL or the maintenance secret is missing
-- ('not_configured').
create or replace function public.maintenance_tick(p_job text)
returns text
language plpgsql security definer set search_path = '' as $fn$
declare
  v_cfg public.push_config;
  v_secret text;
begin
  select * into v_cfg from public.push_config where id;
  select decrypted_secret into v_secret from vault.decrypted_secrets
   where name = 'deskilo_maintenance_secret';
  if v_cfg.functions_url is null or nullif(v_secret, '') is null then
    raise notice 'maintenance not configured: the functions URL or the Vault secret deskilo_maintenance_secret is missing';
    return 'not_configured';
  end if;
  perform net.http_post(
    url := v_cfg.functions_url || '/maintenance',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_cfg.anon_key,
      'Content-Type', 'application/json',
      'x-deskilo-maintenance-secret', v_secret),
    body := jsonb_build_object('job', p_job));
  return 'posted';
end;
$fn$;
revoke execute on function public.maintenance_tick(text) from public, anon, authenticated;
grant execute on function public.maintenance_tick(text) to service_role;

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-invoice-originals-sweep')
    where exists (select 1 from cron.job where jobname = 'deskilo-invoice-originals-sweep');
  perform cron.schedule('deskilo-invoice-originals-sweep', '17 3 * * *',
    $job$select public.maintenance_tick('invoice-originals-sweep')$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs maintenance_tick(''invoice-originals-sweep'') instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(799);
