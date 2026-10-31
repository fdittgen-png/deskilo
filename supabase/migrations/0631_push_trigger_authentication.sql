-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- All push callers use one Vault-backed authentication boundary.
create or replace function public.push_delivery_headers(p_anon_key text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare v_secret text;
begin
  select decrypted_secret into v_secret from vault.decrypted_secrets
   where name = 'deskilo_push_shared_secret';
  return jsonb_build_object(
    'Authorization','Bearer ' || p_anon_key,
    'Content-Type','application/json') ||
    case when nullif(v_secret,'') is null then '{}'::jsonb
      else jsonb_build_object('x-deskilo-push-secret',v_secret) end;
end;
$fn$;
revoke execute on function public.push_delivery_headers(text) from public,anon,authenticated;
grant execute on function public.push_delivery_headers(text) to service_role;


CREATE OR REPLACE FUNCTION public.notify_pending_event() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_kind text;
  v_cfg public.push_config;
begin
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status <> 'pending') then
    v_kind := 'pending_request';
  elsif new.type = 'reservation' and new.action = 'cancelled'
     and new.actor_member_id <> new.subject_member_id
     and (tg_op = 'INSERT'
          or old.actor_member_id = old.subject_member_id) then
    v_kind := 'reservation_cancelled';
  end if;
  if v_kind is not null then
    select * into v_cfg from public.push_config where id;
    if v_cfg.functions_url is not null then
      begin
        perform net.http_post(
          url := v_cfg.functions_url || '/send-push',
          headers := public.push_delivery_headers(v_cfg.anon_key),
          body := jsonb_build_object('event_id', new.id),
          timeout_milliseconds := 5000
        );
      exception when others then
        null;  -- best-effort: push must never fail the event
      end;
    end if;
  end if;
  return new;
end;
$$;

CREATE OR REPLACE FUNCTION public.notify_member_note() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_cfg public.push_config;
begin
  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is not null then
    begin
      perform net.http_post(
        url := v_cfg.functions_url || '/send-push',
        headers := public.push_delivery_headers(v_cfg.anon_key),
        body := jsonb_build_object('note_id', new.id),
        timeout_milliseconds := 5000
      );
    exception when others then
      null;  -- best-effort: push must never fail the note
    end;
  end if;
  return new;
end;
$$;

CREATE OR REPLACE FUNCTION public.reminder_queue_push(p_intent_id uuid, p_event_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_cfg public.push_config;
  v_ws uuid;
  v_request bigint;
begin
  select workspace_id into v_ws from public.reminder_intents where id = p_intent_id;
  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is null then
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, detail)
    values (v_ws, p_intent_id, 'push', 'failed', 'push delivery is not configured on this installation');
    update public.reminder_intents set status = 'failed'
     where id = p_intent_id and status = 'prepared';
    return;
  end if;
  begin
    v_request := net.http_post(
      url := v_cfg.functions_url || '/send-push',
      headers := public.push_delivery_headers(v_cfg.anon_key),
      body := jsonb_build_object('event_id', p_event_id),
      timeout_milliseconds := 5000);
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, net_request_id)
    values (v_ws, p_intent_id, 'push', 'queued', v_request);
    update public.reminder_intents set status = 'queued'
     where id = p_intent_id and status = 'prepared';
  exception when others then
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, detail)
    values (v_ws, p_intent_id, 'push', 'failed', 'the push request could not be queued');
    update public.reminder_intents set status = 'failed'
     where id = p_intent_id and status = 'prepared';
  end;
end $$;

CREATE OR REPLACE FUNCTION public.reconcile_reminder_attempts() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_a record;
  v_resp record;
  v_outcome text;
  v_detail text;
  v_count int := 0;
begin
  for v_a in
    select a.* from public.reminder_attempts a
     where a.outcome = 'queued'
       and not exists (select 1 from public.reminder_attempts b
                        where b.intent_id = a.intent_id and b.channel = a.channel
                          and b.outcome <> 'queued' and b.at >= a.at)
     order by a.at
     for update skip locked
  loop
    select r.status_code, r.timed_out, r.error_msg, r.content into v_resp
      from net._http_response r where r.id = v_a.net_request_id;
    if not found then
      if v_a.at > now() - interval '1 hour' then continue; end if;
      v_outcome := 'unknown';
      v_detail := 'the push queue gave no answer within an hour';
    elsif v_resp.status_code = 202 then
      v_outcome := 'unknown';
      v_detail := 'the push request was accepted; device delivery is not disclosed';
    elsif v_resp.status_code between 200 and 299
          and coalesce(v_resp.content, '') ~ '"sent"\s*:\s*[1-9]' then
      v_outcome := 'provider_accepted';
      v_detail := 'the push service accepted it for at least one device; not proof of receipt';
    elsif v_resp.status_code between 200 and 299 then
      v_outcome := 'failed';
      v_detail := 'no device could receive it';
    else
      v_outcome := 'failed';
      v_detail := 'the push request failed';
    end if;
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, net_request_id, detail)
    values (v_a.workspace_id, v_a.intent_id, v_a.channel, v_outcome, v_a.net_request_id, v_detail);
    update public.reminder_intents set status = v_outcome
     where id = v_a.intent_id and status in ('prepared', 'queued');
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- Restating a caller also restates its service-only execution boundary.
revoke execute on function public.notify_pending_event() from public, anon, authenticated;
grant execute on function public.notify_pending_event() to service_role;
revoke execute on function public.notify_member_note() from public, anon, authenticated;
grant execute on function public.notify_member_note() to service_role;
revoke execute on function public.reminder_queue_push(uuid, uuid) from public, anon, authenticated;
grant execute on function public.reminder_queue_push(uuid, uuid) to service_role;
revoke execute on function public.reconcile_reminder_attempts() from public, anon, authenticated;
grant execute on function public.reconcile_reminder_attempts() to service_role;

select public.set_deskilo_schema_version(631);
