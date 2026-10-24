-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one nullable column and its check on membership_facts, two
-- indexes, one platform setting, two new functions and one pg_cron job.
-- Restated whole: protect_federation_history (0568), membership_fact_enqueue,
-- membership_fact_apply and my_personal_workspace_refs_v1 (0569). No
-- existing row is rewritten.
--
-- #2563 C2, second checkpoint -- the workspace's name on its facts, and the
-- retention of what the backchannel leaves behind.
--
-- Names:
--   * W asserts, with every non-tombstone fact, the workspace's display name
--     as it holds it (`workspace_name`, 1..120 characters, no control
--     character: the workspaces.name rule). A tombstone carries none. A
--     renewal re-asserts the current name, so a rename reaches the home
--     within one `identity.status_reconcile_seconds`.
--   * P decodes it strictly: a name that is not such a string makes the
--     whole fact `malformed`; an absent or null name is the protocol-1 fact
--     without one. The name is presentation, not the relationship: the
--     same revision renews with a new name, never with another status.
--   * `my_personal_workspace_refs_v1` shows, for a workspace of another
--     installation, the name its own fact asserted -- only to the person the
--     fact is about, only while it names a relationship (not a tombstone)
--     and only while its source is enrolled under the epoch it arrived
--     under. A favourite, default or audience reference without a fact
--     still has no name. A local workspace keeps 0566's rule.
--
-- Retention (`federation.retention_hours`, platform, 24 h, 1..720):
--   * `federation_retention_purge()` -- hourly through pg_cron -- removes
--     receipts in `federation_inbox_receipts` and, at a personal home,
--     tombstones in `membership_facts` received longer ago than
--     `federation_retention_interval()`: the setting, and never less than
--     the registry's LARGEST assertion lifetime plus twice its largest skew.
--     By then any message the receipt or the tombstone answers is refused
--     on its own deadline (`expired_assertion`), so a replay or a late,
--     older active fact cannot revive anything.
--   * `protect_federation_history` (restated) still refuses every delete,
--     except a receipt removed by that purge (the transaction-local marker
--     `deskilo.federation_retention`) AND older than the interval. Keys,
--     identity assertions and the identity outbox keep their history.
--   * The W high-water (`membership_fact_state`) is kept for ever, a
--     tombstone included: it is one row per relationship ever bound.
--
-- Full-snapshot reconciliation (per-source watermark and verified
-- manifest) is the next checkpoint; nothing here removes a fact that is
-- not a tombstone.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('federation.retention_hours', 'duration', '24'::jsonb, 1, 720, 'hours', 'security', array['platform'], 'workspaceSettings', 1, true, null, 'federation_retention_purge (#2563)', 'Hours a server keeps the receipt of a signed backchannel message, and a personal home the tombstone of an ended membership, before the hourly cleanup removes them. Never shorter than the longest assertion lifetime plus twice the clock skew, so a replayed or late message still finds what refuses it.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── P: the asserted name ─────────────────────────────────────────────
alter table public.membership_facts add column if not exists workspace_name text;
alter table public.membership_facts drop constraint if exists membership_facts_workspace_name;
alter table public.membership_facts add constraint membership_facts_workspace_name
  check (workspace_name is null
         or (status <> 'tombstone' and char_length(workspace_name) between 1 and 120
             and workspace_name !~ '[[:cntrl:]]'));
comment on column public.membership_facts.workspace_name is
  '#2563 C2 -- the workspace''s display name as its own installation asserted it '
  'with this fact; none on a tombstone. Shown only to the person the fact is about.';

create index if not exists federation_inbox_receipts_received
  on public.federation_inbox_receipts (received_at);
create index if not exists membership_facts_tombstone_received
  on public.membership_facts (received_at) where status = 'tombstone';

-- ── retention ────────────────────────────────────────────────────────
-- How long a receipt and a tombstone are kept: the setting, never less than
-- what a message they answer could still be honoured for.
create or replace function public.federation_retention_interval()
returns interval language sql stable security definer set search_path = public as $fn$
  select make_interval(secs => (greatest(
    (public.setting_value(null, 'federation.retention_hours') #>> '{}')::int * 3600,
    (select d.max_value from public.setting_definitions d
      where d.key = 'identity.status_assertion_lifetime_seconds')
    + 2 * (select d.max_value from public.setting_definitions d
            where d.key = 'identity.clock_skew_seconds')))::double precision);
$fn$;
revoke execute on function public.federation_retention_interval()
  from public, anon, authenticated, service_role;

-- 0568's guard, restated whole: the only delete it lets through is the
-- purge's, of a receipt older than the retention interval.
create or replace function public.protect_federation_history()
returns trigger language plpgsql set search_path = '' as $fn$
begin
  if tg_op = 'DELETE' then
    -- Each table's fields are read only on its own branch.
    if tg_table_name = 'federation_inbox_receipts'
       and coalesce(current_setting('deskilo.federation_retention', true), '') = 'on' then
      if old.received_at <= now() - public.federation_retention_interval() then
        return old;
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

-- The hourly cleanup: receipts everywhere, tombstones at a personal home.
-- A fact that is not a tombstone is never removed here.
create or replace function public.federation_retention_purge()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_keep interval := public.federation_retention_interval();
  v_receipts int;
  v_tombstones int;
begin
  perform set_config('deskilo.federation_retention', 'on', true);
  delete from public.federation_inbox_receipts where received_at <= now() - v_keep;
  get diagnostics v_receipts = row_count;
  perform set_config('deskilo.federation_retention', '', true);
  delete from public.membership_facts
   where status = 'tombstone' and received_at <= now() - v_keep;
  get diagnostics v_tombstones = row_count;
  return jsonb_build_object('receipts', v_receipts, 'tombstones', v_tombstones);
end;
$fn$;
revoke execute on function public.federation_retention_purge()
  from public, anon, authenticated, service_role;

-- ── W: a fact names its workspace (0569's, restated whole) ───────────
create or replace function public.membership_fact_enqueue(p_state public.membership_fact_state)
returns int language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_home record;
  v_event uuid := gen_random_uuid();
  v_until timestamptz := now() + make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
  v_name text;
begin
  select * into v_home from public.membership_fact_home();
  if v_home.home_installation_id is null then
    return 0;
  end if;
  -- The name as this installation holds it; a tombstone carries none, and a
  -- name the home would refuse is left out rather than sinking the fact.
  if p_state.status <> 'tombstone' then
    select w.name into v_name from public.workspaces w
     where w.network_id = p_state.network_id
       and char_length(w.name) between 1 and 120 and w.name !~ '[[:cntrl:]]';
  end if;
  insert into public.membership_fact_outbox (event_id, target_installation_id, issuer, subject,
    network_id, revision, status, asserted_at, valid_until, body)
  values (v_event, v_home.home_installation_id, p_state.issuer, p_state.subject, p_state.network_id,
    p_state.revision, p_state.status, now(), v_until,
    jsonb_build_object('protocol', 1, 'kind', 'membership_fact', 'event_id', v_event,
      'source_installation_id', public.installation_id(),
      'target_installation_id', v_home.home_installation_id,
      'issuer', p_state.issuer, 'subject', p_state.subject, 'network_id', p_state.network_id,
      'revision', p_state.revision, 'status', p_state.status,
      'asserted_at', now(), 'valid_until', v_until)
    || case when v_name is not null then jsonb_build_object('workspace_name', v_name)
            else '{}'::jsonb end);
  update public.membership_fact_state set last_asserted_at = now()
   where issuer = p_state.issuer and subject = p_state.subject and network_id = p_state.network_id;
  return 1;
end;
$fn$;
revoke execute on function public.membership_fact_enqueue(public.membership_fact_state)
  from public, anon, authenticated, service_role;

-- ── P: receive the name (0569's, restated whole) ─────────────────────
create or replace function public.membership_fact_apply(
  p_body jsonb, p_source uuid, p_event uuid, p_request_ts bigint)
returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_skew interval := make_interval(secs =>
    (public.setting_value(null, 'identity.clock_skew_seconds') #>> '{}')::int);
  v_lifetime interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
  v_issuer text;
  v_user uuid;
  v_ref text;
  v_status text;
  v_revision bigint;
  v_issued timestamptz;
  v_until timestamptz;
  v_epoch timestamptz;
  v_name text;
  v_current public.membership_facts;
begin
  begin
    v_issuer := p_body->>'issuer';
    v_user := (p_body->>'subject')::uuid;
    v_ref := p_body->>'network_id';
    v_status := p_body->>'status';
    v_revision := (p_body->>'revision')::bigint;
    v_issued := (p_body->>'asserted_at')::timestamptz;
    v_until := (p_body->>'valid_until')::timestamptz;
  exception when others then
    return 'malformed';
  end;
  -- The name is optional; when present it is a string the workspaces.name
  -- rule admits, or the fact is not one this home understands.
  if coalesce(jsonb_typeof(p_body->'workspace_name'), 'null') <> 'null' then
    if jsonb_typeof(p_body->'workspace_name') <> 'string' then
      return 'malformed';
    end if;
    v_name := p_body->>'workspace_name';
    if char_length(v_name) not between 1 and 120 or v_name ~ '[[:cntrl:]]' then
      return 'malformed';
    end if;
  end if;
  if p_body->>'kind' is distinct from 'membership_fact' or p_body->>'protocol' is distinct from '1'
     or p_body->>'event_id' is distinct from p_event::text
     or p_body->>'source_installation_id' is distinct from p_source::text
     or p_body->>'target_installation_id' is distinct from public.installation_id()::text
     or v_issuer is null or v_user is null
     or v_status is null or v_status not in ('active', 'paused', 'pending', 'exited', 'tombstone')
     or coalesce(v_revision, 0) < 1 or v_issued is null or v_until is null or v_until <= v_issued
     or not coalesce(public.workspace_network_ref_valid(v_ref), false) then
    return 'malformed';
  end if;
  -- A tombstone keeps no name.
  if v_status = 'tombstone' then
    v_name := null;
  end if;
  -- A workspace installation speaks for its own workspaces only.
  if split_part(v_ref, ':', 1) <> p_source::text then
    return 'foreign_workspace';
  end if;
  -- The subject is a person of THIS home's own identity.
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
  perform pg_advisory_xact_lock(hashtextextended('membership_fact:' || v_user || ':' || v_ref, 2563));
  select * into v_current from public.membership_facts
   where user_id = v_user and network_id = v_ref for update;
  -- Linked: the person consented to the source. A tombstone only narrows,
  -- so it also lands on a fact already held.
  if not exists (select 1 from auth.users u where u.id = v_user)
     or (not (p_source in (select t from public.identity_status_linked_targets(v_user) t))
         and (v_status <> 'tombstone' or v_current.revision is null)) then
    return 'unlinked_subject';
  end if;
  if v_current.revision is null then
    insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
      revision, status, asserted_at, valid_until, enrolment_epoch, event_id, workspace_name)
    values (v_user, v_ref, v_issuer, p_source, v_revision, v_status, v_issued, v_until, v_epoch,
      p_event, v_name);
    return 'applied';
  end if;
  if v_revision < v_current.revision then
    return 'superseded';
  end if;
  if v_revision = v_current.revision then
    if v_status <> v_current.status or p_source <> v_current.source_installation_id then
      return 'revision_conflict';
    end if;
    if v_issued <= v_current.asserted_at then
      return 'superseded';
    end if;
    update public.membership_facts
       set asserted_at = v_issued, valid_until = v_until, enrolment_epoch = v_epoch,
           event_id = p_event, received_at = now(), workspace_name = v_name
     where user_id = v_user and network_id = v_ref;
    return 'renewed';
  end if;
  update public.membership_facts
     set issuer = v_issuer, source_installation_id = p_source, revision = v_revision,
         status = v_status, asserted_at = v_issued, valid_until = v_until,
         enrolment_epoch = v_epoch, event_id = p_event, received_at = now(),
         workspace_name = v_name
   where user_id = v_user and network_id = v_ref;
  return 'applied';
end;
$fn$;
revoke execute on function public.membership_fact_apply(jsonb, uuid, uuid, bigint)
  from public, anon, authenticated, service_role;

-- ── P: my references name a remote workspace by its own fact ─────────
-- 0569's reader, restated whole. A local workspace keeps 0566's label rule;
-- another installation's workspace is named by the caller's own fact while
-- it names a relationship and its source is enrolled under the same epoch.
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
               'label', case when split_part(x.ref, ':', 1) = v_home
                             then (case when m.status is not null or w.visibility_set_at is not null
                                        then w.name end)
                             when f.status is not null and f.status <> 'tombstone'
                                  and exists (select 1 from public.enrolled_installations e
                                               where e.installation_id = f.source_installation_id
                                                 and e.enabled and e.enrolled_at = f.enrolment_epoch)
                             then f.workspace_name end,
               'status', coalesce(m.status, nullif(f.status, 'tombstone')),
               'freshness', case when split_part(x.ref, ':', 1) = v_home then 'local'
                                 when f.status is null then 'unavailable'
                                 when public.membership_fact_in_force(v_me, x.ref, array[f.status])
                                   then 'verified'
                                 else 'stale' end,
               'is_default', x.ref = (select p.default_workspace_network_id
                                        from public.profiles p where p.id = v_me),
               'is_favorite', exists (select 1 from public.workspace_favorites f2
                                       where f2.user_id = v_me and f2.workspace_network_id = x.ref),
               'audience_fields', coalesce((select jsonb_agg(s.field order by s.field)
                                              from public.account_field_audience_spaces s
                                             where s.user_id = v_me
                                               and s.workspace_network_id = x.ref), '[]'::jsonb))
             order by x.ref)
        from (select w0.network_id as ref
                from public.members m0 join public.workspaces w0 on w0.id = m0.workspace_id
               where m0.user_id = v_me
              union
              select f0.network_id from public.membership_facts f0
               where f0.user_id = v_me and f0.status <> 'tombstone'
              union
              select f1.workspace_network_id from public.workspace_favorites f1 where f1.user_id = v_me
              union
              select s.workspace_network_id from public.account_field_audience_spaces s where s.user_id = v_me
              union
              select p.default_workspace_network_id from public.profiles p
               where p.id = v_me and p.default_workspace_network_id is not null) x
        left join public.workspaces w on w.network_id = x.ref
        left join public.membership_facts f on f.user_id = v_me and f.network_id = x.ref
        left join lateral (select m1.status from public.members m1
                            where m1.workspace_id = w.id and m1.user_id = v_me
                            order by case m1.status when 'active' then 0 when 'paused' then 1
                                                    when 'pending' then 2 else 3 end
                            limit 1) m on true), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.my_personal_workspace_refs_v1() from public, anon;
grant execute on function public.my_personal_workspace_refs_v1() to authenticated;

-- ── the hourly cleanup ───────────────────────────────────────────────
do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-federation-retention')
    where exists (select 1 from cron.job where jobname = 'deskilo-federation-retention');
  perform cron.schedule('deskilo-federation-retention', '17 * * * *',
    $job$select public.federation_retention_purge()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs federation_retention_purge() instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(574);
