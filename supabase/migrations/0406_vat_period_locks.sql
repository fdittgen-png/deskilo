-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0406 (#2357) — a filed VAT period is locked; what changes in it later
-- is declared as a correction in the next return (ADR 0039).
--
-- A filed return never changes (0402). Until now that was all: an
-- invoice of a filed September voided in October simply vanished from
-- September's recomputation, and no later return declared the
-- difference.
--
-- 1. `vat_return_entries` records what each filed return declared, per
--    document, tax point, rate and category — written once, by the
--    filing, under the filing's writer token; never updated, never
--    deleted except with its workspace or return.
-- 2. `vat_return_lines` is the return of a period with the locks
--    applied: the period's own tax points that no filed return covers,
--    and, for every filed period that ended before it, the difference
--    between what that period's tax points amount to now and what the
--    filed returns declared for them. Those differences are CORRECTION
--    lines naming the filed return they correct (FR CA3 lines 15/21,
--    DE § 17 UStG in the period of the change, UK error correction on
--    the next return).
-- 3. `compute_vat_return` returns the correction flag and the corrected
--    return; `save_vat_declaration` stores the correction lines beside
--    the period's own and refuses a period that overlaps a filed one;
--    `mark_vat_declaration_submitted` records the entries, so the same
--    correction is declared once.
-- 4. A return filed before this migration is locked with the ledger as
--    it stands now: what changed between its filing and today cannot be
--    told apart any more and is not corrected.

-- ============================================================ the ledger
create table public.vat_return_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  declaration_id uuid not null references public.vat_declarations(id)
    on delete cascade,
  invoice_id uuid not null,
  tax_point date not null,
  percent numeric not null,
  category text not null default '',
  credit_note boolean not null default false,
  correction boolean not null default false,
  gross_cents bigint not null,
  net_cents bigint not null
);
select public.ensure_system_columns('vat_return_entries');
create index vat_return_entries_period
  on public.vat_return_entries (workspace_id, tax_point);
create index vat_return_entries_declaration
  on public.vat_return_entries (declaration_id);

alter table public.vat_return_entries enable row level security;
revoke all on public.vat_return_entries from public, anon, authenticated;
grant select on public.vat_return_entries to authenticated;
-- Read: whoever reads the declarations (0216). Written only by the filing.
create policy vat_return_entries_select on public.vat_return_entries
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances'])));
create policy mcp_delegated_deny on public.vat_return_entries as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- A return filed before 0406: its period is locked with what its tax
-- points amount to today. An earlier filed return keeps the tax points
-- two filed periods share.
insert into public.vat_return_entries
    (workspace_id, declaration_id, invoice_id, tax_point, percent, category,
     credit_note, gross_cents, net_cents)
select d.workspace_id, d.id, a.invoice_id, a.tax_point, a.percent, a.category,
       a.credit_note, sum(a.gross_cents)::bigint, sum(a.net_cents)::bigint
  from public.vat_declarations d
  cross join lateral public.vat_return_amounts(d.workspace_id, d.period_start, d.period_end) a
 where d.status = 'filed'
   and not exists (
     select 1 from public.vat_declarations p
      where p.workspace_id = d.workspace_id and p.status = 'filed' and p.id <> d.id
        and a.tax_point between p.period_start and p.period_end
        and (coalesce(p.submitted_at, p.created_at), p.id)
            < (coalesce(d.submitted_at, d.created_at), d.id))
 group by d.workspace_id, d.id, a.invoice_id, a.tax_point, a.percent, a.category,
          a.credit_note;

-- Written once, by the filing that names its return; never changed.
-- A cascade (the return or the workspace going) is the only delete.
create or replace function public.vat_return_entries_guard()
returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'INSERT' then
    if coalesce(current_setting('deskilo.vat_return_writer', true), '')
       <> 'file:' || new.declaration_id then
      raise exception 'what a VAT return declared is recorded only by its filing';
    end if;
    return new;
  end if;
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 then
    return old;
  end if;
  raise exception 'what a filed VAT return declared is immutable';
end;
$fn$;
revoke execute on function public.vat_return_entries_guard() from public, anon, authenticated;

create trigger vat_return_entries_guard
  before insert or update or delete on public.vat_return_entries
  for each row execute function public.vat_return_entries_guard();

-- ============================================================ the return
-- The period's amounts with the locks applied: its own tax points that
-- no filed return of another period covers (a filed period itself reads
-- what its tax points amount to today), then the corrections of every
-- filed period
-- that ended before it — per document, tax point, rate and category,
-- what the tax points amount to now minus what was declared for them.
create or replace function public.vat_return_lines(
  p_workspace_id uuid, p_start date, p_end date
) returns table (invoice_id uuid, tax_point date, percent numeric,
                 category text, credit_note boolean, correction boolean,
                 corrects uuid, gross_cents bigint, net_cents bigint)
language sql stable security definer set search_path = public as $fn$
  with locks as (
    select d.id, d.period_start, d.period_end,
           coalesce(d.submitted_at, d.created_at) as filed_at
      from public.vat_declarations d
     where d.workspace_id = p_workspace_id and d.status = 'filed'
  ), earlier as (
    select l.* from locks l where l.period_end < p_start
  ), span as (
    select min(e.period_start) as s, max(e.period_end) as e from earlier e
  ), ledger as (
    select a.invoice_id, a.tax_point, a.percent, a.category, a.credit_note,
           a.gross_cents, a.net_cents
      from span
      cross join lateral public.vat_return_amounts(p_workspace_id, span.s, span.e) a
     where span.s is not null
       and exists (select 1 from earlier l
                    where a.tax_point between l.period_start and l.period_end)
    union all
    select r.invoice_id, r.tax_point, r.percent, r.category, r.credit_note,
           -r.gross_cents, -r.net_cents
      from public.vat_return_entries r
     where r.workspace_id = p_workspace_id
       and exists (select 1 from earlier l
                    where r.tax_point between l.period_start and l.period_end)
  ), delta as (
    select g.invoice_id, g.tax_point, g.percent, g.category, g.credit_note,
           sum(g.gross_cents)::bigint as gross, sum(g.net_cents)::bigint as net
      from ledger g
     group by g.invoice_id, g.tax_point, g.percent, g.category, g.credit_note
    having sum(g.gross_cents) <> 0 or sum(g.net_cents) <> 0
  )
  select a.invoice_id, a.tax_point, a.percent, a.category, a.credit_note,
         false, null::uuid, a.gross_cents, a.net_cents
    from public.vat_return_amounts(p_workspace_id, p_start, p_end) a
   where not exists (select 1 from locks l
                      where a.tax_point between l.period_start and l.period_end
                        and (l.period_start, l.period_end) <> (p_start, p_end))
  union all
  select d.invoice_id, d.tax_point, d.percent, d.category, d.credit_note,
         true,
         (select l.id from earlier l
           where d.tax_point between l.period_start and l.period_end
           order by l.filed_at, l.id limit 1),
         d.gross, d.net
    from delta d;
$fn$;
revoke execute on function public.vat_return_lines(uuid, date, date)
  from public, anon, authenticated;

-- One row per (rate, category, tax point, credit note, correction): the
-- period's own lines, then the corrections naming the return they
-- correct. Same gate as 0402.
drop function if exists public.compute_vat_return(uuid, date, date);
create function public.compute_vat_return(
  p_workspace uuid, p_start date, p_end date
) returns table (percent numeric, category text, tax_point date,
                 credit_note boolean, correction boolean, corrects uuid,
                 gross_cents bigint, net_cents bigint, vat_cents bigint,
                 invoice_count int)
language plpgsql stable security definer set search_path = public as $fn$
#variable_conflict use_column
begin
  if p_workspace is null or not exists (
       select 1 from public.workspaces_permitting(array['viewFinances']) w
        where w = p_workspace) then
    raise exception 'not allowed to read this workspace''s VAT';
  end if;
  if p_start is null or p_end is null or p_end < p_start then
    raise exception 'invalid period';
  end if;
  return query
    select a.percent, a.category, a.tax_point, a.credit_note, a.correction,
           a.corrects,
           sum(a.gross_cents)::bigint, sum(a.net_cents)::bigint,
           (sum(a.gross_cents) - sum(a.net_cents))::bigint,
           count(distinct a.invoice_id)::int
      from public.vat_return_lines(p_workspace, p_start, p_end) a
     group by a.percent, a.category, a.tax_point, a.credit_note, a.correction,
              a.corrects
     order by a.correction, a.percent desc, a.category, a.tax_point,
              a.credit_note, a.corrects;
end;
$fn$;
revoke execute on function public.compute_vat_return(uuid, date, date) from public, anon;
grant execute on function public.compute_vat_return(uuid, date, date) to authenticated;

-- What a declaration stores: the period's own lines per (rate,
-- category) exactly as 0402 stored them, then one correction line per
-- (corrected return, rate, category) carrying the corrected period.
create or replace function public.vat_return_summary(
  p_workspace_id uuid, p_start date, p_end date
) returns table (lines jsonb, total_net_cents int, total_vat_cents int,
                 invoice_count int)
language sql stable security definer set search_path = public as $fn$
  with a as (
    select * from public.vat_return_lines(p_workspace_id, p_start, p_end)
  ), l as (
    select a.correction, a.corrects, a.percent, a.category,
           sum(a.gross_cents)::bigint as gross, sum(a.net_cents)::bigint as net,
           count(distinct a.invoice_id)::int as n
      from a group by a.correction, a.corrects, a.percent, a.category
  ), j as (
    select l.*, d.period_start as c_start, d.period_end as c_end
      from l left join public.vat_declarations d on d.id = l.corrects
  )
  select coalesce((select jsonb_agg(
                     jsonb_build_object(
                       'percent', j.percent, 'category', j.category,
                       'gross_cents', j.gross, 'net_cents', j.net,
                       'vat_cents', j.gross - j.net, 'invoice_count', j.n)
                     || case when j.correction then jsonb_build_object(
                          'correction', true, 'corrects', j.corrects,
                          'corrects_start', j.c_start, 'corrects_end', j.c_end)
                        else '{}'::jsonb end
                   order by j.correction, j.c_start, j.percent desc, j.category)
                     from j), '[]'::jsonb),
         coalesce((select sum(l.net) from l), 0)::int,
         coalesce((select sum(l.gross - l.net) from l), 0)::int,
         (select count(distinct a.invoice_id) from a)::int;
$fn$;
revoke execute on function public.vat_return_summary(uuid, date, date)
  from public, anon, authenticated;

-- Whether p_start..p_end overlaps a filed return of another period.
create or replace function public.vat_period_overlaps_filed(
  p_workspace_id uuid, p_start date, p_end date
) returns boolean
language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.vat_declarations d
     where d.workspace_id = p_workspace_id and d.status = 'filed'
       and d.period_start <= p_end and d.period_end >= p_start
       and (d.period_start, d.period_end) is distinct from (p_start, p_end));
$fn$;
revoke execute on function public.vat_period_overlaps_filed(uuid, date, date)
  from public, anon, authenticated;

-- ============================================================ the writers
-- 0402's save, refusing a period that overlaps a filed one.
create or replace function public.save_vat_declaration(
  p_workspace_id uuid,
  p_period_start date,
  p_period_end date,
  p_lines jsonb default null,
  p_total_net_cents int default null,
  p_total_vat_cents int default null,
  p_currency text default null,
  p_invoice_count int default null
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_existing public.vat_declarations;
  v_sum record;
  v_currency text;
  v_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_actor.id is null or not (v_actor.is_owner or coalesce(v_actor.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations';
  end if;
  if not public.workspace_charges_vat(p_workspace_id) then
    raise exception 'the workspace is not VAT registered';
  end if;
  if p_period_start is null or p_period_end is null
     or p_period_end < p_period_start then
    raise exception 'invalid period';
  end if;

  select * into v_existing from public.vat_declarations
    where workspace_id = p_workspace_id
      and period_start = p_period_start and period_end = p_period_end
    for update;
  if v_existing.status = 'filed' then
    raise exception 'declaration already filed for this period';
  end if;
  if public.vat_period_overlaps_filed(p_workspace_id, p_period_start, p_period_end) then
    raise exception 'this period overlaps a filed return: its changes are declared as corrections of the next period';
  end if;

  select * into v_sum
    from public.vat_return_summary(p_workspace_id, p_period_start, p_period_end);
  select coalesce(w.currency_code, '') into v_currency
    from public.workspaces w where w.id = p_workspace_id;

  if v_existing.id is not null then
    perform set_config('deskilo.vat_return_writer', 'compute:' || v_existing.id, true);
    update public.vat_declarations
       set status = 'prepared',
           lines = v_sum.lines,
           total_net_cents = v_sum.total_net_cents,
           total_vat_cents = v_sum.total_vat_cents,
           currency = v_currency,
           invoice_count = v_sum.invoice_count,
           created_at = now()
     where id = v_existing.id;
    perform set_config('deskilo.vat_return_writer', '', true);
    return v_existing.id;
  end if;

  v_id := gen_random_uuid();
  perform set_config('deskilo.vat_return_writer', 'compute:' || v_id, true);
  insert into public.vat_declarations
      (id, workspace_id, period_start, period_end, status, lines,
       total_net_cents, total_vat_cents, currency, invoice_count,
       created_by_name)
    values
      (v_id, p_workspace_id, p_period_start, p_period_end, 'prepared',
       v_sum.lines, v_sum.total_net_cents, v_sum.total_vat_cents,
       v_currency, v_sum.invoice_count,
       coalesce((select display_name from public.profiles
                  where id = auth.uid()), ''));
  perform set_config('deskilo.vat_return_writer', '', true);
  return v_id;
end;
$fn$;
revoke execute on function public.save_vat_declaration(
  uuid, date, date, jsonb, int, int, text, int) from public, anon;
grant execute on function public.save_vat_declaration(
  uuid, date, date, jsonb, int, int, text, int) to authenticated;

-- 0402's filing, which now records what the return declared — its own
-- tax points and the corrections it carries — so a period's change is
-- corrected once.
create or replace function public.mark_vat_declaration_submitted(
  p_declaration_id uuid,
  p_channel text,
  p_receipt text default ''
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_decl public.vat_declarations;
  v_actor public.members;
  v_sum record;
begin
  select * into v_decl from public.vat_declarations
    where id = p_declaration_id for update;
  if v_decl.id is null then raise exception 'unknown declaration'; end if;
  select * into v_actor from public.members
    where workspace_id = v_decl.workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_actor.id is null or not (v_actor.is_owner or coalesce(v_actor.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations';
  end if;
  if v_decl.status = 'filed' then
    raise exception 'declaration already filed';
  end if;
  if coalesce(p_channel, '') not in ('manual', 'export') then
    raise exception 'unknown channel: a VAT return is filed by its owner with the tax authority';
  end if;
  if btrim(coalesce(p_receipt, '')) = '' then
    raise exception 'the receipt reference the tax authority gave is required';
  end if;
  if v_decl.status <> 'prepared' then
    raise exception 'prepare the return before filing it';
  end if;
  if public.vat_period_overlaps_filed(v_decl.workspace_id, v_decl.period_start,
                                      v_decl.period_end) then
    raise exception 'this period overlaps a filed return: its changes are declared as corrections of the next period';
  end if;
  select * into v_sum
    from public.vat_return_summary(v_decl.workspace_id, v_decl.period_start,
                                   v_decl.period_end);
  if (v_sum.lines, v_sum.total_net_cents, v_sum.total_vat_cents, v_sum.invoice_count)
     is distinct from
     (v_decl.lines, v_decl.total_net_cents, v_decl.total_vat_cents, v_decl.invoice_count) then
    raise exception 'the period changed since this return was prepared: prepare it again';
  end if;
  perform set_config('deskilo.vat_return_writer', 'file:' || v_decl.id, true);
  insert into public.vat_return_entries
      (workspace_id, declaration_id, invoice_id, tax_point, percent, category,
       credit_note, correction, gross_cents, net_cents)
  select v_decl.workspace_id, v_decl.id, l.invoice_id, l.tax_point, l.percent,
         l.category, l.credit_note, l.correction,
         sum(l.gross_cents)::bigint, sum(l.net_cents)::bigint
    from public.vat_return_lines(v_decl.workspace_id, v_decl.period_start,
                                 v_decl.period_end) l
   group by l.invoice_id, l.tax_point, l.percent, l.category, l.credit_note,
            l.correction;
  update public.vat_declarations
     set status = 'filed',
         number = case when number = '' then public.next_document_number(workspace_id, 'vat_declaration') else number end,
         submitted_at = now(),
         submitted_channel = p_channel,
         submitted_receipt = left(btrim(p_receipt), 500)
   where id = p_declaration_id;
  perform set_config('deskilo.vat_return_writer', '', true);
end;
$fn$;
revoke execute on function public.mark_vat_declaration_submitted(
  uuid, text, text) from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(406);
