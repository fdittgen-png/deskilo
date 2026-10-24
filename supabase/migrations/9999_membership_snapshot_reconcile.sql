-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: three new tables, one index, the functions below and one pg_cron job.
-- Restated whole: protect_federation_history and federation_retention_purge
-- (0574), federation_inbox_accept (0569). No existing row is rewritten.
--
-- #2563 C2, third checkpoint -- full-snapshot reconciliation of membership
-- facts, and the retention of the identity status outbox.
--
-- Snapshot (W, the workspace installation):
--   * `membership_snapshot_issue()` cuts, at most once per
--     `identity.status_reconcile_seconds`, the LIVE relationships
--     (`membership_fact_state`, status other than tombstone) it holds for its
--     personal home's issuer. It locks the high-water table in share mode
--     first, so every revision taken before the cut is committed and every
--     later one is above the watermark (the largest revision held).
--   * The manifest is the watermark, the entry count and the SHA-256 of the
--     canonical list (`membership_snapshot_digest`: one line per entry,
--     sorted bytewise by subject then network id). Every page repeats it;
--     the entries are paged so that a body stays well under the inbox's
--     16 KB limit. `membership_snapshot_drain()` signs each page with the
--     `membership_fact` key and posts it (kind `membership_snapshot`) to the
--     same `federation-inbox`.
--
-- Reconciliation (P, the personal home):
--   * `membership_snapshot_apply` decodes each page strictly (a malformed
--     entry sinks the page), checks the issuer, the deadline, the enrolment
--     and that every network id belongs to the source, and stages the page.
--     A page that disagrees with the pages staged for the same snapshot is
--     refused; a snapshot older than the source's watermark is superseded.
--   * Only when EVERY page arrived, the entry count and the hash match and
--     no page has lapsed does anything change: each live fact of that source
--     with a revision below the watermark that the snapshot does not list is
--     tombstoned locally at the watermark revision (a later rejoin at W is a
--     newer revision). A fact the snapshot lists is never touched, nor one
--     newer than the cut. The per-source watermark is then recorded.
--   * A partial, conflicting, lapsed or unverified snapshot changes nothing.
--
-- Retention (`federation.retention_hours`, 0574): the hourly purge also
-- removes identity status assertions that were delivered or expired and
-- whose deadline (and delivery) is older than the retention interval, and
-- staged snapshot pages older than it. `protect_federation_history` lets
-- exactly those outbox rows go under the purge's marker; a pending, sent or
-- refused assertion, or a recent one, still keeps its history.

-- ── W: the snapshot outbox ───────────────────────────────────────────
create table if not exists public.membership_snapshot_outbox (
  event_id uuid primary key,
  target_installation_id uuid not null,
  snapshot_id uuid not null,
  page int not null check (page > 0),
  pages int not null,
  watermark bigint not null check (watermark >= 0),
  entry_count int not null check (entry_count >= 0),
  manifest_hash text not null check (manifest_hash ~ '^[0-9a-f]{64}$'),
  asserted_at timestamptz not null,
  valid_until timestamptz not null check (valid_until > asserted_at),
  body jsonb not null,
  state text not null default 'pending'
    check (state in ('pending', 'sent', 'delivered', 'refused', 'expired')),
  attempts int not null default 0,
  last_attempt_at timestamptz,
  net_request_id bigint,
  outcome text,
  delivered_at timestamptz,
  constraint membership_snapshot_outbox_page check (page <= pages),
  constraint membership_snapshot_outbox_one_page unique (snapshot_id, page)
);
select public.ensure_system_columns('membership_snapshot_outbox');
create index if not exists membership_snapshot_outbox_due
  on public.membership_snapshot_outbox (state, asserted_at) where state in ('pending', 'sent');
comment on table public.membership_snapshot_outbox is
  '#2563 C2 -- the pages of the full membership snapshots this workspace '
  'installation cut for its personal home, and how their delivery went.';

-- ── P: staged pages and the per-source watermark ─────────────────────
create table if not exists public.membership_snapshot_pages (
  source_installation_id uuid not null,
  snapshot_id uuid not null,
  page int not null check (page > 0),
  pages int not null,
  issuer text not null,
  watermark bigint not null check (watermark >= 0),
  entry_count int not null check (entry_count >= 0),
  manifest_hash text not null check (manifest_hash ~ '^[0-9a-f]{64}$'),
  enrolment_epoch timestamptz not null,
  asserted_at timestamptz not null,
  valid_until timestamptz not null check (valid_until > asserted_at),
  entries jsonb not null check (jsonb_typeof(entries) = 'array'),
  event_id uuid not null,
  received_at timestamptz not null default now(),
  primary key (source_installation_id, snapshot_id, page),
  constraint membership_snapshot_pages_page check (page <= pages)
);
select public.ensure_system_columns('membership_snapshot_pages');
comment on table public.membership_snapshot_pages is
  '#2563 C2 -- pages of a membership snapshot received from a workspace '
  'installation and not yet complete. Removed when the snapshot completes, '
  'is refused, or ages past federation.retention_hours.';

create table if not exists public.membership_snapshot_watermarks (
  source_installation_id uuid primary key,
  enrolment_epoch timestamptz not null,
  watermark bigint not null check (watermark >= 0),
  snapshot_id uuid not null,
  live_count int not null check (live_count >= 0),
  removed int not null check (removed >= 0),
  completed_at timestamptz not null
);
select public.ensure_system_columns('membership_snapshot_watermarks');
comment on table public.membership_snapshot_watermarks is
  '#2563 C2 -- per workspace installation, the last complete and verified '
  'membership snapshot this personal home reconciled: an older one is refused.';

alter table public.membership_snapshot_outbox enable row level security;
revoke all on public.membership_snapshot_outbox from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.membership_snapshot_outbox;
create policy mcp_delegated_deny on public.membership_snapshot_outbox
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.membership_snapshot_outbox;
create policy personal_native_session on public.membership_snapshot_outbox
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
alter table public.membership_snapshot_pages enable row level security;
revoke all on public.membership_snapshot_pages from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.membership_snapshot_pages;
create policy mcp_delegated_deny on public.membership_snapshot_pages
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.membership_snapshot_pages;
create policy personal_native_session on public.membership_snapshot_pages
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
alter table public.membership_snapshot_watermarks enable row level security;
revoke all on public.membership_snapshot_watermarks from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.membership_snapshot_watermarks;
create policy mcp_delegated_deny on public.membership_snapshot_watermarks
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.membership_snapshot_watermarks;
create policy personal_native_session on public.membership_snapshot_watermarks
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

-- ── the manifest hash, one definition for both sides ─────────────────
-- Entries are [subject, network id, revision, status]; the order they
-- arrive in does not matter.
create or replace function public.membership_snapshot_digest(p_entries jsonb)
returns text language sql stable set search_path = '' as $fn$
  select encode(extensions.digest(convert_to(coalesce(string_agg(
           (e->>0) || ' ' || (e->>1) || ' ' || (e->>2) || ' ' || (e->>3), E'\n'
           order by (e->>0) collate "C", (e->>1) collate "C"), ''), 'UTF8'), 'sha256'), 'hex')
    from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) e;
$fn$;
revoke execute on function public.membership_snapshot_digest(jsonb)
  from public, anon, authenticated, service_role;

-- ── W: cut a snapshot ────────────────────────────────────────────────
create or replace function public.membership_snapshot_issue()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_issuer text;
  v_home record;
  v_every interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_reconcile_seconds') #>> '{}')::int);
  v_until timestamptz := now() + make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
  v_snapshot uuid := gen_random_uuid();
  v_watermark bigint;
  v_entries jsonb;
  v_count int;
  v_hash text;
  v_chunks jsonb[];
  v_pages int;
  v_event uuid;
begin
  select issuer into v_issuer from public.identity_authority where kind = 'oidc';
  if v_issuer is null then
    return jsonb_build_object('issued', 0, 'authority', 'native');
  end if;
  select * into v_home from public.membership_fact_home();
  if v_home.home_installation_id is null then
    return jsonb_build_object('issued', 0, 'home', 'none');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('membership_snapshot_issue', 2563));
  if exists (select 1 from public.membership_snapshot_outbox o
              where o.target_installation_id = v_home.home_installation_id
                and o.asserted_at > now() - v_every) then
    return jsonb_build_object('issued', 0, 'due', false);
  end if;
  -- Waits for every writer of the high-water: after this, each revision
  -- already taken is committed, and each new one is above the watermark.
  lock table public.membership_fact_state in share mode;
  select coalesce(max(s.revision), 0) into v_watermark
    from public.membership_fact_state s where s.issuer = v_issuer;
  select coalesce(jsonb_agg(jsonb_build_array(s.subject, s.network_id, s.revision, s.status)
                            order by s.subject collate "C", s.network_id collate "C"), '[]'::jsonb),
         count(*)::int
    into v_entries, v_count
    from public.membership_fact_state s
   where s.issuer = v_issuer and s.status <> 'tombstone';
  v_hash := public.membership_snapshot_digest(v_entries);
  -- Pages of about 12 000 bytes of entries: one entry is a few hundred bytes
  -- at most, so a page with its manifest stays under the inbox's 16 384.
  select array_agg(p.entries order by p.ix) into v_chunks
    from (select c.start / 12000 as ix, jsonb_agg(c.e order by c.n) as entries
            from (select x.e, x.n,
                         sum(octet_length(x.e::text)) over (order by x.n) - octet_length(x.e::text) as start
                    from jsonb_array_elements(v_entries) with ordinality x(e, n)) c
           group by c.start / 12000) p;
  v_chunks := coalesce(v_chunks, array['[]'::jsonb]);
  v_pages := array_length(v_chunks, 1);
  for i in 1 .. v_pages loop
    v_event := gen_random_uuid();
    insert into public.membership_snapshot_outbox (event_id, target_installation_id, snapshot_id,
      page, pages, watermark, entry_count, manifest_hash, asserted_at, valid_until, body)
    values (v_event, v_home.home_installation_id, v_snapshot, i, v_pages, v_watermark, v_count,
      v_hash, now(), v_until,
      jsonb_build_object('protocol', 1, 'kind', 'membership_snapshot', 'event_id', v_event,
        'source_installation_id', public.installation_id(),
        'target_installation_id', v_home.home_installation_id, 'issuer', v_issuer,
        'snapshot_id', v_snapshot, 'watermark', v_watermark, 'page', i, 'pages', v_pages,
        'count', v_count, 'hash', v_hash, 'asserted_at', now(), 'valid_until', v_until,
        'entries', v_chunks[i]));
  end loop;
  return jsonb_build_object('issued', v_pages, 'snapshot_id', v_snapshot,
    'watermark', v_watermark, 'count', v_count);
end;
$fn$;
revoke execute on function public.membership_snapshot_issue()
  from public, anon, authenticated, service_role;

-- ── W: deliver (membership_fact_drain's shape) ───────────────────────
create or replace function public.membership_snapshot_drain()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.membership_snapshot_outbox;
  v_home record;
  v_code int;
  v_content text;
  v_timed_out boolean;
  v_found int;
  v_outcome text;
  v_headers jsonb;
  v_sent int := 0;
  v_settled int := 0;
begin
  -- 1. the answers to earlier attempts
  if to_regclass('net._http_response') is not null then
    for v_row in select * from public.membership_snapshot_outbox
                  where state = 'sent' order by asserted_at, page for update skip locked loop
      execute 'select status_code, content, timed_out from net._http_response where id = $1'
        into v_code, v_content, v_timed_out using v_row.net_request_id;
      get diagnostics v_found = row_count;
      begin
        v_outcome := v_content::jsonb->>'outcome';
      exception when others then
        v_outcome := null;
      end;
      if v_found = 0 then
        if v_row.last_attempt_at < now() - interval '2 minutes' then
          update public.membership_snapshot_outbox set state = 'pending', outcome = 'no_answer'
           where event_id = v_row.event_id;
        end if;
        continue;
      end if;
      if v_code between 200 and 299 then
        update public.membership_snapshot_outbox
           set state = 'delivered', delivered_at = now(), outcome = coalesce(v_outcome, 'delivered')
         where event_id = v_row.event_id;
      elsif v_code in (400, 409, 421, 422) then
        update public.membership_snapshot_outbox
           set state = 'refused', outcome = coalesce(v_outcome, 'http_' || v_code)
         where event_id = v_row.event_id;
      else
        update public.membership_snapshot_outbox
           set state = 'pending',
               outcome = coalesce(v_outcome, case when coalesce(v_timed_out, false)
                                                  then 'timeout' else 'http_' || v_code end)
         where event_id = v_row.event_id;
      end if;
      v_settled := v_settled + 1;
    end loop;
  end if;
  -- 2. what lapsed undelivered, and what can no longer matter
  update public.membership_snapshot_outbox set state = 'expired'
   where state in ('pending', 'sent') and valid_until <= now();
  delete from public.membership_snapshot_outbox
   where state in ('delivered', 'refused', 'expired') and valid_until <= now();
  -- 3. send
  if to_regprocedure('net.http_post(text, jsonb, jsonb, jsonb, integer)') is null then
    return jsonb_build_object('settled', v_settled, 'sent', 0, 'transport', 'unavailable');
  end if;
  select * into v_home from public.membership_fact_home();
  for v_row in select * from public.membership_snapshot_outbox
                where state = 'pending' order by asserted_at, page limit 200 for update skip locked loop
    if v_row.target_installation_id is distinct from v_home.home_installation_id then
      update public.membership_snapshot_outbox set state = 'refused', outcome = 'home_changed'
       where event_id = v_row.event_id;
      continue;
    end if;
    begin
      v_headers := public.federation_envelope_headers('membership_fact',
        v_row.target_installation_id, v_row.event_id, '/federation-inbox', v_row.body);
    exception when sqlstate 'P0002' then
      update public.membership_snapshot_outbox set outcome = 'no_outbound_key'
       where event_id = v_row.event_id;
      continue;
    end;
    update public.membership_snapshot_outbox
       set state = 'sent', attempts = attempts + 1, last_attempt_at = now(),
           net_request_id = net.http_post(
             url := v_home.home_origin || '/functions/v1/federation-inbox',
             body := v_row.body,
             headers := v_headers || jsonb_build_object('Content-Type', 'application/json',
                                                        'apikey', v_home.home_key),
             timeout_milliseconds := 10000)
     where event_id = v_row.event_id;
    v_sent := v_sent + 1;
  end loop;
  return jsonb_build_object('settled', v_settled, 'sent', v_sent);
end;
$fn$;
revoke execute on function public.membership_snapshot_drain()
  from public, anon, authenticated, service_role;

-- ── P: stage, verify, reconcile ──────────────────────────────────────
create or replace function public.membership_snapshot_apply(
  p_body jsonb, p_source uuid, p_event uuid, p_request_ts bigint)
returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_skew interval := make_interval(secs =>
    (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int);
  v_lifetime interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
  v_issuer text;
  v_snapshot uuid;
  v_watermark bigint;
  v_page int;
  v_pages int;
  v_count int;
  v_hash text;
  v_issued timestamptz;
  v_until timestamptz;
  v_entries jsonb;
  v_epoch timestamptz;
  v_mark public.membership_snapshot_watermarks;
  v_staged public.membership_snapshot_pages;
  v_all jsonb;
  v_removed int;
begin
  begin
    v_issuer := p_body->>'issuer';
    v_snapshot := (p_body->>'snapshot_id')::uuid;
    v_watermark := (p_body->>'watermark')::bigint;
    v_page := (p_body->>'page')::int;
    v_pages := (p_body->>'pages')::int;
    v_count := (p_body->>'count')::int;
    v_hash := p_body->>'hash';
    v_issued := (p_body->>'asserted_at')::timestamptz;
    v_until := (p_body->>'valid_until')::timestamptz;
    v_entries := p_body->'entries';
  exception when others then
    return 'malformed';
  end;
  if p_body->>'kind' is distinct from 'membership_snapshot' or p_body->>'protocol' is distinct from '1'
     or p_body->>'event_id' is distinct from p_event::text
     or p_body->>'source_installation_id' is distinct from p_source::text
     or p_body->>'target_installation_id' is distinct from public.installation_id()::text
     or v_issuer is null or v_snapshot is null or coalesce(v_watermark, -1) < 0
     or coalesce(v_page, 0) < 1 or v_pages is null or v_page > v_pages
     or coalesce(v_count, -1) < 0 or coalesce(v_hash, '') !~ '^[0-9a-f]{64}$'
     or v_issued is null or v_until is null or v_until <= v_issued
     or jsonb_typeof(v_entries) is distinct from 'array' then
    return 'malformed';
  end if;
  if jsonb_array_length(v_entries) > v_count then
    return 'malformed';
  end if;
  -- Every entry is [subject, network id, revision 1..watermark, live status].
  if (exists (select 1 from jsonb_array_elements(v_entries) e
               where (case when jsonb_typeof(e) <> 'array' then true
                           when jsonb_array_length(e) <> 4 then true
                           when jsonb_typeof(e->0) <> 'string' or jsonb_typeof(e->1) <> 'string'
                                or jsonb_typeof(e->2) <> 'number' or jsonb_typeof(e->3) <> 'string'
                             then true
                           when char_length(e->>0) not between 1 and 255 then true
                           when not public.workspace_network_ref_valid(e->>1) then true
                           when (e->>2) !~ '^[1-9][0-9]{0,17}$' then true
                           when (e->>2)::bigint > v_watermark then true
                           else (e->>3) not in ('active', 'paused', 'pending', 'exited') end)))
     or (select count(*) from (select distinct e->>0 as s, e->>1 as n from jsonb_array_elements(v_entries) e) d)
        <> jsonb_array_length(v_entries) then
    return 'malformed';
  end if;
  -- A workspace installation speaks for its own workspaces only.
  if exists (select 1 from jsonb_array_elements(v_entries) e
              where split_part(e->>1, ':', 1) <> p_source::text) then
    return 'foreign_workspace';
  end if;
  if not exists (select 1 from public.identity_authority
                  where kind = 'native' and issuer = v_issuer) then
    return 'wrong_issuer';
  end if;
  if v_issued > now() + v_skew or to_timestamp(p_request_ts) < v_issued - v_skew then
    return 'future_assertion';
  end if;
  v_until := least(v_until, v_issued + v_lifetime);
  if v_until + v_skew <= now() then
    return 'expired_assertion';
  end if;
  select enrolled_at into v_epoch from public.enrolled_installations
   where installation_id = p_source and enabled;
  if v_epoch is null then
    return 'unenrolled_source';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('membership_snapshot:' || p_source, 2563));
  select * into v_mark from public.membership_snapshot_watermarks
   where source_installation_id = p_source for update;
  if v_mark.snapshot_id = v_snapshot
     or (v_mark.enrolment_epoch = v_epoch and v_mark.watermark > v_watermark) then
    return 'superseded';
  end if;
  -- Every page of one snapshot carries the same manifest.
  if exists (select 1 from public.membership_snapshot_pages s
              where s.source_installation_id = p_source and s.snapshot_id = v_snapshot
                and row(s.issuer, s.watermark, s.pages, s.entry_count, s.manifest_hash, s.enrolment_epoch)
                    is distinct from row(v_issuer, v_watermark, v_pages, v_count, v_hash, v_epoch)) then
    return 'snapshot_conflict';
  end if;
  select * into v_staged from public.membership_snapshot_pages
   where source_installation_id = p_source and snapshot_id = v_snapshot and page = v_page;
  if v_staged.page is not null then
    return (case when v_staged.entries = v_entries then 'duplicate' else 'snapshot_conflict' end);
  end if;
  insert into public.membership_snapshot_pages (source_installation_id, snapshot_id, page, pages,
    issuer, watermark, entry_count, manifest_hash, enrolment_epoch, asserted_at, valid_until,
    entries, event_id)
  values (p_source, v_snapshot, v_page, v_pages, v_issuer, v_watermark, v_count, v_hash, v_epoch,
    v_issued, v_until, v_entries, p_event);
  if (select count(*) from public.membership_snapshot_pages
       where source_installation_id = p_source and snapshot_id = v_snapshot) < v_pages then
    return 'staged';
  end if;
  -- Complete: verify the whole list against its manifest before anything moves.
  select coalesce(jsonb_agg(e), '[]'::jsonb) into v_all
    from public.membership_snapshot_pages s
   cross join lateral jsonb_array_elements(s.entries) e
   where s.source_installation_id = p_source and s.snapshot_id = v_snapshot;
  if jsonb_array_length(v_all) <> v_count
     or (select count(*) from (select distinct e->>0 as s, e->>1 as n from jsonb_array_elements(v_all) e) d)
        <> v_count
     or public.membership_snapshot_digest(v_all) <> v_hash then
    delete from public.membership_snapshot_pages
     where source_installation_id = p_source and snapshot_id = v_snapshot;
    return 'unverified';
  end if;
  if (select min(s.valid_until) from public.membership_snapshot_pages s
       where s.source_installation_id = p_source and s.snapshot_id = v_snapshot) + v_skew <= now() then
    delete from public.membership_snapshot_pages
     where source_installation_id = p_source and snapshot_id = v_snapshot;
    return 'expired_snapshot';
  end if;
  -- A live fact of this source, older than the cut and not listed, ended.
  with listed as (select e->>0 as subject, e->>1 as network_id from jsonb_array_elements(v_all) e)
  update public.membership_facts f
     set status = 'tombstone', revision = v_watermark, asserted_at = v_issued,
         valid_until = v_until, enrolment_epoch = v_epoch, event_id = p_event,
         received_at = now(), workspace_name = null
   where f.source_installation_id = p_source and f.issuer = v_issuer
     and f.status <> 'tombstone' and f.revision < v_watermark
     and not exists (select 1 from listed l
                      where l.subject = f.user_id::text and l.network_id = f.network_id);
  get diagnostics v_removed = row_count;
  insert into public.membership_snapshot_watermarks (source_installation_id, enrolment_epoch,
    watermark, snapshot_id, live_count, removed, completed_at)
  values (p_source, v_epoch, v_watermark, v_snapshot, v_count, v_removed, now())
  on conflict (source_installation_id) do update
     set enrolment_epoch = excluded.enrolment_epoch, watermark = excluded.watermark,
         snapshot_id = excluded.snapshot_id, live_count = excluded.live_count,
         removed = excluded.removed, completed_at = excluded.completed_at;
  delete from public.membership_snapshot_pages
   where source_installation_id = p_source
     and (snapshot_id = v_snapshot or watermark < v_watermark);
  return 'reconciled';
end;
$fn$;
revoke execute on function public.membership_snapshot_apply(jsonb, uuid, uuid, bigint)
  from public, anon, authenticated, service_role;

-- What `federation-inbox` calls with the request's raw body (base64).
-- 0569's, restated whole: the purpose decides the side, and a
-- membership_fact body's kind decides between a fact and a snapshot page.
create or replace function public.federation_inbox_accept(
  p_method text, p_path text, p_headers jsonb, p_body_b64 text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_raw bytea;
  v_verified jsonb;
  v_body jsonb;
  v_receipt public.federation_inbox_receipts;
  v_outcome text;
begin
  if p_method is distinct from 'POST' or p_path is distinct from '/federation-inbox' then
    return jsonb_build_object('outcome', 'malformed');
  end if;
  begin
    v_raw := decode(p_body_b64, 'base64');
  exception when others then
    return jsonb_build_object('outcome', 'malformed');
  end;
  if coalesce(octet_length(v_raw), 0) not between 1 and 16384 then
    return jsonb_build_object('outcome', 'malformed');
  end if;
  v_verified := public.federation_verify(p_method, p_path, p_headers, v_raw);
  if v_verified->>'outcome' <> 'verified' then
    return jsonb_build_object('outcome', v_verified->>'outcome');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'federation_inbox:' || (v_verified->>'source') || ':' || (v_verified->>'event'), 2562));
  select * into v_receipt from public.federation_inbox_receipts
   where source_installation_id = (v_verified->>'source')::uuid
     and event_id = (v_verified->>'event')::uuid;
  if v_receipt.event_id is not null then
    if v_receipt.body_digest = v_verified->>'digest' then
      return jsonb_build_object('outcome', 'duplicate', 'first_outcome', v_receipt.outcome);
    end if;
    return jsonb_build_object('outcome', 'event_conflict');
  end if;
  begin
    v_body := convert_from(v_raw, 'UTF8')::jsonb;
  exception when others then
    v_outcome := 'malformed';
  end;
  if v_outcome is null and jsonb_typeof(v_body) = 'object' then
    if v_verified->>'purpose' = 'identity_status' then
      v_outcome := public.identity_status_apply(v_body, (v_verified->>'source')::uuid,
        (v_verified->>'event')::uuid, (v_verified->>'timestamp')::bigint);
    elsif v_verified->>'purpose' = 'membership_fact' then
      if v_body->>'kind' = 'membership_snapshot' then
        v_outcome := public.membership_snapshot_apply(v_body, (v_verified->>'source')::uuid,
          (v_verified->>'event')::uuid, (v_verified->>'timestamp')::bigint);
      else
        v_outcome := public.membership_fact_apply(v_body, (v_verified->>'source')::uuid,
          (v_verified->>'event')::uuid, (v_verified->>'timestamp')::bigint);
      end if;
    end if;
  end if;
  v_outcome := coalesce(v_outcome, 'malformed');
  insert into public.federation_inbox_receipts
    (source_installation_id, event_id, purpose, body_digest, outcome)
  values ((v_verified->>'source')::uuid, (v_verified->>'event')::uuid,
          v_verified->>'purpose', v_verified->>'digest', v_outcome);
  return jsonb_build_object('outcome', v_outcome);
end;
$fn$;
revoke execute on function public.federation_inbox_accept(text, text, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.federation_inbox_accept(text, text, jsonb, text) to service_role;

-- ── retention ────────────────────────────────────────────────────────
-- 0574's guard, restated whole: under the purge's marker it lets through a
-- receipt older than the retention interval, and an identity status
-- assertion that was delivered or expired and whose deadline and delivery
-- are both older than it. Nothing else is deleted.
create or replace function public.protect_federation_history()
returns trigger language plpgsql set search_path = '' as $fn$
begin
  if tg_op = 'DELETE' then
    -- Each table's fields are read only on its own branch.
    if coalesce(current_setting('deskilo.federation_retention', true), '') = 'on' then
      if tg_table_name = 'federation_inbox_receipts' then
        if old.received_at <= now() - public.federation_retention_interval() then
          return old;
        end if;
      elsif tg_table_name = 'identity_status_outbox' then
        if old.state in ('delivered', 'expired')
           and old.valid_until <= now() - public.federation_retention_interval()
           and coalesce(old.delivered_at, old.valid_until)
               <= now() - public.federation_retention_interval() then
          return old;
        end if;
      end if;
    end if;
    raise exception '% keeps its history', tg_table_name using errcode = '55000';
  end if;
  if tg_table_name = 'federation_keys' then
    if row(new.peer_installation_id, new.direction, new.purpose, new.key_id, new.vault_secret_id)
         is distinct from row(old.peer_installation_id, old.direction, old.purpose, old.key_id,
                              old.vault_secret_id)
       or (old.retired_at is not null and new.retired_at is distinct from old.retired_at) then
      raise exception 'a federation key is retired, never rewritten' using errcode = '55000';
    end if;
  elsif tg_table_name = 'identity_status_outbox' then
    if row(new.event_id, new.target_installation_id, new.issuer, new.subject, new.revision,
           new.status, new.issued_at, new.valid_until, new.body)
       is distinct from row(old.event_id, old.target_installation_id, old.issuer, old.subject,
           old.revision, old.status, old.issued_at, old.valid_until, old.body) then
      raise exception 'an issued assertion is never rewritten' using errcode = '55000';
    end if;
  elsif tg_table_name = 'federation_inbox_receipts' then
    raise exception 'a receipt is never rewritten' using errcode = '55000';
  elsif tg_table_name = 'identity_status_assertions' then
    if new.issuer <> old.issuer or new.subject <> old.subject
       or new.revision <= old.revision or old.status = 'erased' then
      raise exception 'an identity status only moves forward, and erased is final'
        using errcode = '55000';
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.protect_federation_history()
  from public, anon, authenticated, service_role;

-- 0574's hourly cleanup, restated whole: also settled identity status
-- assertions and staged snapshot pages. A fact that is not a tombstone, a
-- pending, sent or refused assertion and a recent row are never removed.
create or replace function public.federation_retention_purge()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_keep interval := public.federation_retention_interval();
  v_receipts int;
  v_statuses int;
  v_tombstones int;
  v_pages int;
begin
  perform set_config('deskilo.federation_retention', 'on', true);
  delete from public.federation_inbox_receipts where received_at <= now() - v_keep;
  get diagnostics v_receipts = row_count;
  delete from public.identity_status_outbox
   where state in ('delivered', 'expired') and valid_until <= now() - v_keep
     and coalesce(delivered_at, valid_until) <= now() - v_keep;
  get diagnostics v_statuses = row_count;
  perform set_config('deskilo.federation_retention', '', true);
  delete from public.membership_facts
   where status = 'tombstone' and received_at <= now() - v_keep;
  get diagnostics v_tombstones = row_count;
  delete from public.membership_snapshot_pages where received_at <= now() - v_keep;
  get diagnostics v_pages = row_count;
  return jsonb_build_object('receipts', v_receipts, 'identity_statuses', v_statuses,
    'tombstones', v_tombstones, 'snapshot_pages', v_pages);
end;
$fn$;
revoke execute on function public.federation_retention_purge()
  from public, anon, authenticated, service_role;

create index if not exists identity_status_outbox_settled
  on public.identity_status_outbox (valid_until) where state in ('delivered', 'expired');

-- ── the snapshot tick ────────────────────────────────────────────────
do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-membership-snapshot-tick')
    where exists (select 1 from cron.job where jobname = 'deskilo-membership-snapshot-tick');
  perform cron.schedule('deskilo-membership-snapshot-tick', '* * * * *',
    $job$select public.membership_snapshot_issue(); select public.membership_snapshot_drain()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs membership_snapshot_issue() and membership_snapshot_drain() instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9999);
