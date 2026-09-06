-- SPDX-License-Identifier: 0BSD
-- 0164 — #925: one number-sequence framework, per workspace, generated
-- in the database.
--
-- The only human-facing number the app generated was the invoice
-- number, produced by copy-pasted SQL in create_invoice and
-- settle_invoices: count(*) over the year's invoices, plus one, under a
-- workspace-wide advisory lock, with the year taken in UTC. That was
-- gapless by accident (a rolled-back issue takes its count with it),
-- O(n) per issue, serialised every issuer of a workspace behind one
-- lock, rolled the year at UTC midnight while every other billing
-- boundary uses the workspace's clock, and could not be configured.
--
-- A Postgres SEQUENCE is the textbook answer and would have broken the
-- one thing worth keeping: nextval is deliberately non-transactional, so
-- every failed issue would burn a number for good. French law (CGI art.
-- 289) requires a continuous chronological series per journal.
--
-- So: one narrow row per (workspace, journal), locked FOR UPDATE for the
-- microseconds it takes to increment, inside the caller's transaction.
-- Gapless — the increment rolls back with the issue. O(1). Serialised
-- only against writers of the same series. The period key is resolved on
-- the WORKSPACE clock. And the format is the owner's to set: prefix,
-- date part, digits, suffix, reset policy.
--
-- `gapless` is constrained to true. Caching blocks of numbers is
-- incompatible with a gapless series (an unconsumed block IS the hole
-- the law forbids), and no journal needs a gapped mode today; the column
-- exists so a later journal that does can ask for one explicitly.
--
-- Values are per workspace by construction: the primary key carries the
-- workspace and row-level security restricts reads to its members.
-- Writes go only through the definer functions below.
--
-- Every workspace is seeded so its invoice series continues unbroken:
-- next_value is the same count(*)+1 the old code would have produced
-- for the current year, keyed to the workspace's own year.
create table if not exists public.number_sequences (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  journal      text not null check (journal ~ '^[a-z_]{1,32}$'),
  prefix       text not null default '' check (char_length(prefix) <= 16),
  suffix       text not null default '' check (char_length(suffix) <= 16),
  date_part    text not null default 'year' check (date_part in ('none','year','year_month')),
  digits       int  not null default 4 check (digits between 1 and 9),
  reset        text not null default 'yearly' check (reset in ('never','yearly','monthly')),
  gapless      boolean not null default true check (gapless),
  period_key   text not null default '',
  next_value   bigint not null default 1 check (next_value >= 1),
  primary key (workspace_id, journal)
);
alter table public.number_sequences enable row level security;
drop policy if exists number_sequences_select on public.number_sequences;
create policy number_sequences_select on public.number_sequences
  for select using (public.is_member_of(workspace_id));

-- The period a counter belongs to, on the workspace clock — never UTC.
create or replace function public.number_sequence_period_key(
  p_workspace_id uuid, p_reset text, p_at timestamptz default now())
returns text language sql stable as $$
  select case p_reset
    when 'yearly'  then to_char(p_at at time zone coalesce(w.timezone, 'UTC'), 'YYYY')
    when 'monthly' then to_char(p_at at time zone coalesce(w.timezone, 'UTC'), 'YYYY-MM')
    else '' end
  from public.workspaces w where w.id = p_workspace_id;
$$;

create or replace function public.number_sequence_format(
  p_workspace_id uuid, p_seq public.number_sequences, p_value bigint, p_at timestamptz default now())
returns text language sql stable as $$
  select p_seq.prefix
      || case p_seq.date_part
           when 'year'       then to_char(p_at at time zone coalesce(w.timezone,'UTC'), 'YYYY') || '-'
           when 'year_month' then to_char(p_at at time zone coalesce(w.timezone,'UTC'), 'YYYY-MM') || '-'
           else '' end
      || lpad(p_value::text, p_seq.digits, '0')
      || p_seq.suffix
  from public.workspaces w where w.id = p_workspace_id;
$$;

-- The one way a number is taken. Definer, and NOT callable by clients:
-- a number is drawn by the function that issues the document, inside
-- its transaction, so it can never be drawn and then not used.
create or replace function public.next_document_number(p_workspace_id uuid, p_journal text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare v_seq public.number_sequences; v_key text; v_value bigint;
begin
  insert into public.number_sequences (workspace_id, journal)
  values (p_workspace_id, p_journal) on conflict (workspace_id, journal) do nothing;
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
revoke execute on function public.next_document_number(uuid, text) from public, anon, authenticated;

-- What the next number WOULD be, without taking it — the live preview
-- on the settings screen.
create or replace function public.preview_document_number(p_workspace_id uuid, p_journal text)
returns text language plpgsql stable security definer set search_path = public as $$
declare v_seq public.number_sequences; v_key text;
begin
  if not public.is_member_of(p_workspace_id) then raise exception 'not a member'; end if;
  select * into v_seq from public.number_sequences
   where workspace_id = p_workspace_id and journal = p_journal;
  if not found then
    v_seq.prefix := ''; v_seq.suffix := ''; v_seq.date_part := 'year';
    v_seq.digits := 4; v_seq.reset := 'yearly'; v_seq.period_key := ''; v_seq.next_value := 1;
  end if;
  v_key := public.number_sequence_period_key(p_workspace_id, v_seq.reset);
  return public.number_sequence_format(p_workspace_id, v_seq,
    case when v_seq.period_key = v_key then v_seq.next_value else 1 end);
end;
$$;
grant execute on function public.preview_document_number(uuid, text) to authenticated;

-- Owner only. A format change applies to what comes next and never
-- rewrites an issued document. The counter may be raised (to continue a
-- series kept elsewhere) and never lowered: lowering would reissue a
-- number that already names a document.
create or replace function public.set_number_sequence(
  p_workspace_id uuid, p_journal text, p_prefix text, p_suffix text,
  p_date_part text, p_digits int, p_reset text, p_next_value bigint default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_seq public.number_sequences;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only owners may configure number sequences';
  end if;
  insert into public.number_sequences (workspace_id, journal)
  values (p_workspace_id, p_journal) on conflict (workspace_id, journal) do nothing;
  select * into v_seq from public.number_sequences
   where workspace_id = p_workspace_id and journal = p_journal for update;
  if p_next_value is not null and p_next_value < v_seq.next_value then
    raise exception 'a sequence never goes backwards: % is below %', p_next_value, v_seq.next_value;
  end if;
  update public.number_sequences
     set prefix = coalesce(p_prefix, prefix), suffix = coalesce(p_suffix, suffix),
         date_part = coalesce(p_date_part, date_part), digits = coalesce(p_digits, digits),
         reset = coalesce(p_reset, reset), next_value = coalesce(p_next_value, next_value)
   where workspace_id = p_workspace_id and journal = p_journal;
end;
$$;
revoke execute on function public.set_number_sequence(uuid, text, text, text, text, int, text, bigint) from public, anon;
grant execute on function public.set_number_sequence(uuid, text, text, text, text, int, text, bigint) to authenticated;

insert into public.number_sequences (workspace_id, journal, prefix, date_part, digits, reset, period_key, next_value)
select w.id, 'invoice', 'INV-', 'year', 4, 'yearly',
       to_char(now() at time zone coalesce(w.timezone,'UTC'), 'YYYY'),
       coalesce((select count(*) from public.invoices i
                  where i.workspace_id = w.id
                    and date_part('year', i.issued_at) = date_part('year', now())), 0) + 1
  from public.workspaces w
on conflict (workspace_id, journal) do nothing;

-- The two issuers draw from the framework; the duplicated count is gone.
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_invoice';
  v_old := E'  select count(*) into v_count from public.invoices\n'
        || E'    where workspace_id = p_workspace_id\n'
        || E'      and date_part(''year'', issued_at) = date_part(''year'', now());\n'
        || E'  v_number := ''INV-'' || date_part(''year'', now())::int || ''-''\n'
        || E'      || lpad((v_count + 1)::text, 4, ''0'');\n';
  if position(v_old in v_def) = 0 then raise exception '0164: create_invoice numbering anchor missing'; end if;
  execute replace(v_def, v_old, E'  v_number := public.next_document_number(p_workspace_id, ''invoice'');\n');
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='settle_invoices';
  v_old := E'  select count(*) into v_count from public.invoices\n'
        || E'    where workspace_id = p_workspace_id and date_part(''year'', issued_at) = date_part(''year'', now());\n'
        || E'  v_number := ''INV-'' || date_part(''year'', now())::int || ''-'' || lpad((v_count + 1)::text, 4, ''0'');\n';
  if position(v_old in v_def) = 0 then raise exception '0164: settle_invoices numbering anchor missing'; end if;
  execute replace(v_def, v_old, E'  v_number := public.next_document_number(p_workspace_id, ''invoice'');\n');
end
$patch$;
