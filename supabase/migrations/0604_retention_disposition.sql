-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0604 (#2571) -- a retention clock gives a disposition, not a permission.
--
--   1. retention_holds    a legal or audit hold: every class or one, every
--      issuer or one, with its reason; it ends only when someone releases it
--      with a reason. Rows are never deleted. Read with viewFinances or
--      manageBilling, placed and released with manageBilling while
--      accountingBook is on; a hold keeps working when the flag is off.
--   2. retention_rule_for  the US setting retention.us_years EXTENDS the rule
--      and never shortens it.
--   3. retention_assess(workspace, issuer site, classes, document date)
--      returns every rule that applies to the document, with its source and
--      the day its clock ends, the holds over it, the latest of those days,
--      the reasons a person must review it, and one disposition:
--        retain                       a clock still runs, or a hold is in place;
--        review_required              no clock runs, but a rule is unconfirmed,
--                                     is the shared `*` default, is missing,
--                                     has no trigger date, or the issuer's
--                                     fiscal calendar is assumed;
--        eligible_for_erasure_review  only confirmed rules, every clock ended,
--                                     no hold.
--      The issuer is a site of the space (null: the default site), its
--      country the site's, else the space's. A rule is read twice, as in force
--      on the document's date and as in force today, and the later end wins:
--      a later shortening never shortens a document already issued.
--      retention_until now reads it, so there is one clock.
--   4. reset_workspace refuses (SQLSTATE DKE01) while the books of any issuer
--      are not eligible: the refusal names the rule and the day it ends, or
--      the hold, and carries the assessment as its detail. Nothing is deleted.
--   5. preview_my_erasure carries the assessment of the invoices and the
--      ledger it keeps.
--
-- Eligible means eligible for the existing, authorised erasure review. Nothing
-- here deletes a record when a clock ends.

-- ── 1. holds ──────────────────────────────────────────────────────────
create table if not exists public.retention_holds (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  issuer_site_id uuid references public.sites (id) on delete restrict,
  doc_class text check (doc_class is null or btrim(doc_class) <> ''),
  reason text not null check (char_length(btrim(reason)) between 1 and 500),
  placed_at timestamptz not null default now(),
  placed_by uuid references auth.users (id) on delete set null,
  released_at timestamptz,
  released_by uuid references auth.users (id) on delete set null,
  release_reason text check (release_reason is null or char_length(btrim(release_reason)) between 1 and 500),
  constraint retention_holds_release_whole check ((released_at is null) = (release_reason is null))
);
select public.ensure_system_columns('retention_holds');
create index if not exists retention_holds_active_idx
  on public.retention_holds (workspace_id) where released_at is null;
alter table public.retention_holds enable row level security;
revoke all on table public.retention_holds from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.retention_holds;
create policy mcp_delegated_deny on public.retention_holds
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── 2. the setting extends the rule ───────────────────────────────────
create or replace function public.retention_rule_for(p_workspace_id uuid, p_class text)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_country text;
  v_rule jsonb;
  v_years int;
begin
  select w.country_code into v_country from public.workspaces w where w.id = p_workspace_id;
  v_rule := public.retention_rule_of(v_country, p_class);
  if v_rule is null then return null; end if;
  if upper(btrim(coalesce(v_country, ''))) = 'US' then
    v_years := coalesce((public.setting_value(p_workspace_id, 'retention.us_years') #>> '{}')::int, 0);
    -- Only a longer period replaces the rule; a shorter one changes nothing.
    if v_years > (v_rule ->> 'years')::int then
      v_rule := v_rule || jsonb_build_object('years', v_years, 'from', 'document_date', 'source',
        'the space''s own setting retention.us_years');
    end if;
  end if;
  return v_rule;
end;
$fn$;
revoke execute on function public.retention_rule_for(uuid, text) from public, anon, authenticated;

-- ── 3. the assessment ─────────────────────────────────────────────────
create or replace function public.retention_assess(
  p_workspace_id uuid, p_issuer_site_id uuid, p_classes text[], p_document_date date)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tz text;
  v_country text;
  v_site public.sites;
  v_today date;
  v_month int;
  v_day int;
  v_assumed boolean := false;
  v_start date;
  v_year_end date;
  v_class text;
  v_on date;
  v_seen uuid[];
  v_found boolean;
  v_row record;
  v_base date;
  v_until date;
  v_latest date;
  v_unknown boolean := false;
  v_reasons text[] := '{}';
  v_rules jsonb := '[]'::jsonb;
  v_holds jsonb;
  v_us int;
begin
  select w.timezone, w.country_code into v_tz, v_country from public.workspaces w where w.id = p_workspace_id;
  if not found then raise exception 'no such workspace' using errcode = '22023'; end if;
  v_today := (now() at time zone coalesce(v_tz, 'UTC'))::date;
  if p_issuer_site_id is null then
    v_site := public.default_site(p_workspace_id);
  else
    select s.* into v_site from public.sites s
     where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id;
    if v_site.id is null then v_reasons := array_append(v_reasons, 'wrong_issuer'); end if;
  end if;
  v_country := upper(btrim(coalesce(nullif(btrim(v_site.country_code), ''), v_country, '')));

  if p_document_date is null then
    v_reasons := array_append(v_reasons, 'missing_trigger');
  else
    -- The end of the issuer's fiscal year the document falls in; the
    -- calendar year, flagged, where the issuer keeps no book profile.
    select b.fiscal_year_start_month, b.fiscal_year_start_day into v_month, v_day
      from public.book_profiles b
     where b.workspace_id = p_workspace_id and b.issuer_site_id = v_site.id
       and b.effective_from <= p_document_date
     order by b.effective_from desc limit 1;
    if v_month is null then
      v_assumed := true;
      v_month := 1;
      v_day := 1;
    end if;
    v_start := make_date(extract(year from p_document_date)::int, v_month, 1);
    v_start := least(v_start + (v_day - 1), (v_start + interval '1 month')::date - 1);
    if v_start > p_document_date then v_start := (v_start - interval '1 year')::date; end if;
    v_year_end := (v_start + interval '1 year')::date - 1;
  end if;

  foreach v_class in array coalesce(p_classes, '{}'::text[]) loop
    v_seen := '{}';
    v_found := false;
    foreach v_on in array array[coalesce(p_document_date, v_today), v_today] loop
      select t.id, t.country, t.valid_from, (t.value ->> 'years')::int as years, t.value ->> 'from' as start,
             t.source, t.confirmed
        into v_row
        from public.tax_reference t
       where t.domain = 'retention' and t.key = v_class
         and t.country in (v_country, '*')
         and t.valid_from <= v_on and (t.valid_to is null or t.valid_to > v_on)
       order by (t.country = '*'), t.valid_from desc
       limit 1;
      if not found or v_row.id = any (v_seen) then continue; end if;
      v_seen := v_seen || v_row.id;
      v_found := true;
      v_base := case v_row.start when 'document_date' then p_document_date
                                 when 'fiscal_year_end' then v_year_end end;
      v_until := (v_base + make_interval(years => v_row.years))::date;
      if v_until is null then
        v_unknown := true;
        v_reasons := array_append(v_reasons, 'missing_trigger');
      else
        v_latest := greatest(v_latest, v_until);
      end if;
      if v_row.country = '*' then v_reasons := array_append(v_reasons, 'default_rule'); end if;
      if not v_row.confirmed then v_reasons := array_append(v_reasons, 'unconfirmed'); end if;
      if v_assumed and v_row.start = 'fiscal_year_end' then
        v_reasons := array_append(v_reasons, 'fiscal_calendar_assumed');
      end if;
      v_rules := v_rules || jsonb_build_array(jsonb_build_object(
        'class', v_class, 'country', v_row.country, 'years', v_row.years, 'from', v_row.start,
        'valid_from', v_row.valid_from, 'source', v_row.source, 'confirmed', v_row.confirmed,
        'until', v_until));
    end loop;
    if not v_found then
      v_unknown := true;
      v_reasons := array_append(v_reasons, 'no_rule');
    end if;
    -- A US space's own longer period is one more rule; it can only end later.
    if v_country = 'US' and p_document_date is not null then
      v_us := coalesce((public.setting_value(p_workspace_id, 'retention.us_years') #>> '{}')::int, 0);
      if v_us > 0 then
        v_until := (p_document_date + make_interval(years => v_us))::date;
        v_latest := greatest(v_latest, v_until);
        v_rules := v_rules || jsonb_build_array(jsonb_build_object(
          'class', v_class, 'country', 'US', 'years', v_us, 'from', 'document_date',
          'source', 'the space''s own setting retention.us_years', 'confirmed', true,
          'until', v_until));
      end if;
    end if;
  end loop;

  select coalesce(jsonb_agg(jsonb_build_object('id', h.id, 'issuer_site_id', h.issuer_site_id,
                                               'class', h.doc_class, 'reason', h.reason,
                                               'placed_at', h.placed_at)
                            order by h.placed_at), '[]'::jsonb)
    into v_holds
    from public.retention_holds h
   where h.workspace_id = p_workspace_id and h.released_at is null
     and (h.issuer_site_id is null or h.issuer_site_id = v_site.id)
     and (h.doc_class is null or h.doc_class = any (p_classes));

  return jsonb_build_object(
    'issuer_site_id', v_site.id,
    'country', v_country,
    'document_date', p_document_date,
    'rules', v_rules,
    'holds', v_holds,
    'retain_until', v_latest,
    'indefinite', jsonb_array_length(v_holds) > 0,
    'reasons', to_jsonb(array(select distinct r from unnest(v_reasons) r order by r)),
    'disposition', case
      when jsonb_array_length(v_holds) > 0 then 'retain'
      when v_latest > v_today then 'retain'
      when cardinality(v_reasons) > 0 or v_unknown then 'review_required'
      else 'eligible_for_erasure_review' end);
end;
$fn$;
revoke execute on function public.retention_assess(uuid, uuid, text[], date) from public, anon, authenticated;

-- Several documents, given as the latest one per issuer
-- ([{issuer_site_id, document_date}]): the strictest disposition, the latest
-- end, and the rule that sets it. Null disposition: nothing to keep.
create or replace function public.retention_assess_records(
  p_workspace_id uuid, p_classes text[], p_records jsonb)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_item jsonb;
  v_one jsonb;
  v_issuers jsonb := '[]'::jsonb;
  v_rank int := 0;
  v_latest date;
  v_governing jsonb;
  v_rule jsonb;
begin
  for v_item in select e from jsonb_array_elements(coalesce(p_records, '[]'::jsonb)) e loop
    v_one := public.retention_assess(p_workspace_id, nullif(v_item ->> 'issuer_site_id', '')::uuid,
                                     p_classes, (v_item ->> 'document_date')::date);
    v_issuers := v_issuers || jsonb_build_array(v_one);
    v_rank := greatest(v_rank, case v_one ->> 'disposition' when 'retain' then 3
                                                             when 'review_required' then 2 else 1 end);
    if (v_one ->> 'retain_until')::date > v_latest or v_latest is null then
      v_latest := (v_one ->> 'retain_until')::date;
    end if;
  end loop;
  for v_rule in select r from jsonb_array_elements(v_issuers) i, jsonb_array_elements(i -> 'rules') r loop
    if (v_rule ->> 'until')::date = v_latest and v_governing is null then v_governing := v_rule; end if;
  end loop;
  return jsonb_build_object(
    'disposition', case v_rank when 3 then 'retain' when 2 then 'review_required'
                               when 1 then 'eligible_for_erasure_review' end,
    'retain_until', v_latest,
    'indefinite', exists (select 1 from jsonb_array_elements(v_issuers) i where (i ->> 'indefinite')::boolean),
    'rule', v_governing,
    'holds', coalesce((select jsonb_agg(h) from jsonb_array_elements(v_issuers) i,
                              jsonb_array_elements(i -> 'holds') h), '[]'::jsonb),
    'reasons', to_jsonb(array(select distinct r from jsonb_array_elements(v_issuers) i,
                                     jsonb_array_elements_text(i -> 'reasons') r order by r)),
    'issuers', v_issuers);
end;
$fn$;
revoke execute on function public.retention_assess_records(uuid, text[], jsonb) from public, anon, authenticated;

-- What a member's invoices or ledger rows are under: the latest of them per
-- issuer, in the space's time zone.
create or replace function public.retention_member_records(
  p_workspace_id uuid, p_member_id uuid, p_store text)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tz text;
begin
  select coalesce(w.timezone, 'UTC') into v_tz from public.workspaces w where w.id = p_workspace_id;
  if p_store = 'invoices' then
    return public.retention_assess_records(p_workspace_id, array['invoice'],
      (select coalesce(jsonb_agg(jsonb_build_object('issuer_site_id', x.site_id, 'document_date', x.day)), '[]'::jsonb)
         from (select i.site_id, max((i.issued_at at time zone v_tz)::date) as day
                 from public.invoices i
                where i.workspace_id = p_workspace_id and i.member_id = p_member_id
                group by i.site_id) x));
  elsif p_store = 'ledger_entries' then
    return public.retention_assess_records(p_workspace_id, array['books'],
      (select coalesce(jsonb_agg(jsonb_build_object('issuer_site_id', x.site_id, 'document_date', x.day)), '[]'::jsonb)
         from (select l.site_id, max((l.created_at at time zone v_tz)::date) as day
                 from public.ledger_entries l
                where l.workspace_id = p_workspace_id and l.member_id = p_member_id
                group by l.site_id) x));
  end if;
  raise exception 'unknown store %', p_store using errcode = '22023';
end;
$fn$;
revoke execute on function public.retention_member_records(uuid, uuid, text) from public, anon, authenticated;

-- The refusal of a destructive step over records that must stay: it names
-- the rule and the day it ends, or the hold, and carries the assessment.
create or replace function public.retention_refuse_unless_eligible(p_what text, p_assessment jsonb)
returns void
language plpgsql stable security definer set search_path = public as $fn$
begin
  if coalesce(p_assessment ->> 'disposition', 'eligible_for_erasure_review') = 'eligible_for_erasure_review' then
    return;
  end if;
  raise exception '%', format('retention: the %s of this space are kept %s; nothing was deleted', p_what,
      case when (p_assessment ->> 'indefinite')::boolean
             then 'under a legal hold: ' || (p_assessment -> 'holds' -> 0 ->> 'reason')
           when p_assessment ->> 'disposition' = 'retain'
             then 'until ' || (p_assessment ->> 'retain_until') || ' under '
                  || coalesce(p_assessment -> 'rule' ->> 'source', 'the retention rule')
           else 'until a person reviews the retention rule ('
                || array_to_string(array(select jsonb_array_elements_text(p_assessment -> 'reasons')), ', ')
                || coalesce('; its clock ended on ' || (p_assessment ->> 'retain_until'), '') || ')'
      end)
    using errcode = 'DKE01', detail = p_assessment::text;
end;
$fn$;
revoke execute on function public.retention_refuse_unless_eligible(text, jsonb) from public, anon, authenticated;

-- One clock: the first day a document may go is the assessment's.
create or replace function public.retention_until(p_workspace_id uuid, p_class text, p_document_date date)
returns date
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members := public.my_active_member(p_workspace_id);
begin
  if p_document_date is null then return null; end if;
  return (public.retention_assess(p_workspace_id, null, array[p_class], p_document_date) ->> 'retain_until')::date;
end;
$fn$;
revoke execute on function public.retention_until(uuid, text, date) from public, anon;
grant execute on function public.retention_until(uuid, text, date) to authenticated;

-- ── the holds, read, placed and released ─────────────────────────────
create or replace function public.retention_holds_json(p_hold public.retention_holds)
returns jsonb
language sql stable set search_path = public as $fn$
  select jsonb_build_object('id', p_hold.id, 'workspace_id', p_hold.workspace_id,
    'issuer_site_id', p_hold.issuer_site_id, 'class', p_hold.doc_class, 'reason', p_hold.reason,
    'placed_at', p_hold.placed_at, 'released_at', p_hold.released_at,
    'release_reason', p_hold.release_reason);
$fn$;
revoke execute on function public.retention_holds_json(public.retention_holds) from public, anon, authenticated;

create or replace function public.retention_holds(p_workspace_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not (public.has_permission(p_workspace_id, 'viewFinances')
             or public.has_permission(p_workspace_id, 'manageBilling')) then
    raise exception 'only someone who reads this workspace''s finances reads its holds'
      using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(public.retention_holds_json(h)
                                    order by h.released_at is not null, h.placed_at desc)
                     from public.retention_holds h where h.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.retention_holds(uuid) from public, anon;
grant execute on function public.retention_holds(uuid) to authenticated;

create or replace function public.retention_hold_writer(p_workspace_id uuid)
returns void
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'only someone who manages billing places or releases a hold' using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'accountingBook') then
    raise exception 'the accounting books are off in this workspace' using errcode = '0A000';
  end if;
end;
$fn$;
revoke execute on function public.retention_hold_writer(uuid) from public, anon, authenticated;

create or replace function public.place_retention_hold(
  p_workspace_id uuid, p_issuer_site_id uuid, p_doc_class text, p_reason text)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_hold public.retention_holds;
begin
  perform public.retention_hold_writer(p_workspace_id);
  if p_issuer_site_id is not null and not exists (
       select 1 from public.sites s where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this workspace' using errcode = '22023';
  end if;
  if p_doc_class is not null and not exists (
       select 1 from public.tax_reference t where t.domain = 'retention' and t.key = p_doc_class) then
    raise exception 'no retention rule knows this class of record' using errcode = '22023';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 1 and 500 then
    raise exception 'a hold names its reason' using errcode = '22023';
  end if;
  insert into public.retention_holds (workspace_id, issuer_site_id, doc_class, reason, placed_by)
  values (p_workspace_id, p_issuer_site_id, p_doc_class, btrim(p_reason), auth.uid())
  returning * into v_hold;
  return public.retention_holds_json(v_hold);
end;
$fn$;
revoke execute on function public.place_retention_hold(uuid, uuid, text, text) from public, anon;
grant execute on function public.place_retention_hold(uuid, uuid, text, text) to authenticated;

create or replace function public.release_retention_hold(p_hold_id uuid, p_reason text)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_hold public.retention_holds;
begin
  select * into v_hold from public.retention_holds where id = p_hold_id for update;
  if v_hold.id is null then
    raise exception 'no such hold' using errcode = 'P0002';
  end if;
  perform public.retention_hold_writer(v_hold.workspace_id);
  if v_hold.released_at is not null then
    raise exception 'this hold is already released' using errcode = '55000';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 1 and 500 then
    raise exception 'a release names its reason' using errcode = '22023';
  end if;
  update public.retention_holds
     set released_at = now(), released_by = auth.uid(), release_reason = btrim(p_reason)
   where id = p_hold_id
  returning * into v_hold;
  return public.retention_holds_json(v_hold);
end;
$fn$;
revoke execute on function public.release_retention_hold(uuid, text) from public, anon;
grant execute on function public.release_retention_hold(uuid, text) to authenticated;

-- ── 4 and 5. the consumers ────────────────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  -- The books of every issuer leave only when their retention allows it.
  select pg_get_functiondef('public.reset_workspace(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  delete from public.event_decisions d$a$,
    $a$  perform public.retention_refuse_unless_eligible('books', public.retention_assess_records(
    p_workspace_id, array['books'],
    (select coalesce(jsonb_agg(jsonb_build_object('issuer_site_id', x.site_id, 'document_date', x.day)), '[]'::jsonb)
       from (select l.site_id, max((l.created_at at time zone w.timezone)::date) as day
               from public.ledger_entries l join public.workspaces w on w.id = l.workspace_id
              where l.workspace_id = p_workspace_id
              group by l.site_id) x)));

  delete from public.event_decisions d$a$);
  if v_def is null or position('retention_refuse_unless_eligible' in v_def) = 0 then
    raise exception '0604: reset_workspace anchor missing';
  end if;
  execute v_def;

  select pg_get_functiondef('public.preview_my_erasure(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'until', public.retention_until(p_workspace_id, 'invoice',
                   (select max(i.issued_at)::date from public.invoices i where i.member_id = v_me.id))),$a$,
    $a$'until', public.retention_member_records(p_workspace_id, v_me.id, 'invoices') ->> 'retain_until',
        'retention', public.retention_member_records(p_workspace_id, v_me.id, 'invoices')),$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$'until', public.retention_until(p_workspace_id, 'books',
                   (select max(l.created_at)::date from public.ledger_entries l where l.member_id = v_me.id))),$a$,
    $a$'until', public.retention_member_records(p_workspace_id, v_me.id, 'ledger_entries') ->> 'retain_until',
        'retention', public.retention_member_records(p_workspace_id, v_me.id, 'ledger_entries')),$a$);
  if v_def is null
     or position($a$retention_member_records(p_workspace_id, v_me.id, 'invoices')$a$ in v_def) = 0
     or position($a$retention_member_records(p_workspace_id, v_me.id, 'ledger_entries')$a$ in v_def) = 0 then
    raise exception '0604: preview_my_erasure anchor missing';
  end if;
  execute v_def;
end
$migration$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon;

select public.set_deskilo_schema_version(604);
