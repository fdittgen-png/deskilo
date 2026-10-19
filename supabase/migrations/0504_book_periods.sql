-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0504 (#2365) -- closing a book period, and the log of accounting exports.
--
-- A CLOSED period (a date range, closed by the owner, or by the filing of a
-- VAT return) refuses what would change the books inside it after the fact:
-- voiding an invoice issued inside it, and matching (or writing off) a
-- payment dated inside it. Corrections go to the open period: a credit note
-- today, not a void of last year. Reopening is the owner's too, needs a
-- reason and is kept on the row.
--
-- `book_exports` is the server's log of the files handed to an accountant:
-- format, period, sha256, bytes, rows, documents, by whom and when, and
-- whether the period was closed at the time (a closed period exported twice
-- must show one sha256).
--
--   close_book_period_v1 / reopen_book_period_v1   owner
--   record_book_export_v1                           exportData
--   book_periods_v1                                 owner / viewFinances / exportData
--
-- The guards hold whether or not the `accountingPeriods` flag is on: a period
-- that was closed stays closed. Closing and the log need the flag.

create table public.book_periods (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  period_from date not null,
  period_to date not null,
  reason text not null check (reason in ('owner', 'vat_filed')),
  closed_by_member_id uuid references public.members(id),
  closed_at timestamptz not null default now(),
  reopened_by_member_id uuid references public.members(id),
  reopened_at timestamptz,
  reopen_reason text not null default '' check (char_length(reopen_reason) <= 300),
  check (period_to >= period_from),
  check ((reopened_at is null) = (reopened_by_member_id is null)),
  -- two periods closed at once never overlap
  exclude using gist (workspace_id with =, daterange(period_from, period_to, '[]') with &&)
    where (reopened_at is null)
);
select public.ensure_system_columns('book_periods');
create index book_periods_workspace on public.book_periods (workspace_id, period_from);

create table public.book_exports (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  format_id text not null check (char_length(format_id) between 1 and 60),
  period_from date not null,
  period_to date not null,
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  byte_count bigint not null check (byte_count >= 0),
  row_count int not null check (row_count >= 0),
  document_count int not null check (document_count >= 0),
  closed_period boolean not null,
  exported_by_member_id uuid references public.members(id),
  exported_at timestamptz not null default now(),
  check (period_to >= period_from)
);
select public.ensure_system_columns('book_exports');
create index book_exports_workspace on public.book_exports (workspace_id, exported_at desc);

alter table public.book_periods enable row level security;
alter table public.book_exports enable row level security;
revoke all on public.book_periods, public.book_exports from public, anon, authenticated;
grant select on public.book_periods, public.book_exports to authenticated;
create policy book_periods_select on public.book_periods for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'exportData']))
         or public.is_owner_of(workspace_id));
create policy book_exports_select on public.book_exports for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'exportData']))
         or public.is_owner_of(workspace_id));
create policy mcp_delegated_deny on public.book_periods as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.book_exports as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── is a day inside a closed period? ──────────────────────────────────────
create or replace function public.book_period_closed(p_workspace_id uuid, p_day date)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.book_periods p
                  where p.workspace_id = p_workspace_id and p.reopened_at is null
                    and p_day between p.period_from and p.period_to);
$fn$;
revoke execute on function public.book_period_closed(uuid, date) from public, anon, authenticated;

create or replace function public.book_local_day(p_workspace_id uuid, p_at timestamptz)
returns date language sql stable security definer set search_path = public as $fn$
  select (p_at at time zone coalesce((select w.timezone from public.workspaces w where w.id = p_workspace_id), 'UTC'))::date;
$fn$;
revoke execute on function public.book_local_day(uuid, timestamptz) from public, anon, authenticated;

-- ── the guards ────────────────────────────────────────────────────────────
create or replace function public.book_period_void_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.voided_at is null and new.voided_at is not null
     and public.book_period_closed(new.workspace_id, public.book_local_day(new.workspace_id, new.issued_at)) then
    raise exception 'this invoice belongs to a closed period of the books: issue a credit note in the open period instead';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.book_period_void_guard() from public, anon, authenticated;
drop trigger if exists book_period_void_guard on public.invoices;
create trigger book_period_void_guard before update of voided_at on public.invoices
  for each row execute function public.book_period_void_guard();

create or replace function public.book_period_match_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_at timestamptz;
begin
  v_at := coalesce(new.writeoff_at, new.matched_at);
  if (tg_op = 'INSERT' or new.matched_at is distinct from old.matched_at
      or new.writeoff_at is distinct from old.writeoff_at or new.paid_cents is distinct from old.paid_cents)
     and public.book_period_closed(new.workspace_id, public.book_local_day(new.workspace_id, v_at)) then
    raise exception 'this payment is dated inside a closed period of the books: it is booked in the open period';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.book_period_match_guard() from public, anon, authenticated;
drop trigger if exists book_period_match_guard on public.invoice_matches;
create trigger book_period_match_guard before insert or update on public.invoice_matches
  for each row execute function public.book_period_match_guard();

-- ── a filed VAT return closes its period ──────────────────────────────────
create or replace function public.book_period_vat_close()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.status = 'filed' and old.status is distinct from 'filed'
     and public.feature_effective(new.workspace_id, 'accountingPeriods')
     and not exists (select 1 from public.book_periods p
                      where p.workspace_id = new.workspace_id and p.reopened_at is null
                        and daterange(p.period_from, p.period_to, '[]') && daterange(new.period_start, new.period_end, '[]')) then
    insert into public.book_periods (workspace_id, period_from, period_to, reason)
    values (new.workspace_id, new.period_start, new.period_end, 'vat_filed');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.book_period_vat_close() from public, anon, authenticated;
drop trigger if exists book_period_vat_close on public.vat_declarations;
create trigger book_period_vat_close after update of status on public.vat_declarations
  for each row execute function public.book_period_vat_close();

-- ── the commands ──────────────────────────────────────────────────────────
create or replace function public.book_actor(p_workspace_id uuid, p_owner boolean)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'accountingPeriods') then
    raise exception 'accounting periods are switched off in this space';
  end if;
  if p_owner and not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner closes or reopens a period';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.book_actor(uuid, boolean) from public, anon, authenticated;

create or replace function public.book_period_json(p public.book_periods)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('id', p.id, 'period_from', p.period_from, 'period_to', p.period_to,
    'reason', p.reason, 'closed_at', p.closed_at, 'reopened_at', p.reopened_at,
    'reopen_reason', p.reopen_reason);
$fn$;
revoke execute on function public.book_period_json(public.book_periods) from public, anon, authenticated;

create or replace function public.close_book_period_v1(p_workspace_id uuid, p_from date, p_to date)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  p public.book_periods;
begin
  v_me := public.book_actor(p_workspace_id, true);
  perform pg_advisory_xact_lock(hashtext('book-periods:' || p_workspace_id));
  if p_from is null or p_to is null or p_to < p_from then raise exception 'the period ends before it starts'; end if;
  if p_to > public.book_local_day(p_workspace_id, now()) then
    raise exception 'a period that has not ended cannot be closed';
  end if;
  if exists (select 1 from public.book_periods x
              where x.workspace_id = p_workspace_id and x.reopened_at is null
                and daterange(x.period_from, x.period_to, '[]') && daterange(p_from, p_to, '[]')) then
    raise exception 'part of this period is already closed';
  end if;
  insert into public.book_periods (workspace_id, period_from, period_to, reason, closed_by_member_id)
  values (p_workspace_id, p_from, p_to, 'owner', v_me) returning * into p;
  return public.book_period_json(p);
end;
$fn$;
revoke execute on function public.close_book_period_v1(uuid, date, date) from public, anon;
grant execute on function public.close_book_period_v1(uuid, date, date) to authenticated;

create or replace function public.reopen_book_period_v1(p_workspace_id uuid, p_period_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  p public.book_periods;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  v_me := public.book_actor(p_workspace_id, true);
  if v_reason = '' then raise exception 'say why the period is reopened'; end if;
  select * into p from public.book_periods where id = p_period_id and workspace_id = p_workspace_id for update;
  if p.id is null then raise exception 'unknown period'; end if;
  if p.reopened_at is not null then raise exception 'this period is already reopened'; end if;
  update public.book_periods
     set reopened_at = now(), reopened_by_member_id = v_me, reopen_reason = left(v_reason, 300)
   where id = p.id returning * into p;
  return public.book_period_json(p);
end;
$fn$;
revoke execute on function public.reopen_book_period_v1(uuid, uuid, text) from public, anon;
grant execute on function public.reopen_book_period_v1(uuid, uuid, text) to authenticated;

create or replace function public.record_book_export_v1(
  p_workspace_id uuid, p_format_id text, p_from date, p_to date,
  p_sha256 text, p_bytes bigint, p_rows int, p_documents int
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  e public.book_exports;
  v_closed boolean;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  -- The client logs every accounting export it makes; a space that keeps no
  -- accounting periods simply logs nothing.
  if not public.feature_effective(p_workspace_id, 'accountingPeriods') then
    return jsonb_build_object('logged', false);
  end if;
  if not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'you may not export the books';
  end if;
  if p_to < p_from then raise exception 'the period ends before it starts'; end if;
  -- closed when every day of the export lies inside closed periods
  select not exists (
      select 1 from generate_series(p_from, p_to, interval '1 day') d
       where not public.book_period_closed(p_workspace_id, d::date)) into v_closed;
  insert into public.book_exports
    (workspace_id, format_id, period_from, period_to, sha256, byte_count, row_count, document_count,
     closed_period, exported_by_member_id)
  values (p_workspace_id, btrim(p_format_id), p_from, p_to, lower(p_sha256), p_bytes, p_rows, p_documents,
          v_closed, v_me)
  returning * into e;
  return jsonb_build_object('logged', true, 'id', e.id, 'closed_period', e.closed_period, 'exported_at', e.exported_at);
end;
$fn$;
revoke execute on function public.record_book_export_v1(uuid, text, date, date, text, bigint, int, int) from public, anon;
grant execute on function public.record_book_export_v1(uuid, text, date, date, text, bigint, int, int) to authenticated;

create or replace function public.book_periods_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.book_actor(p_workspace_id, false);
  if not (public.is_owner_of(p_workspace_id) or public.has_permission(p_workspace_id, 'viewFinances')
          or public.has_permission(p_workspace_id, 'exportData')) then
    raise exception 'you may not read the periods';
  end if;
  return jsonb_build_object(
    'periods', coalesce((select jsonb_agg(public.book_period_json(p) order by p.period_from desc, p.closed_at desc)
                           from public.book_periods p where p.workspace_id = p_workspace_id), '[]'::jsonb),
    'exports', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'format_id', x.format_id,
                           'period_from', x.period_from, 'period_to', x.period_to, 'sha256', x.sha256,
                           'byte_count', x.byte_count, 'row_count', x.row_count, 'document_count', x.document_count,
                           'closed_period', x.closed_period, 'exported_at', x.exported_at)
                           order by x.exported_at desc)
                           from (select * from public.book_exports e where e.workspace_id = p_workspace_id
                                  order by e.exported_at desc limit 100) x), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.book_periods_v1(uuid) from public, anon;
grant execute on function public.book_periods_v1(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(504);
