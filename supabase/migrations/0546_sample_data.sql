-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0546 (#2872, ADR 0047 §9) -- sample data in the owner's own test space.
--
-- One switch fills a TEST space (environment 'dev') with a handful of
-- members, their bookings and their payments, made from the space's own
-- configuration: its places, its opening days and hours, its subscription
-- levels and fee bands. A second switch removes them again.
--
-- Every row the generation writes -- and every row its triggers write for
-- it -- is named in `sample_data_records` under one generation batch.
-- Clearing deletes exactly the rows of that batch and the rows that can
-- only exist because of them (they reference a batch member or booking),
-- never anything chosen by type or by creation time. A clear that cannot
-- remove everything raises and changes nothing, so the app says "not
-- cleared" and offers to try again.
--
-- What the generation never does: create an account, an invitation or an
-- invoice (an invoice takes a legal number from the space's sequence and
-- can never be deleted, so a statement is all a sample member gets), send
-- anything, call a payment or e-invoicing provider, or change what the
-- space declares about itself. A space holding sample data cannot be
-- declared production, and the setup status does not count a sample
-- booking or a sample member as evidence that the space is in use.
--
-- The members are managed profiles (0153) with no account, no member
-- number and no e-mail address, so nothing can ever reach them; the twin
-- mirror (0185) only copies members that have an account. The bookings are
-- status 'completed' in the past and 'reserved' ahead; the events their
-- triggers log are 'applied', which notifies nobody (notify_pending_event).

-- ── the batch and its records ─────────────────────────────────────────────
create table if not exists public.sample_data_batches (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  request_id uuid not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  cleared_at timestamptz,
  counts jsonb not null default '{}'::jsonb,
  constraint sample_data_batches_request_key unique (workspace_id, request_id)
);
select public.ensure_system_columns('sample_data_batches');
-- One open batch per space: a second "fill" answers the open one.
create unique index if not exists sample_data_batches_open_idx
  on public.sample_data_batches (workspace_id) where cleared_at is null;
alter table public.sample_data_batches enable row level security;
revoke all on table public.sample_data_batches from anon, authenticated;
grant select on table public.sample_data_batches to authenticated;
drop policy if exists mcp_delegated_deny on public.sample_data_batches;
create policy mcp_delegated_deny on public.sample_data_batches
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists sample_data_batches_configurers on public.sample_data_batches;
create policy sample_data_batches_configurers on public.sample_data_batches
  for select to authenticated
  using (public.has_permission(workspace_id, 'manageConfiguration'));

create table if not exists public.sample_data_records (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.sample_data_batches (id) on delete cascade,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  table_name text not null check (table_name in (
    'members', 'managed_identities', 'directory_people', 'reservations',
    'reservation_target_history', 'member_credit_uses', 'events',
    'ledger_entries', 'reservation_charges')),
  record_id uuid not null,
  constraint sample_data_records_key unique (batch_id, table_name, record_id)
);
select public.ensure_system_columns('sample_data_records');
create index if not exists sample_data_records_lookup_idx
  on public.sample_data_records (table_name, record_id);
alter table public.sample_data_records enable row level security;
revoke all on table public.sample_data_records from anon, authenticated;
grant select on table public.sample_data_records to authenticated;
drop policy if exists mcp_delegated_deny on public.sample_data_records;
create policy mcp_delegated_deny on public.sample_data_records
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists sample_data_records_configurers on public.sample_data_records;
create policy sample_data_records_configurers on public.sample_data_records
  for select to authenticated
  using (public.has_permission(workspace_id, 'manageConfiguration'));

-- Whether a row belongs to a sample batch. Read by definer functions only.
create or replace function public.is_sample_record(p_table text, p_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.sample_data_records s
                  where s.table_name = p_table and s.record_id = p_id);
$fn$;
revoke execute on function public.is_sample_record(text, uuid) from public, anon, authenticated;

-- Who may touch sample data: a person who configures the space, never an
-- assistant acting on their behalf.
create or replace function public.sample_data_guard(p_workspace_id uuid)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if public.mcp_is_delegated() then
    raise exception 'sample data is not available to a delegated assistant' using errcode = '42501';
  end if;
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this space may add or clear sample data'
      using errcode = '42501';
  end if;
end;
$fn$;
revoke execute on function public.sample_data_guard(uuid) from public, anon, authenticated;

create or replace function public.sample_data_json(p public.sample_data_batches)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object('batch_id', p.id, 'created_at', p.created_at,
                            'cleared_at', p.cleared_at, 'counts', p.counts);
$fn$;
revoke execute on function public.sample_data_json(public.sample_data_batches) from public, anon, authenticated;

-- ── the generation ────────────────────────────────────────────────────────
create or replace function public.create_sample_data(p_workspace_id uuid, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  w public.workspaces;
  v_batch public.sample_data_batches;
  v_first text[] := array['Camille', 'Lukas', 'Sofia', 'Lucía', 'Noah', 'Emma'];
  v_last text[] := array['Martin', 'Becker', 'Rossi', 'García', 'Dubois', 'Wilson'];
  v_presets int[];
  v_open int[];
  v_seats uuid[];
  v_members uuid[] := '{}';
  v_reservations uuid[] := '{}';
  v_identity jsonb;
  v_member uuid;
  v_person uuid;
  v_pct int;
  v_fee int;
  v_res uuid;
  v_seat uuid;
  v_day date;
  v_today date;
  v_start int;
  v_half int;
  v_end int;
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_ledger uuid;
  d int;
  i int;
begin
  perform public.sample_data_guard(p_workspace_id);
  if p_request_id is null then
    raise exception 'a request id is required' using errcode = '22023';
  end if;
  select * into w from public.workspaces where id = p_workspace_id;
  if w.id is null then
    raise exception 'no such workspace' using errcode = '22023';
  end if;
  if w.environment <> 'dev' then
    raise exception 'sample data lives only in a test space, never in a production one'
      using errcode = '22023';
  end if;
  if not public.feature_effective(p_workspace_id, 'setupGuide') then
    raise exception 'the setupGuide feature is off' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('sample-data:' || p_workspace_id::text, 2872));

  -- Activating twice is safe: the open batch, or the batch this request
  -- already made, is the answer.
  select * into v_batch from public.sample_data_batches b
   where b.workspace_id = p_workspace_id
     and (b.cleared_at is null or b.request_id = p_request_id)
   order by (b.cleared_at is null) desc limit 1;
  if v_batch.id is not null then
    return public.sample_data_json(v_batch);
  end if;

  insert into public.sample_data_batches (workspace_id, request_id, created_by)
  values (p_workspace_id, p_request_id, auth.uid())
  returning * into v_batch;

  -- The space's own subscription levels, opening days and hours.
  select coalesce(array_agg(x::int order by x::int) filter (where x::int > 0), '{}')
    into v_presets
    from jsonb_array_elements_text(case when jsonb_typeof(w.subscription_levels->'enabled_presets') = 'array'
                                        then w.subscription_levels->'enabled_presets' else '[]'::jsonb end) x;
  if cardinality(v_presets) = 0 then v_presets := array[100]; end if;
  v_open := coalesce((select array_agg(x::int) from jsonb_array_elements_text(
                        case when jsonb_typeof(w.booking_rules->'open_weekdays') = 'array'
                             then w.booking_rules->'open_weekdays' else '[]'::jsonb end) x),
                     array[1, 2, 3, 4, 5]);
  if cardinality(v_open) = 0 then v_open := array[1, 2, 3, 4, 5]; end if;
  select m.work_start, m.half_boundary, m.work_end, m.tz into v_start, v_half, v_end, v_tz
    from public.mcp_booking_period_minutes(p_workspace_id) m;
  v_tz := coalesce(v_tz, 'UTC');
  v_today := (now() at time zone v_tz)::date;

  -- Its own places: ordinary seats on its own levels, outside rented rooms.
  v_seats := array(
    select s.id from public.seats s
      join public.desks dk on dk.id = s.desk_id
      join public.offices o on o.id = dk.office_id
      left join public.levels l on l.id = o.level_id
     where s.workspace_id = p_workspace_id
       and coalesce(s.resource_kind, 'seat') = 'seat'
       and coalesce(l.kind, 'own') = 'own'
       and not exists (select 1 from public.room_rentals r where r.office_id = o.id)
     order by o.name, dk.name, s.name, s.id);

  -- The members: managed profiles without an account, an e-mail or a number.
  for i in 1 .. cardinality(v_first) loop
    v_pct := v_presets[1 + (i - 1) % cardinality(v_presets)];
    v_identity := jsonb_build_object('first_name', v_first[i], 'last_name', v_last[i]);
    insert into public.members
      (workspace_id, user_id, is_admin, status, managed_identity, managed_by,
       managed_name, origin, subscription_pct)
    values (p_workspace_id, null, false, 'active', public.managed_identity_public(v_identity),
            auth.uid(), public.managed_identity_name(v_identity), 'delegated', v_pct)
    returning id, person_id into v_member, v_person;
    insert into public.managed_identities (member_id, workspace_id, identity)
    values (v_member, p_workspace_id, v_identity);
    insert into public.sample_data_records (batch_id, workspace_id, table_name, record_id)
    values (v_batch.id, p_workspace_id, 'members', v_member),
           (v_batch.id, p_workspace_id, 'managed_identities', v_member),
           (v_batch.id, p_workspace_id, 'directory_people', v_person);
    v_members := v_members || v_member;

    -- Every second member paid last month's subscription at its fee band.
    if i % 2 = 1 then
      select b.fee_cents into v_fee from public.fee_bands b
       where b.workspace_id = p_workspace_id and b.from_pct < v_pct and v_pct <= b.to_pct
       order by b.from_pct limit 1;
      if coalesce(v_fee, 0) > 0 then
        insert into public.ledger_entries
          (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
        values (p_workspace_id, v_member, 'credit', 'payment', v_fee, '',
                to_char(v_today - interval '1 month', 'YYYY-MM'),
                least(v_today, date_trunc('month', v_today)::date + 4))
        returning id into v_ledger;
        insert into public.sample_data_records (batch_id, workspace_id, table_name, record_id)
        values (v_batch.id, p_workspace_id, 'ledger_entries', v_ledger);
      end if;
    end if;
  end loop;

  -- Their bookings, two weeks back and two weeks ahead, on open days only.
  if cardinality(v_seats) > 0 then
    for d in -14 .. 14 loop
      v_day := v_today + d;
      continue when not (extract(isodow from v_day)::int = any(v_open));
      continue when exists (select 1 from public.closure_days c
                             where c.workspace_id = p_workspace_id and c.day = v_day);
      for i in 1 .. cardinality(v_members) loop
        continue when (d + 14 + i) % 3 <> 0;
        v_seat := v_seats[1 + ((d + 14) * cardinality(v_members) + i) % cardinality(v_seats)];
        v_from := (v_day + make_interval(mins => v_start)) at time zone v_tz;
        v_to := (v_day + make_interval(mins => case when (d + i) % 2 = 0 then v_end else v_half end))
                  at time zone v_tz;
        continue when v_to <= v_from;
        continue when exists (select 1 from public.reservations r
                               where r.seat_id = v_seat
                                 and r.status in ('reserved', 'checked_in', 'completed')
                                 and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_from, v_to));
        begin
          insert into public.reservations
            (workspace_id, seat_id, member_id, starts_at, ends_at, status, checked_in_at, checked_out_at)
          values (p_workspace_id, v_seat, v_members[i], v_from, v_to,
                  case when v_to <= now() then 'completed' else 'reserved' end,
                  case when v_to <= now() then v_from end,
                  case when v_to <= now() then v_to end)
          returning id into v_res;
          v_reservations := v_reservations || v_res;
        exception when raise_exception or exclusion_violation or unique_violation then
          -- A place the space's own rules refuse (blocked, held by a whole
          -- room or level booking) is simply not used.
          null;
        end;
      end loop;
    end loop;
  end if;
  insert into public.sample_data_records (batch_id, workspace_id, table_name, record_id)
  select v_batch.id, p_workspace_id, 'reservations', unnest(v_reservations);

  -- What the triggers wrote for those rows belongs to the batch too.
  insert into public.sample_data_records (batch_id, workspace_id, table_name, record_id)
  select v_batch.id, p_workspace_id, t.name, t.id from (
    select 'events' as name, e.id from public.events e
     where e.workspace_id = p_workspace_id
       and (e.reservation_id = any(v_reservations) or e.subject_member_id = any(v_members)
            or e.actor_member_id = any(v_members))
    union
    select 'reservation_target_history', h.id from public.reservation_target_history h
     where h.reservation_id = any(v_reservations)
    union
    select 'member_credit_uses', u.id from public.member_credit_uses u
     where u.reservation_id = any(v_reservations)
    union
    select 'reservation_charges', c.id from public.reservation_charges c
     where c.workspace_id = p_workspace_id
       and (c.reservation_id = any(v_reservations) or c.member_id = any(v_members))
    union
    select 'ledger_entries', l.id from public.ledger_entries l
     where l.workspace_id = p_workspace_id and l.member_id = any(v_members)) t
  on conflict (batch_id, table_name, record_id) do nothing;

  update public.sample_data_batches b
     set counts = coalesce((select jsonb_object_agg(x.table_name, x.n) from (
                    select r.table_name, count(*) as n from public.sample_data_records r
                     where r.batch_id = b.id group by r.table_name) x), '{}'::jsonb)
   where b.id = v_batch.id
  returning * into v_batch;
  return public.sample_data_json(v_batch);
end;
$fn$;
revoke execute on function public.create_sample_data(uuid, uuid) from public, anon;
grant execute on function public.create_sample_data(uuid, uuid) to authenticated;

-- ── the cleanup ───────────────────────────────────────────────────────────
create or replace function public.clear_sample_data(p_workspace_id uuid, p_batch_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_batch public.sample_data_batches;
  v_members uuid[];
  v_reservations uuid[];
  v_people uuid[];
  v_left int := 0;
  v_n int;
  r record;
begin
  perform public.sample_data_guard(p_workspace_id);
  perform pg_advisory_xact_lock(hashtextextended('sample-data:' || p_workspace_id::text, 2872));
  select * into v_batch from public.sample_data_batches b
   where b.id = p_batch_id and b.workspace_id = p_workspace_id for update;
  if v_batch.id is null then
    raise exception 'no such sample data batch' using errcode = 'P0002';
  end if;
  if v_batch.cleared_at is not null then
    return public.sample_data_json(v_batch) || jsonb_build_object('remaining', '{}'::jsonb);
  end if;

  v_members := array(select s.record_id from public.sample_data_records s
                      where s.batch_id = v_batch.id and s.table_name = 'members');
  v_people := array(select s.record_id from public.sample_data_records s
                     where s.batch_id = v_batch.id and s.table_name = 'directory_people');
  -- A booking the owner made later for a sample member is the batch's too.
  v_reservations := array(
    select s.record_id from public.sample_data_records s
     where s.batch_id = v_batch.id and s.table_name = 'reservations'
    union
    select x.id from public.reservations x
     where x.workspace_id = p_workspace_id and x.member_id = any(v_members));

  begin
    -- Dependency order: a quote before its ledger charge, the ledger before
    -- the events it points at, the bookings and identities before the
    -- members, the members before their directory person.
    delete from public.reservation_charges c
     where c.workspace_id = p_workspace_id
       and (c.id in (select s.record_id from public.sample_data_records s
                      where s.batch_id = v_batch.id and s.table_name = 'reservation_charges')
            or c.reservation_id = any(v_reservations) or c.member_id = any(v_members));
    -- The one other place the append-only ledger stands down (0212), for
    -- the rows of this batch only; transaction-local and aimed at this table.
    perform set_config('deskilo.ledger_reset', 'public.ledger_entries'::regclass::oid::text, true);
    delete from public.ledger_entries l
     where l.workspace_id = p_workspace_id
       and (l.id in (select s.record_id from public.sample_data_records s
                      where s.batch_id = v_batch.id and s.table_name = 'ledger_entries')
            or l.member_id = any(v_members));
    perform set_config('deskilo.ledger_reset', '', true);
    delete from public.events e
     where e.workspace_id = p_workspace_id
       and (e.id in (select s.record_id from public.sample_data_records s
                      where s.batch_id = v_batch.id and s.table_name = 'events')
            or e.subject_member_id = any(v_members) or e.actor_member_id = any(v_members)
            or e.reservation_id = any(v_reservations));
    delete from public.reservations x
     where x.workspace_id = p_workspace_id and x.id = any(v_reservations);
    delete from public.managed_identities mi where mi.member_id = any(v_members);
    delete from public.members m
     where m.workspace_id = p_workspace_id and m.id = any(v_members);
    delete from public.directory_people dp
     where dp.id = any(v_people)
       and not exists (select 1 from public.members m where m.person_id = dp.id)
       and not exists (select 1 from public.profiles p where p.person_id = dp.id);
  exception when foreign_key_violation or raise_exception then
    perform set_config('deskilo.ledger_reset', '', true);
    raise exception 'sample data not cleared: %', sqlerrm using errcode = '55000';
  end;

  -- Nothing the batch recorded may remain.
  for r in select s.table_name, array_agg(s.record_id) as ids from public.sample_data_records s
            where s.batch_id = v_batch.id group by s.table_name loop
    execute format('select count(*) from public.%I where %I = any($1)', r.table_name,
                   case when r.table_name = 'managed_identities' then 'member_id' else 'id' end)
      into v_n using r.ids;
    v_left := v_left + v_n;
  end loop;
  if v_left > 0 then
    raise exception 'sample data not cleared: % records remain', v_left using errcode = '55000';
  end if;

  delete from public.sample_data_records s where s.batch_id = v_batch.id;
  update public.sample_data_batches b set cleared_at = now()
   where b.id = v_batch.id returning * into v_batch;
  return public.sample_data_json(v_batch)
      || jsonb_build_object('remaining', coalesce((select jsonb_object_agg(k, 0)
                                                     from jsonb_object_keys(v_batch.counts) k),
                                                  '{}'::jsonb));
end;
$fn$;
revoke execute on function public.clear_sample_data(uuid, uuid) from public, anon;
grant execute on function public.clear_sample_data(uuid, uuid) to authenticated;

-- The open batch of a space, or null.
create or replace function public.sample_data_status(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_batch public.sample_data_batches;
begin
  perform public.sample_data_guard(p_workspace_id);
  select * into v_batch from public.sample_data_batches b
   where b.workspace_id = p_workspace_id and b.cleared_at is null;
  if v_batch.id is null then return null; end if;
  return public.sample_data_json(v_batch);
end;
$fn$;
revoke execute on function public.sample_data_status(uuid) from public, anon;
grant execute on function public.sample_data_status(uuid) to authenticated;

-- ── a space holding sample data is a test space ───────────────────────────
create or replace function public.workspaces_sample_data_stays_test()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.environment = 'prod' and old.environment is distinct from 'prod'
     and exists (select 1 from public.sample_data_batches b
                  where b.workspace_id = new.id and b.cleared_at is null) then
    raise exception 'clear the sample data before declaring this space production'
      using errcode = '55000';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_sample_data_stays_test() from public, anon, authenticated;
drop trigger if exists workspaces_sample_data_stays_test on public.workspaces;
create trigger workspaces_sample_data_stays_test
before update of environment on public.workspaces
for each row execute function public.workspaces_sample_data_stays_test();

-- ── the setup status reads no sample row as evidence ──────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $patch$
declare
  v_def text := pg_get_functiondef('public.workspace_readiness(uuid)'::regprocedure);
  v_old text[] := array[
    $a$from public.members where workspace_id = p_workspace_id and status = 'active';$a$,
    $a$and r.status in ('reserved', 'checked_in', 'completed'));$a$];
  v_new text[] := array[
    $a$from public.members where workspace_id = p_workspace_id and status = 'active' and not public.is_sample_record('members', members.id);$a$,
    $a$and r.status in ('reserved', 'checked_in', 'completed') and not public.is_sample_record('reservations', r.id));$a$];
  v_next text;
  i int;
begin
  for i in 1 .. cardinality(v_old) loop
    if position(v_old[i] in v_def) > 0
       and (length(v_def) - length(replace(v_def, v_old[i], ''))) <> length(v_old[i]) then
      raise exception '0546: anchor % occurs more than once in workspace_readiness', i;
    end if;
    v_next := pg_temp.anchor_replace(v_def, v_old[i], v_new[i]);
    if v_next is null or v_next = v_def then
      raise exception '0546: anchor % missing in workspace_readiness', i;
    end if;
    v_def := v_next;
  end loop;
  execute v_def;
end
$patch$;

select public.set_deskilo_schema_version(546);
