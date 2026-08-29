-- SPDX-License-Identifier: 0BSD
--
-- #726 — AUTOMATIC payment reminders. The dunning rules (0093: levels,
-- first_after_days, between_days) were a policy the owner applied by
-- hand, one tap per invoice. Now a daily sweep applies them: an OPEN
-- invoice whose waiting period has run gets its next reminder level
-- recorded, an `invoice_reminder` event lands in the member's feed (and
-- in the finance admins' feed, who see every event), and the push goes
-- out through the same send-push function the pending requests use.
--
-- WHY A SWEEP AND NOT A TRIGGER. Nothing happens on the invoice when
-- time passes; only a clock can notice a term has run. pg_cron runs the
-- sweep every morning; an owner or admin opening Finances runs it too
-- (idempotent: the rules decide, not the caller), so a project where
-- cron is not allowed still reminds — a day later at worst.
--
-- WHAT IS "OPEN". No match row at all (0067): a matched invoice — even
-- pending validation, even under-accepted — is in someone's hands.
-- Voided invoices are never reminded. The clock for level 1 starts at
-- issued_at; every further level waits between_days after the previous
-- reminder — exactly dueReminderLevel() on the client.
--
-- THE OWNER'S SWITCH. dunning_rules.automatic (default true) turns the
-- sweep off per workspace without touching the levels; the feature flag
-- paymentReminders (child of dunning) hides the whole thing.

alter table public.invoice_reminders
  add column if not exists automatic boolean not null default false,
  add column if not exists level int not null default 1;

alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check check (type in
  ('reservation','payment','expense','adjustment','service_charge',
   'quota','role_change','member_join','space_reservation',
   'invoice_payment','reservation_delete','invoice_writeoff',
   'invoice_reminder'));

-- One workspace's sweep. Returns how many reminders it recorded.
create or replace function public.sweep_payment_reminders(
  p_workspace_id uuid default null
) returns int language plpgsql security definer set search_path = public as $$
declare
  v_ws record;
  v_inv record;
  v_rules jsonb;
  v_levels int;
  v_first int;
  v_between int;
  v_count int;
  v_last timestamptz;
  v_since timestamptz;
  v_wait int;
  v_level int;
  v_owner uuid;
  v_event_id uuid;
  v_cfg public.push_config;
  v_total int := 0;
begin
  -- A signed-in caller may only sweep a workspace they administer; the
  -- scheduler (no auth.uid()) sweeps every workspace.
  if auth.uid() is not null then
    if p_workspace_id is null then
      raise exception 'workspace required';
    end if;
    if not public.is_admin_of(p_workspace_id) then
      raise exception 'not an admin of this workspace';
    end if;
  end if;

  for v_ws in
    select w.id, w.dunning_rules, w.feature_flags
      from public.workspaces w
     where (p_workspace_id is null or w.id = p_workspace_id)
       -- dunning on (default on), paymentReminders on (default on),
       -- and the owner's switch not off.
       and coalesce((w.feature_flags ->> 'dunning')::boolean, true)
       and coalesce((w.feature_flags ->> 'invoicing')::boolean, true)
       and coalesce((w.feature_flags ->> 'moneyTab')::boolean, true)
       and coalesce((w.feature_flags ->> 'paymentReminders')::boolean, true)
       and coalesce((w.dunning_rules ->> 'automatic')::boolean, true)
  loop
    v_rules := coalesce(v_ws.dunning_rules, '{}'::jsonb);
    v_levels := least(greatest(coalesce((v_rules ->> 'levels')::int, 3), 1), 9);
    v_first := least(greatest(coalesce((v_rules ->> 'first_after_days')::int, 14), 1), 365);
    v_between := least(greatest(coalesce((v_rules ->> 'between_days')::int, 14), 1), 365);
    select id into v_owner from public.members
      where workspace_id = v_ws.id and is_owner and status = 'active'
      limit 1;
    if v_owner is null then continue; end if;

    for v_inv in
      select i.id, i.number, i.member_id, i.issued_at, i.total_cents, i.currency
        from public.invoices i
       where i.workspace_id = v_ws.id
         and i.voided_at is null
         and i.total_cents > 0
         and not exists (select 1 from public.invoice_matches m
                          where m.invoice_id = i.id)
    loop
      select count(*), max(sent_at) into v_count, v_last
        from public.invoice_reminders r where r.invoice_id = v_inv.id;
      if v_count >= v_levels then continue; end if;
      v_since := case when v_count = 0 then v_inv.issued_at else coalesce(v_last, v_inv.issued_at) end;
      v_wait := case when v_count = 0 then v_first else v_between end;
      if now() - v_since < make_interval(days => v_wait) then continue; end if;
      v_level := v_count + 1;

      insert into public.invoice_reminders (workspace_id, invoice_id, by_name, automatic, level)
      values (v_ws.id, v_inv.id, '', true, v_level);

      insert into public.events
        (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
      values
        (v_ws.id, 'invoice_reminder', 'created', v_owner, v_inv.member_id,
         jsonb_build_object(
           'invoice_id', v_inv.id,
           'number', v_inv.number,
           'level', v_level,
           'levels', v_levels,
           'amount_cents', v_inv.total_cents,
           'currency', v_inv.currency,
           'issued_at', v_inv.issued_at,
           'days_overdue', greatest(0, (extract(epoch from now() - v_inv.issued_at) / 86400)::int - v_first),
           'automatic', true),
         'applied')
      returning id into v_event_id;

      -- Push, best-effort, the 0084 way.
      select * into v_cfg from public.push_config where id;
      if v_cfg.functions_url is not null then
        begin
          perform net.http_post(
            url := v_cfg.functions_url || '/send-push',
            headers := jsonb_build_object(
              'Authorization', 'Bearer ' || v_cfg.anon_key,
              'Content-Type', 'application/json'),
            body := jsonb_build_object('event_id', v_event_id),
            timeout_milliseconds := 5000);
        exception when others then
          null;
        end;
      end if;
      v_total := v_total + 1;
    end loop;
  end loop;
  return v_total;
end;
$$;
revoke execute on function public.sweep_payment_reminders(uuid) from public, anon;
grant execute on function public.sweep_payment_reminders(uuid) to authenticated;

-- The morning sweep. Best-effort: a project without pg_cron keeps the
-- client-side sweep (Finances opened by an admin).
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-payment-reminders')
    where exists (select 1 from cron.job where jobname = 'deskilo-payment-reminders');
  perform cron.schedule('deskilo-payment-reminders', '15 6 * * *',
    $job$select public.sweep_payment_reminders()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): the client-side sweep stays the only clock', sqlerrm;
end $$;
