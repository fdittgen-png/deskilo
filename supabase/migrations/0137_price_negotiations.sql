-- SPDX-License-Identifier: 0BSD
--
-- #739 PRICE NEGOTIATIONS — the workspace tariff becomes the DEFAULT,
-- and a member may have their own deal on top of it: a monthly fee, an
-- overage rate per half-day, a discount on the supplements (accessories,
-- level/office/desk reservations) — each optional, the band's value
-- where absent. The statement applies the ACTIVE deal and reports the
-- default beside it, so the member reads what they negotiated against
-- what everyone else pays.
--
-- WHO. A deal is PROPOSED by an owner or an admin with the finance
-- permission, for another member, and lands as a pending
-- `price_negotiation` event: the validation rules (default or the
-- domain's own — scope, count, owner sign-off, 0017/0135) decide; on
-- confirmation the deal becomes active and supersedes the previous one.
-- Nobody validates their own proposal (0086).
--
-- WHO SEES. The member, the owners, and admins with the finance
-- permission (may_view_member_finances, 0131). Every read by someone
-- other than the member is written to data_access_log under
-- 'negotiations', so the member sees who could look and who did (#719).

-- ---------------------------------------------------------------- table
create table public.price_negotiations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  fee_cents int check (fee_cents is null or fee_cents >= 0),
  overage_fee_cents int check (overage_fee_cents is null or overage_fee_cents >= 0),
  discount_percent numeric(5,2) check (discount_percent is null or (discount_percent >= 0 and discount_percent <= 100)),
  note text not null default '' check (char_length(note) <= 500),
  valid_from date not null,
  status text not null default 'pending'
    check (status in ('pending','active','rejected','superseded')),
  event_id uuid references public.events(id) on delete set null,
  proposed_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  check (fee_cents is not null or overage_fee_cents is not null or discount_percent is not null)
);
create index price_negotiations_member_idx on public.price_negotiations (member_id, status);
create unique index price_negotiations_one_active
  on public.price_negotiations (member_id) where status = 'active';
create unique index price_negotiations_one_pending
  on public.price_negotiations (member_id) where status = 'pending';

alter table public.price_negotiations enable row level security;
create policy price_negotiations_select on public.price_negotiations
  for select using (public.may_view_member_finances(member_id));
-- No write policies: writes only through the RPC and the event trigger.

-- ---------------------------------------------------------------- events + policies
alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check check (type in
  ('reservation','payment','expense','adjustment','service_charge',
   'quota','role_change','member_join','space_reservation',
   'invoice_payment','reservation_delete','invoice_writeoff',
   'invoice_reminder','price_negotiation'));
alter table public.validation_policies
  drop constraint validation_policies_event_type_check;
alter table public.validation_policies
  add constraint validation_policies_event_type_check check (
    event_type is null or event_type in (
      'reservation','payment','expense','adjustment','service_charge',
      'quota','role_change','member_join','space_reservation',
      'invoice_payment','reservation_delete','invoice_writeoff',
      'price_negotiation'));

-- ---------------------------------------------------------------- access log category
alter table public.data_access_log drop constraint if exists data_access_log_category_check;
alter table public.data_access_log add constraint data_access_log_category_check
  check (category in ('finances', 'messages', 'export', 'negotiations'));

-- ---------------------------------------------------------------- the band, for context
-- The workspace default for a member: their band's fee and overage.
create or replace function public.default_tariff_of(p_member_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(
    (select jsonb_build_object('fee_cents', b.fee_cents, 'overage_fee_cents', b.overage_fee_cents)
       from public.members m
       join public.fee_bands b on b.workspace_id = m.workspace_id
        and b.from_pct < coalesce(m.subscription_pct, 100)
        and coalesce(m.subscription_pct, 100) <= b.to_pct
      where m.id = p_member_id
      limit 1),
    jsonb_build_object('fee_cents', 0, 'overage_fee_cents', 0));
$$;
revoke execute on function public.default_tariff_of(uuid) from public, anon;
grant execute on function public.default_tariff_of(uuid) to authenticated;

-- ---------------------------------------------------------------- propose
create or replace function public.propose_price_negotiation(
  p_member_id uuid,
  p_fee_cents int default null,
  p_overage_fee_cents int default null,
  p_discount_percent numeric default null,
  p_note text default '',
  p_valid_from date default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_actor public.members;
  v_valid_from date;
  v_event_id uuid;
  v_id uuid;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  select * into v_actor from public.members
    where workspace_id = v_member.workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if not (v_actor.is_owner or public.has_permission(v_member.workspace_id, 'viewFinances')) then
    raise exception 'only the owner or a finance admin may propose a deal';
  end if;
  if v_actor.id = v_member.id then
    raise exception 'a deal is proposed for someone else';
  end if;
  if not coalesce((select w.feature_flags ->> 'priceNegotiations' from public.workspaces w
                    where w.id = v_member.workspace_id)::boolean, true) then
    raise exception 'price negotiations are off in this workspace';
  end if;
  if p_fee_cents is null and p_overage_fee_cents is null and p_discount_percent is null then
    raise exception 'nothing negotiated';
  end if;
  if exists (select 1 from public.price_negotiations
              where member_id = p_member_id and status = 'pending') then
    raise exception 'a proposal is already awaiting validation';
  end if;
  v_valid_from := coalesce(p_valid_from, date_trunc('month', now())::date);

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    v_member.workspace_id, 'price_negotiation', 'submitted', v_actor.id, v_member.id,
    jsonb_build_object(
      'fee_cents', p_fee_cents,
      'overage_fee_cents', p_overage_fee_cents,
      'discount_percent', p_discount_percent,
      'note', coalesce(p_note, ''),
      'valid_from', v_valid_from,
      'default', public.default_tariff_of(p_member_id)),
    'pending')
  returning id into v_event_id;

  insert into public.price_negotiations
    (workspace_id, member_id, fee_cents, overage_fee_cents, discount_percent,
     note, valid_from, status, event_id, proposed_by)
  values (v_member.workspace_id, v_member.id, p_fee_cents, p_overage_fee_cents,
          p_discount_percent, coalesce(p_note, ''), v_valid_from, 'pending',
          v_event_id, v_actor.id)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.propose_price_negotiation(uuid, int, int, numeric, text, date) from public, anon;
grant execute on function public.propose_price_negotiation(uuid, int, int, numeric, text, date) to authenticated;

-- ---------------------------------------------------------------- decide → activate
create or replace function public.apply_negotiation_on_decision()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type <> 'price_negotiation' or new.status = old.status then return new; end if;
  if new.status = 'confirmed' then
    update public.price_negotiations set status = 'superseded', decided_at = now()
     where member_id = new.subject_member_id and status = 'active';
    update public.price_negotiations set status = 'active', decided_at = now()
     where event_id = new.id and status = 'pending';
  elsif new.status in ('rejected', 'expired') then
    update public.price_negotiations set status = 'rejected', decided_at = now()
     where event_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;
drop trigger if exists events_apply_negotiation on public.events;
create trigger events_apply_negotiation
  after update of status on public.events
  for each row execute function public.apply_negotiation_on_decision();

-- ---------------------------------------------------------------- read, logged
-- The member's deal as the app shows it: default, active, pending. A
-- read by anyone but the member is on the record.
create or replace function public.member_price_negotiation(p_member_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_member public.members;
  v_me public.members;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  if not public.may_view_member_finances(p_member_id) then
    raise exception 'not allowed to see this member''s deal';
  end if;
  select * into v_me from public.members
    where workspace_id = v_member.workspace_id and user_id = auth.uid() and status = 'active';
  if v_me.id is not null and v_me.id <> v_member.id then
    insert into public.data_access_log
      (workspace_id, actor_member_id, subject_member_id, category)
    values (v_member.workspace_id, v_me.id, v_member.id, 'negotiations');
  end if;
  return jsonb_build_object(
    'default', public.default_tariff_of(p_member_id),
    'active', (select to_jsonb(n) from public.price_negotiations n
                where n.member_id = p_member_id and n.status = 'active'),
    'pending', (select to_jsonb(n) from public.price_negotiations n
                 where n.member_id = p_member_id and n.status = 'pending'));
end;
$$;
revoke execute on function public.member_price_negotiation(uuid) from public, anon;
grant execute on function public.member_price_negotiation(uuid) to authenticated;

-- ---------------------------------------------------------------- who can see me
do $$
declare
  v_def text;
  v_old text := $o$    'reservations', 'all_members',$o$;
  v_new text := $n$    'negotiations', (
      select coalesce(jsonb_agg(m.id), '[]'::jsonb) from public.members m
       where m.workspace_id = p_workspace_id and m.status = 'active' and m.id <> v_me.id
         and (m.is_owner or m.co_owner = 'active' or m.is_admin)
    ),
    'reservations', 'all_members',$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'who_can_access_me';
  if v_def is null then raise exception 'who_can_access_me missing'; end if;
  if position(v_old in v_def) = 0 then raise exception 'who_can_access_me anchor not found'; end if;
  execute replace(v_def, v_old, v_new);
end $$;

-- ---------------------------------------------------------------- statement v13
-- The active deal overrides the band; the discount trims the
-- supplements; the JSON carries default + negotiated for the UI.
do $$
declare
  v_def text;
  v_old_band text := $o$  if v_band.id is not null then
    v_base := v_band.fee_cents;
    v_overage_rate := v_band.overage_fee_cents;
  end if;$o$;
  v_new_band text := $n$  if v_band.id is not null then
    v_base := v_band.fee_cents;
    v_overage_rate := v_band.overage_fee_cents;
  end if;
  -- #739 — the member's own deal, when active for this month.
  declare
    v_neg public.price_negotiations;
    v_default_fee int := v_base;
    v_default_overage int := v_overage_rate;
  begin
    select * into v_neg from public.price_negotiations n
     where n.member_id = p_member_id and n.status = 'active'
       and n.valid_from <= v_month_first;
    if v_neg.id is not null then
      if v_neg.fee_cents is not null then v_base := v_neg.fee_cents; end if;
      if v_neg.overage_fee_cents is not null then v_overage_rate := v_neg.overage_fee_cents; end if;
    end if;
    v_negotiated := jsonb_build_object(
      'default_fee_cents', v_default_fee,
      'default_overage_fee_cents', v_default_overage,
      'fee_cents', v_neg.fee_cents,
      'overage_fee_cents', v_neg.overage_fee_cents,
      'discount_percent', v_neg.discount_percent,
      'valid_from', v_neg.valid_from,
      'active', v_neg.id is not null);
    v_discount := coalesce(v_neg.discount_percent, 0);
  end;$n$;
  v_old_ret text := $o$    'overage_policy', coalesce(v_member.overage_policy, 'blocked'),
    'overage_rate_cents', v_overage_rate,$o$;
  v_new_ret text := $n$    'negotiated', v_negotiated,
    'overage_policy', coalesce(v_member.overage_policy, 'blocked'),
    'overage_rate_cents', v_overage_rate,$n$;
  v_old_bal text := $o$    'balance_cents',
      v_credits - v_base - v_overage - v_supplement - v_level_supplement
        - v_office_supplement - v_desk_supplement,$o$;
  v_new_bal text := $n$    'balance_cents',
      v_credits - v_base - v_overage - v_supplement - v_level_supplement
        - v_office_supplement - v_desk_supplement,
    'discount_percent', v_discount,$n$;
  v_old_decl text := $o$  v_overage_rate int := 0;$o$;
  v_new_decl text := $n$  v_overage_rate int := 0;
  v_negotiated jsonb := '{}'::jsonb;
  v_discount numeric := 0;$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'member_statement';
  if v_def is null then raise exception 'member_statement missing'; end if;
  if position(v_old_band in v_def) = 0 then raise exception 'band anchor not found'; end if;
  if position(v_old_ret in v_def) = 0 then raise exception 'return anchor not found'; end if;
  if position(v_old_bal in v_def) = 0 then raise exception 'balance anchor not found'; end if;
  if position(v_old_decl in v_def) = 0 then raise exception 'declare anchor not found'; end if;
  v_def := replace(v_def, v_old_decl, v_new_decl);
  v_def := replace(v_def, v_old_band, v_new_band);
  v_def := replace(v_def, v_old_ret, v_new_ret);
  v_def := replace(v_def, v_old_bal, v_new_bal);
  execute v_def;
end $$;

-- The discount on the supplements: applied where they are summed is
-- four different places; applying it once, on the way out, is the same
-- arithmetic and one anchor. The four supplement variables are rounded
-- AFTER the discount, on the returned figures.
do $$
declare
  v_def text;
  v_old text := $o$  return jsonb_build_object(
    'period', p_period,$o$;
  v_new text := $n$  if v_discount > 0 then
    v_supplement := round(v_supplement * (100 - v_discount) / 100)::int;
    v_level_supplement := round(v_level_supplement * (100 - v_discount) / 100)::int;
    v_office_supplement := round(v_office_supplement * (100 - v_discount) / 100)::int;
    v_desk_supplement := round(v_desk_supplement * (100 - v_discount) / 100)::int;
  end if;
  return jsonb_build_object(
    'period', p_period,$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'member_statement';
  if position(v_old in v_def) = 0 then raise exception 'discount anchor not found'; end if;
  execute replace(v_def, v_old, v_new);
end $$;
