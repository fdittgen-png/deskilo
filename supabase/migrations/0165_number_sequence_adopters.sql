-- SPDX-License-Identifier: 0BSD
-- 0165 — #928: three documents that carried no number take one from the
-- framework of 0164.
--
--   member          M-0001        drawn when a membership is created —
--                                 the owner's own at create_workspace, a
--                                 join, a managed profile — and frozen
--                                 into every invoice's buyer party as
--                                 "N° adhérent". Existing members are
--                                 numbered in join order so nobody's
--                                 number is younger than a newer member's.
--   vat_declaration DECL-2026-0001 drawn the moment a declaration is
--                                 FILED (a draft is not a document yet);
--                                 already-filed ones are numbered in
--                                 filing order per workspace-year.
--   payment         PAY-2026-0001 drawn inside the intent's own insert by
--                                 open_payment_intent, which the
--                                 create-payment-order function calls
--                                 instead of inserting itself — so the
--                                 reference the provider shows the payer
--                                 is the one the treasurer reconciles.
--
-- Each journal has its own defaults (number_sequence_defaults): a member
-- number never resets and carries no year; the others follow the invoice.
-- Both lazy paths (drawing and previewing) take them, so an owner who
-- never opened the settings screen still gets sensible series.
alter table public.members add column if not exists member_number text not null default '';
alter table public.vat_declarations add column if not exists number text not null default '';
alter table public.payment_intents add column if not exists reference text not null default '';

create or replace function public.number_sequence_defaults(p_journal text)
returns table(prefix text, date_part text, reset text) language sql immutable as $$
  select case p_journal when 'invoice' then 'INV-' when 'credit_note' then 'CN-'
                        when 'vat_declaration' then 'DECL-' when 'member' then 'M-'
                        when 'payment' then 'PAY-' else '' end,
         case p_journal when 'member' then 'none' else 'year' end,
         case p_journal when 'member' then 'never' else 'yearly' end;
$$;

create or replace function public.next_document_number(p_workspace_id uuid, p_journal text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare v_seq public.number_sequences; v_key text; v_value bigint;
begin
  insert into public.number_sequences (workspace_id, journal, prefix, date_part, reset)
  select p_workspace_id, p_journal, d.prefix, d.date_part, d.reset from public.number_sequence_defaults(p_journal) d
  on conflict (workspace_id, journal) do nothing;
  select * into v_seq from public.number_sequences
   where workspace_id = p_workspace_id and journal = p_journal for update;
  v_key := public.number_sequence_period_key(p_workspace_id, v_seq.reset);
  if v_seq.period_key <> v_key then
    v_value := 1;
    update public.number_sequences set period_key = v_key, next_value = 2
     where workspace_id = p_workspace_id and journal = p_journal;
  else
    v_value := v_seq.next_value;
    update public.number_sequences set next_value = next_value + 1
     where workspace_id = p_workspace_id and journal = p_journal;
  end if;
  return public.number_sequence_format(p_workspace_id, v_seq, v_value);
end;
$$;

create or replace function public.preview_document_number(p_workspace_id uuid, p_journal text)
returns text language plpgsql stable security definer set search_path = public as $$
declare v_seq public.number_sequences; v_key text;
begin
  if not public.is_member_of(p_workspace_id) then raise exception 'not a member'; end if;
  select * into v_seq from public.number_sequences
   where workspace_id = p_workspace_id and journal = p_journal;
  if not found then
    select d.prefix, d.date_part, d.reset into v_seq.prefix, v_seq.date_part, v_seq.reset
      from public.number_sequence_defaults(p_journal) d;
    v_seq.suffix := ''; v_seq.digits := 4; v_seq.period_key := ''; v_seq.next_value := 1;
  end if;
  v_key := public.number_sequence_period_key(p_workspace_id, v_seq.reset);
  return public.number_sequence_format(p_workspace_id, v_seq,
    case when v_seq.period_key = v_key then v_seq.next_value else 1 end);
end;
$$;

with numbered as (
  select id, row_number() over (partition by workspace_id order by joined_at, id) rn from public.members
)
update public.members m set member_number = 'M-' || lpad(n.rn::text, 4, '0')
  from numbered n where n.id = m.id and m.member_number = '';
insert into public.number_sequences (workspace_id, journal, prefix, date_part, digits, reset, period_key, next_value)
select w.id, 'member', 'M-', 'none', 4, 'never', '',
       coalesce((select count(*) from public.members m where m.workspace_id = w.id), 0) + 1
  from public.workspaces w
on conflict (workspace_id, journal) do nothing;

with numbered as (
  select d.id, to_char(d.submitted_at at time zone coalesce(w.timezone,'UTC'), 'YYYY') yr,
         row_number() over (partition by d.workspace_id, to_char(d.submitted_at at time zone coalesce(w.timezone,'UTC'), 'YYYY')
                            order by d.submitted_at, d.id) rn
    from public.vat_declarations d join public.workspaces w on w.id = d.workspace_id
   where d.status = 'submitted'
)
update public.vat_declarations d set number = 'DECL-' || n.yr || '-' || lpad(n.rn::text, 4, '0')
  from numbered n where n.id = d.id and d.number = '';
insert into public.number_sequences (workspace_id, journal, prefix, date_part, digits, reset, period_key, next_value)
select w.id, 'vat_declaration', 'DECL-', 'year', 4, 'yearly',
       to_char(now() at time zone coalesce(w.timezone,'UTC'), 'YYYY'),
       coalesce((select count(*) from public.vat_declarations d
                  where d.workspace_id = w.id and d.status = 'submitted'
                    and to_char(d.submitted_at at time zone coalesce(w.timezone,'UTC'), 'YYYY')
                      = to_char(now() at time zone coalesce(w.timezone,'UTC'), 'YYYY')), 0) + 1
  from public.workspaces w
on conflict (workspace_id, journal) do nothing;

create or replace function public.open_payment_intent(
  p_workspace_id uuid, p_member_id uuid, p_provider text, p_period text, p_amount_cents int, p_currency text)
returns table(id uuid, reference text) language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := gen_random_uuid(); v_ref text;
begin
  v_ref := public.next_document_number(p_workspace_id, 'payment');
  -- (provider, order_id) is unique; until the provider answers, the
  -- intent's own id stands in for the order id it does not have yet.
  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference)
  values (v_id, p_workspace_id, p_member_id, p_provider, 'pending:' || v_id::text, p_period, p_amount_cents, p_currency, v_ref);
  return query select v_id, v_ref;
end;
$$;
revoke execute on function public.open_payment_intent(uuid, uuid, text, text, int, text) from public, anon, authenticated;
grant execute on function public.open_payment_intent(uuid, uuid, text, text, int, text) to service_role;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_workspace';
  v_old := E'  insert into public.members (workspace_id, user_id, is_admin, is_owner)\n  values (ws_id, auth.uid(), true, true);\n';
  if position(v_old in v_def) = 0 then raise exception '0165: create_workspace anchor missing'; end if;
  execute replace(v_def, v_old, v_old || E'  update public.members set member_number = public.next_document_number(ws_id, ''member'')\n    where workspace_id = ws_id and user_id = auth.uid();\n');

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='join_workspace';
  v_old := E'          is_admin = public.members.is_admin or excluded.is_admin\n    returning id into v_member_id;\n';
  if position(v_old in v_def) = 0 then raise exception '0165: join_workspace anchor missing'; end if;
  execute replace(v_def, v_old, v_old || E'  update public.members set member_number = public.next_document_number(ws_id, ''member'')\n    where id = v_member_id and member_number = '''';\n');

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_managed_member';
  v_old := E'          public.managed_identity_name(v_identity))\n  returning id into v_id;\n';
  if position(v_old in v_def) = 0 then raise exception '0165: create_managed_member anchor missing'; end if;
  execute replace(v_def, v_old, v_old || E'  update public.members set member_number = public.next_document_number(p_workspace_id, ''member'')\n    where id = v_id and member_number = '''';\n');

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_invoice';
  v_old := E'      ''legal_id'', v_member_legal,\n';
  if position(v_old in v_def) = 0 then raise exception '0165: create_invoice anchor missing'; end if;
  execute replace(v_def, v_old, v_old || E'      ''member_number'', coalesce(v_subject.member_number, ''''),\n');

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mark_vat_declaration_submitted';
  v_old := E'     set status = ''submitted'',\n';
  if position(v_old in v_def) = 0 then raise exception '0165: mark_vat_declaration_submitted anchor missing'; end if;
  execute replace(v_def, v_old, v_old || E'         number = case when number = '''' then public.next_document_number(workspace_id, ''vat_declaration'') else number end,\n');
end
$patch$;
