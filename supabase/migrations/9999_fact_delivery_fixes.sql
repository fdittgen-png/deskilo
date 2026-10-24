-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one platform setting and two new functions. Restated whole:
-- identity_status_drain (0568), membership_fact_reconcile and
-- membership_fact_drain (0569), membership_snapshot_drain (0576). No
-- existing row is rewritten.
--
-- #2563 C2 -- three delivery defects of the backchannel.
--
-- 1. A retry of a refused event was booked as delivered. When the first
--    answer never reached the sender (pg_net lost it, or it came after the
--    wait), the sender posts the same event again and the receiver answers
--    `duplicate` with the outcome it gave the first time (`first_outcome`,
--    which `federation-inbox` now forwards). A drain books a duplicate
--    whose first outcome is a refusal (`federation_outcome_refused`: every
--    outcome but the inbox's successes) as refused, for that first reason;
--    a duplicate of a success, or one without a first outcome (an older
--    receiver), stays delivered. All three drains share the inbox, so all
--    three book it the same way.
-- 2. `membership_fact_reconcile` tombstoned and renewed relationships of
--    every issuer it ever held, so after the trusted authority changed it
--    kept enqueueing facts of the old issuer, which the home refuses
--    (`wrong_issuer`). Both loops now take only the current issuer's rows,
--    like the re-derivation loop above them; the old rows stay as the
--    high-water.
-- 3. The wait for an answer before a sent message goes back to pending was
--    a literal two minutes in each drain. It is the platform setting
--    `federation.answer_wait_seconds` (120 s, 30..600), read through
--    `federation_answer_wait()`.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('federation.answer_wait_seconds', 'duration', '120'::jsonb, 30, 600, 'seconds', 'security', array['platform'], 'workspaceSettings', 30, true, null, 'backchannel drains (#2563)', 'Seconds a server waits for the answer to a signed backchannel message (identity status, membership fact, membership snapshot) before it sends the same message again. At least 30: one attempt times out after 10 seconds. Keep it below the assertion lifetime, or a message lapses before its retry.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- Whether an inbox outcome is a final refusal. The inbox answers 2xx for
-- exactly these successes; anything else, an unknown outcome included, was
-- never a success.
create or replace function public.federation_outcome_refused(p_outcome text)
returns boolean language sql immutable set search_path = public as $fn$
  select p_outcome is not null
     and p_outcome not in ('applied', 'renewed', 'staged', 'reconciled', 'duplicate', 'superseded');
$fn$;
revoke execute on function public.federation_outcome_refused(text)
  from public, anon, authenticated, service_role;

-- How long a drain waits for the answer to a sent message.
create or replace function public.federation_answer_wait()
returns interval language sql stable security definer set search_path = public as $fn$
  select make_interval(secs =>
    (public.setting_value(null, 'federation.answer_wait_seconds') #>> '{}')::int);
$fn$;
revoke execute on function public.federation_answer_wait()
  from public, anon, authenticated, service_role;

-- ── P: deliver (0568's, restated whole) ──────────────────────────────
create or replace function public.identity_status_drain()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.identity_status_outbox;
  v_target public.enrolled_installations;
  v_code int;
  v_content text;
  v_timed_out boolean;
  v_found int;
  v_outcome text;
  v_first text;
  v_wait interval := public.federation_answer_wait();
  v_headers jsonb;
  v_sent int := 0;
  v_settled int := 0;
begin
  -- 1. the answers to earlier attempts
  if to_regclass('net._http_response') is not null then
    for v_row in select * from public.identity_status_outbox
                  where state = 'sent' order by issued_at for update skip locked loop
      execute 'select status_code, content, timed_out from net._http_response where id = $1'
        into v_code, v_content, v_timed_out using v_row.net_request_id;
      get diagnostics v_found = row_count;
      begin
        v_outcome := v_content::jsonb->>'outcome';
        v_first := v_content::jsonb->>'first_outcome';
      exception when others then
        v_outcome := null;
        v_first := null;
      end;
      if v_found = 0 then
        -- No answer yet; pg_net answers or times out well within a minute.
        if v_row.last_attempt_at < now() - v_wait then
          update public.identity_status_outbox set state = 'pending', outcome = 'no_answer'
           where event_id = v_row.event_id;
        end if;
        continue;
      end if;
      if v_code between 200 and 299 and v_outcome = 'duplicate'
         and public.federation_outcome_refused(v_first) then
        -- A retry of an event the receiver refused the first time: it
        -- stays refused, for the first reason, never delivered.
        update public.identity_status_outbox
           set state = 'refused', outcome = v_first
         where event_id = v_row.event_id;
      elsif v_code between 200 and 299 then
        update public.identity_status_outbox
           set state = 'delivered', delivered_at = now(), outcome = coalesce(v_outcome, 'delivered')
         where event_id = v_row.event_id;
      elsif v_code in (400, 409, 421, 422) then
        update public.identity_status_outbox
           set state = 'refused', outcome = coalesce(v_outcome, 'http_' || v_code)
         where event_id = v_row.event_id;
      else
        update public.identity_status_outbox
           set state = 'pending',
               outcome = coalesce(v_outcome, case when coalesce(v_timed_out, false)
                                                  then 'timeout' else 'http_' || v_code end)
         where event_id = v_row.event_id;
      end if;
      v_settled := v_settled + 1;
    end loop;
  end if;
  -- 2. what lapsed undelivered: every older assertion has lapsed with it
  update public.identity_status_outbox set state = 'expired'
   where state in ('pending', 'sent') and valid_until <= now();
  -- 3. send
  if to_regprocedure('net.http_post(text, jsonb, jsonb, jsonb, integer)') is null then
    return jsonb_build_object('settled', v_settled, 'sent', 0, 'transport', 'unavailable');
  end if;
  for v_row in select * from public.identity_status_outbox
                where state = 'pending' order by issued_at limit 200 for update skip locked loop
    select * into v_target from public.enrolled_installations
     where installation_id = v_row.target_installation_id;
    if not coalesce(v_target.enabled, false) then
      update public.identity_status_outbox set state = 'refused', outcome = 'target_revoked'
       where event_id = v_row.event_id;
      continue;
    end if;
    begin
      v_headers := public.federation_envelope_headers('identity_status',
        v_row.target_installation_id, v_row.event_id, '/federation-inbox', v_row.body);
    exception when sqlstate 'P0002' then
      update public.identity_status_outbox set outcome = 'no_outbound_key'
       where event_id = v_row.event_id;
      continue;
    end;
    update public.identity_status_outbox
       set state = 'sent', attempts = attempts + 1, last_attempt_at = now(),
           net_request_id = net.http_post(
             url := v_target.origin || '/functions/v1/federation-inbox',
             body := v_row.body,
             headers := v_headers || jsonb_build_object('Content-Type', 'application/json',
                                                        'apikey', v_target.publishable_key),
             timeout_milliseconds := 10000)
     where event_id = v_row.event_id;
    v_sent := v_sent + 1;
  end loop;
  return jsonb_build_object('settled', v_settled, 'sent', v_sent);
end;
$fn$;
revoke execute on function public.identity_status_drain()
  from public, anon, authenticated, service_role;

-- ── W: reconcile (0569's, restated whole) ───────────────────────────
create or replace function public.membership_fact_reconcile()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_issuer text;
  v_every interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_reconcile_seconds') #>> '{}')::int);
  v_pair record;
  v_state public.membership_fact_state;
  v_changed int := 0;
  v_renewed int := 0;
begin
  select issuer into v_issuer from public.identity_authority where kind = 'oidc';
  if v_issuer is null then
    return jsonb_build_object('changed', 0, 'renewed', 0, 'authority', 'native');
  end if;
  for v_pair in
    select m.workspace_id, m.user_id from public.members m
      join public.identity_bindings b on b.local_user_id = m.user_id
       and b.installation_id = public.installation_id() and b.issuer = v_issuer
    union
    select split_part(s.network_id, ':', 2)::uuid, b.local_user_id
      from public.membership_fact_state s
      join public.identity_bindings b on b.issuer = s.issuer and b.subject = s.subject
       and b.installation_id = public.installation_id()
     where s.issuer = v_issuer and s.status <> 'tombstone' loop
    v_changed := v_changed + public.membership_fact_produce(v_pair.workspace_id, v_pair.user_id);
  end loop;
  for v_state in select s.* from public.membership_fact_state s
                  where s.issuer = v_issuer and s.status <> 'tombstone'
                    and not exists (select 1 from public.identity_bindings b
                                     where b.issuer = s.issuer and b.subject = s.subject
                                       and b.installation_id = public.installation_id()) loop
    update public.membership_fact_state
       set revision = nextval('public.membership_fact_revision'), status = 'tombstone',
           last_asserted_at = null
     where issuer = v_state.issuer and subject = v_state.subject and network_id = v_state.network_id
    returning * into v_state;
    v_changed := v_changed + public.membership_fact_enqueue(v_state);
  end loop;
  for v_state in select s.* from public.membership_fact_state s
                  where s.issuer = v_issuer
                    and ((s.status <> 'tombstone'
                          and (s.last_asserted_at is null or s.last_asserted_at <= now() - v_every))
                         or (s.status = 'tombstone' and s.last_asserted_at is null)) loop
    v_renewed := v_renewed + public.membership_fact_enqueue(v_state);
  end loop;
  return jsonb_build_object('changed', v_changed, 'renewed', v_renewed);
end;
$fn$;
revoke execute on function public.membership_fact_reconcile()
  from public, anon, authenticated, service_role;

-- ── W: deliver facts (0569's, restated whole) ───────────────────────
create or replace function public.membership_fact_drain()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.membership_fact_outbox;
  v_home record;
  v_code int;
  v_content text;
  v_timed_out boolean;
  v_found int;
  v_outcome text;
  v_first text;
  v_wait interval := public.federation_answer_wait();
  v_headers jsonb;
  v_sent int := 0;
  v_settled int := 0;
begin
  -- 1. the answers to earlier attempts
  if to_regclass('net._http_response') is not null then
    for v_row in select * from public.membership_fact_outbox
                  where state = 'sent' order by asserted_at for update skip locked loop
      execute 'select status_code, content, timed_out from net._http_response where id = $1'
        into v_code, v_content, v_timed_out using v_row.net_request_id;
      get diagnostics v_found = row_count;
      begin
        v_outcome := v_content::jsonb->>'outcome';
        v_first := v_content::jsonb->>'first_outcome';
      exception when others then
        v_outcome := null;
        v_first := null;
      end;
      if v_found = 0 then
        if v_row.last_attempt_at < now() - v_wait then
          update public.membership_fact_outbox set state = 'pending', outcome = 'no_answer'
           where event_id = v_row.event_id;
        end if;
        continue;
      end if;
      if v_code between 200 and 299 and v_outcome = 'duplicate'
         and public.federation_outcome_refused(v_first) then
        -- A retry of an event the receiver refused the first time: it
        -- stays refused, for the first reason, never delivered.
        update public.membership_fact_outbox
           set state = 'refused', outcome = v_first
         where event_id = v_row.event_id;
      elsif v_code between 200 and 299 then
        update public.membership_fact_outbox
           set state = 'delivered', delivered_at = now(), outcome = coalesce(v_outcome, 'delivered')
         where event_id = v_row.event_id;
      elsif v_code in (400, 409, 421, 422) then
        update public.membership_fact_outbox
           set state = 'refused', outcome = coalesce(v_outcome, 'http_' || v_code)
         where event_id = v_row.event_id;
      else
        update public.membership_fact_outbox
           set state = 'pending',
               outcome = coalesce(v_outcome, case when coalesce(v_timed_out, false)
                                                  then 'timeout' else 'http_' || v_code end)
         where event_id = v_row.event_id;
      end if;
      v_settled := v_settled + 1;
    end loop;
  end if;
  -- 2. what lapsed undelivered, and what can no longer matter
  update public.membership_fact_outbox set state = 'expired'
   where state in ('pending', 'sent') and valid_until <= now();
  delete from public.membership_fact_outbox
   where state in ('delivered', 'refused', 'expired') and valid_until <= now();
  -- 3. send
  if to_regprocedure('net.http_post(text, jsonb, jsonb, jsonb, integer)') is null then
    return jsonb_build_object('settled', v_settled, 'sent', 0, 'transport', 'unavailable');
  end if;
  select * into v_home from public.membership_fact_home();
  for v_row in select * from public.membership_fact_outbox
                where state = 'pending' order by asserted_at limit 200 for update skip locked loop
    if v_row.target_installation_id is distinct from v_home.home_installation_id then
      update public.membership_fact_outbox set state = 'refused', outcome = 'home_changed'
       where event_id = v_row.event_id;
      continue;
    end if;
    begin
      v_headers := public.federation_envelope_headers('membership_fact',
        v_row.target_installation_id, v_row.event_id, '/federation-inbox', v_row.body);
    exception when sqlstate 'P0002' then
      update public.membership_fact_outbox set outcome = 'no_outbound_key'
       where event_id = v_row.event_id;
      continue;
    end;
    update public.membership_fact_outbox
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
revoke execute on function public.membership_fact_drain()
  from public, anon, authenticated, service_role;

-- ── W: deliver snapshot pages (0576's, restated whole) ──────────────
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
  v_first text;
  v_wait interval := public.federation_answer_wait();
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
        v_first := v_content::jsonb->>'first_outcome';
      exception when others then
        v_outcome := null;
        v_first := null;
      end;
      if v_found = 0 then
        if v_row.last_attempt_at < now() - v_wait then
          update public.membership_snapshot_outbox set state = 'pending', outcome = 'no_answer'
           where event_id = v_row.event_id;
        end if;
        continue;
      end if;
      if v_code between 200 and 299 and v_outcome = 'duplicate'
         and public.federation_outcome_refused(v_first) then
        -- A retry of an event the receiver refused the first time: it
        -- stays refused, for the first reason, never delivered.
        update public.membership_snapshot_outbox
           set state = 'refused', outcome = v_first
         where event_id = v_row.event_id;
      elsif v_code between 200 and 299 then
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

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9999);
