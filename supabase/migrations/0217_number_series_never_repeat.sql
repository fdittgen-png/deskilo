-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1320 — a number series never issues the same number twice.
--
-- `next_document_number` restarted a counter whenever the stored period
-- key differed from the current one. Two things made that re-issue
-- numbers that already existed:
--
--   1. A restart finer than the printed date. "No date, restart every
--      year" prints INV-0001 again each January; "year, restart every
--      month" prints 2026-0001 again each month. `invoices` has a unique
--      index, so invoicing then failed for the whole period — and the
--      failed transaction rolled back the increment, so every retry drew
--      the same number. Member numbers have no unique index and were
--      duplicated silently.
--   2. Changing the restart mid-period moved the key at once, so the next
--      draw restarted inside a period that had already issued 0001.
--
-- Now: an invalid pair is refused. A draw restarts only when the stored
-- period is an EARLIER period of the SAME granularity; every other
-- mismatch continues the counter and re-keys it, because continuing can
-- never repeat a number and restarting can. A legacy invalid row is drawn
-- as its nearest valid pair and reported, never silently rewritten.

-- Which restarts a date part can carry: no date → never; the year →
-- never or yearly; year and month → any.
create or replace function public.number_sequence_pair_valid(p_date_part text, p_reset text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case p_date_part
    when 'none' then p_reset = 'never'
    when 'year' then p_reset in ('never', 'yearly')
    when 'year_month' then p_reset in ('never', 'yearly', 'monthly')
    else false
  end;
$$;

-- The restart a draw honours: the stored one when valid, otherwise the
-- finest restart the printed date can carry.
create or replace function public.number_sequence_effective_reset(p_date_part text, p_reset text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when public.number_sequence_pair_valid(p_date_part, p_reset) then p_reset
    when p_date_part = 'year' then 'yearly'
    else 'never'
  end;
$$;

-- A draw starts again at 1 only when the stored period is an earlier
-- period of the same granularity ('2025' → '2026', '2026-08' → '2026-09').
create or replace function public.number_sequence_restarts(p_stored text, p_current text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_stored <> '' and length(p_stored) = length(p_current) and p_stored < p_current;
$$;

-- How much of the date a series prints: none 0, year 1, year and month 2.
create or replace function public.number_sequence_date_rank(p_date_part text)
returns integer
language sql
immutable
set search_path = public
as $$
  select case p_date_part when 'year' then 1 when 'year_month' then 2 else 0 end;
$$;

-- Helpers of the definer functions below; nobody calls them directly.
revoke execute on function public.number_sequence_pair_valid(text, text) from public, anon;
revoke execute on function public.number_sequence_effective_reset(text, text) from public, anon;
revoke execute on function public.number_sequence_restarts(text, text) from public, anon;
revoke execute on function public.number_sequence_date_rank(text) from public, anon;

create or replace function public.next_document_number(p_workspace_id uuid, p_journal text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_seq public.number_sequences; v_key text; v_value bigint;
begin
  insert into public.number_sequences (workspace_id, journal, prefix, date_part, reset)
  select p_workspace_id, p_journal, d.prefix, d.date_part, d.reset from public.number_sequence_defaults(p_journal) d
  on conflict (workspace_id, journal)
    do update set journal = public.number_sequences.journal
  returning * into v_seq;
  v_key := public.number_sequence_period_key(p_workspace_id,
             public.number_sequence_effective_reset(v_seq.date_part, v_seq.reset));
  if public.number_sequence_restarts(v_seq.period_key, v_key) then
    v_value := 1;
    update public.number_sequences set period_key = v_key, next_value = 2
     where workspace_id = p_workspace_id and journal = p_journal;
  else
    -- Continue, and re-key: a restart change, a legacy pair or a first
    -- draw takes effect at the NEXT boundary, never inside this period.
    v_value := v_seq.next_value;
    update public.number_sequences
       set next_value = next_value + 1,
           period_key = case when length(period_key) = length(v_key)
                             then greatest(period_key, v_key) else v_key end
     where workspace_id = p_workspace_id and journal = p_journal;
  end if;
  return public.number_sequence_format(p_workspace_id, v_seq, v_value);
end;
$function$;

create or replace function public.preview_document_number(p_workspace_id uuid, p_journal text)
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
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
  v_key := public.number_sequence_period_key(p_workspace_id,
             public.number_sequence_effective_reset(v_seq.date_part, v_seq.reset));
  return public.number_sequence_format(p_workspace_id, v_seq,
    case when public.number_sequence_restarts(v_seq.period_key, v_key) then 1 else v_seq.next_value end);
end;
$function$;

create or replace function public.set_number_sequence(
  p_workspace_id uuid, p_journal text, p_prefix text, p_suffix text,
  p_date_part text, p_digits integer, p_reset text, p_next_value bigint default null)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_seq public.number_sequences; v_date text; v_reset text;
begin
  if not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'only owners may configure number sequences';
  end if;
  insert into public.number_sequences (workspace_id, journal)
  values (p_workspace_id, p_journal) on conflict (workspace_id, journal) do nothing;
  select * into v_seq from public.number_sequences
   where workspace_id = p_workspace_id and journal = p_journal for update;
  if p_next_value is not null and p_next_value < v_seq.next_value then
    raise exception 'a sequence never goes backwards: % is below %', p_next_value, v_seq.next_value;
  end if;
  v_date := coalesce(p_date_part, v_seq.date_part);
  v_reset := coalesce(p_reset, v_seq.reset);
  if not public.number_sequence_pair_valid(v_date, v_reset) then
    raise exception 'a number series cannot restart more often than it prints its date (% with %)',
      v_date, v_reset
      using hint = 'no date: never; the year: never or yearly; year and month: any';
  end if;
  -- Printing less of the date on a series that already issued numbers
  -- can print one of them again (2026-0005 and 2027-0005 both become
  -- INV-0005). A new prefix or suffix keeps the new numbers apart.
  if public.number_sequence_date_rank(v_date) < public.number_sequence_date_rank(v_seq.date_part)
     and v_seq.next_value > 1
     and coalesce(p_prefix, v_seq.prefix) = v_seq.prefix
     and coalesce(p_suffix, v_seq.suffix) = v_seq.suffix then
    raise exception 'removing the date from a series that already issued numbers could repeat one: change the prefix or suffix in the same step';
  end if;
  update public.number_sequences
     set prefix = coalesce(p_prefix, prefix), suffix = coalesce(p_suffix, suffix),
         date_part = v_date, digits = coalesce(p_digits, digits),
         reset = v_reset, next_value = coalesce(p_next_value, next_value)
   where workspace_id = p_workspace_id and journal = p_journal;
end;
$function$;

-- CREATE OR REPLACE keeps each function's ACL; restated here so this file
-- says who may call what. authenticated keeps what it had.
revoke execute on function public.next_document_number(uuid, text) from public, anon;
revoke execute on function public.preview_document_number(uuid, text) from public, anon;
revoke execute on function public.set_number_sequence(uuid, text, text, text, text, integer, text, bigint) from public, anon;

-- Existing invalid pairs: reported, never rewritten. They are already
-- drawn safely through number_sequence_effective_reset, and the editor
-- asks the owner for a valid pair.
do $report$
declare r record;
begin
  for r in
    select workspace_id, journal, date_part, reset from public.number_sequences
     where not public.number_sequence_pair_valid(date_part, reset)
  loop
    raise warning '#1320: number series % of workspace % restarts % but prints %; drawn as %',
      r.journal, r.workspace_id, r.reset, r.date_part,
      public.number_sequence_effective_reset(r.date_part, r.reset);
  end loop;
end
$report$;

-- Member and VAT declaration numbers were never unique. Where the data
-- allows it they are now; where it does not, the duplicates are named and
-- the index waits for an owner to resolve them. An empty number is "not
-- numbered yet" (a mirrored dev-twin member, a draft), never a duplicate.
do $unique$
begin
  if exists (select 1 from public.members where member_number <> ''
              group by workspace_id, member_number having count(*) > 1) then
    raise warning '#1320: duplicate member numbers exist — members_workspace_member_number_key not created';
  else
    create unique index if not exists members_workspace_member_number_key
      on public.members (workspace_id, member_number) where member_number <> '';
  end if;
  if exists (select 1 from public.vat_declarations where number <> ''
              group by workspace_id, number having count(*) > 1) then
    raise warning '#1320: duplicate VAT declaration numbers exist — vat_declarations_workspace_number_key not created';
  else
    create unique index if not exists vat_declarations_workspace_number_key
      on public.vat_declarations (workspace_id, number) where number <> '';
  end if;
end
$unique$;
