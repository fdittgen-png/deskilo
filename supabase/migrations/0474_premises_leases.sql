-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0474 (#2569, C1 of the lease) -- the premises lease the space holds as
-- tenant, its rent terms with their history, and the scheduled expenses they
-- generate.
--
--   * `premises_leases`: one lease per row -- lessor (a supplier), the
--     member who answers its occurrences, the premises, the term (starts,
--     fixed until, notice months), the deposit, the indexation note, the
--     contract document, a status draft|active|notice_given|ended and, once
--     notice is given, who gave it, when, why and the effective end.
--   * `lease_terms`: rent / service-charge advance / other amounts, each from
--     an effective date. A term is never edited: a new term of the same kind
--     SUPERSEDES the one in force (it closes the day before) and a notice
--     closes every open one at the effective end. Each term owns one
--     `expense_schedules` row (0141); the existing sweep materialises its
--     occurrences, so the rent is a scheduled expense the responsible member
--     answers -- no second recurring engine.
--   * `save_premises_lease_v1`, `add_lease_term_v1`, `give_lease_notice_v1`:
--     manageLease while `premisesLease` is on, request-id replay
--     (`purchase_requests`), a stale revision refused.
--   * `premises_leases_v1`: the leases with their terms, the notice deadline
--     (fixed-until minus the notice months) and, after notice, what is
--     consequent -- the deposit due back and the occurrences left after the
--     end.
--
-- Not here: the validation domain, the year-end settlement, calendar
-- reminders, payables and payments (C2, #2365 and #2574).

-- ── tables ─────────────────────────────────────────────────────────────
create table public.premises_leases (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  supplier_id uuid not null,
  responsible_member_id uuid not null,
  premises text not null check (char_length(btrim(premises)) between 1 and 300),
  site_id uuid references public.sites(id),
  area_m2 numeric(10, 2) check (area_m2 is null or area_m2 > 0),
  covered_levels text not null default '' check (char_length(covered_levels) <= 300),
  starts_on date not null,
  fixed_until date,
  notice_months int not null default 0 check (notice_months between 0 and 60),
  indexation_note text not null default '' check (char_length(indexation_note) <= 500),
  deposit_cents int not null default 0 check (deposit_cents >= 0),
  contract_document_id uuid references public.workspace_documents(id),
  status text not null default 'draft'
    check (status in ('draft', 'active', 'notice_given', 'ended')),
  notice_given_on date,
  effective_end date,
  termination_reason text not null default '' check (char_length(termination_reason) <= 500),
  terminated_by_member_id uuid,
  revision int not null default 1 check (revision >= 1),
  created_by uuid references public.members(id),
  unique (workspace_id, id),
  foreign key (workspace_id, supplier_id) references public.suppliers (workspace_id, id),
  foreign key (workspace_id, responsible_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, terminated_by_member_id) references public.members (workspace_id, id),
  check (fixed_until is null or fixed_until >= starts_on),
  check (effective_end is null or effective_end >= starts_on),
  check ((status in ('notice_given', 'ended')) = (effective_end is not null)),
  check ((status in ('notice_given', 'ended')) = (notice_given_on is not null))
);
select public.ensure_system_columns('premises_leases');
create index premises_leases_workspace on public.premises_leases (workspace_id, status);

create table public.lease_terms (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  lease_id uuid not null,
  kind text not null check (kind in ('rent', 'service_charge_advance', 'other')),
  label text not null default '' check (char_length(label) <= 60),
  amount_cents int not null check (amount_cents > 0),
  every_months int not null default 1 check (every_months in (1, 3, 6, 12)),
  effective_from date not null,
  effective_to date,
  schedule_id uuid not null references public.expense_schedules(id),
  created_by uuid references public.members(id),
  unique (lease_id, kind, label, effective_from),
  foreign key (workspace_id, lease_id) references public.premises_leases (workspace_id, id),
  check (effective_to is null or effective_to >= effective_from)
);
select public.ensure_system_columns('lease_terms');
create index lease_terms_lease on public.lease_terms (lease_id, kind, effective_from);

-- A schedule is either a member's outlay (0141: the member advanced it and is
-- owed it back once confirmed) or a workspace contract (a lease): the space
-- pays the lessor itself, so its occurrences are EXPECTED obligations -- never
-- confirmed by a member as an outlay, never a credit on a member account.
-- Existing schedules are member outlays, unchanged.
alter table public.expense_schedules
  add column origin text not null default 'member_outlay'
    check (origin in ('member_outlay', 'workspace_contract')),
  add column contract_id uuid;

-- ── row level security: read by who sees the finances or manages the lease ─
alter table public.premises_leases enable row level security;
revoke all on public.premises_leases from public, anon, authenticated;
grant select on public.premises_leases to authenticated;
create policy premises_leases_select on public.premises_leases
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageLease'])));
create policy mcp_delegated_deny on public.premises_leases as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.lease_terms enable row level security;
revoke all on public.lease_terms from public, anon, authenticated;
grant select on public.lease_terms to authenticated;
create policy lease_terms_select on public.lease_terms
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageLease'])));
create policy mcp_delegated_deny on public.lease_terms as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- A term is history: never edited or deleted, only superseded by closing it
-- (effective_to) through the functions below.
create or replace function public.lease_terms_guard()
returns trigger language plpgsql as $fn$
declare
  o jsonb := to_jsonb(old) - public.system_column_names() - 'effective_to';
  n jsonb := to_jsonb(new) - public.system_column_names() - 'effective_to';
begin
  if tg_op = 'DELETE' then raise exception 'a lease term is history and is never deleted'; end if;
  if o is distinct from n then raise exception 'a lease term is superseded, never edited'; end if;
  if old.effective_to is not null and new.effective_to is distinct from old.effective_to
     and new.effective_to > old.effective_to then
    raise exception 'a closed lease term is not reopened';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.lease_terms_guard() from public, anon, authenticated;
create trigger lease_terms_guard
  before update or delete on public.lease_terms
  for each row execute function public.lease_terms_guard();

-- ── the member behind a call, with the lease rights checked ─────────────
create or replace function public.lease_actor(p_workspace_id uuid, p_write boolean)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'premisesLease') then
    raise exception 'the premises lease is switched off in this space';
  end if;
  if p_write then
    if not public.has_permission(p_workspace_id, 'manageLease') then
      raise exception 'you may not manage the lease';
    end if;
    if not public.feature_effective(p_workspace_id, 'supplyExpenses') then
      raise exception 'suppliers are switched off in this space';
    end if;
  elsif not (public.has_permission(p_workspace_id, 'viewFinances')
             or public.has_permission(p_workspace_id, 'manageLease')) then
    raise exception 'you may not read the lease';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.lease_actor(uuid, boolean) from public, anon, authenticated;

-- ── the reading ─────────────────────────────────────────────────────────
create or replace function public.premises_lease_json(l public.premises_leases)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', l.id, 'revision', l.revision,
    'supplier_id', l.supplier_id,
    'supplier_name', (select s.name from public.suppliers s
                       where s.workspace_id = l.workspace_id and s.id = l.supplier_id),
    'responsible_member_id', l.responsible_member_id,
    'premises', l.premises, 'site_id', l.site_id, 'area_m2', l.area_m2,
    'covered_levels', l.covered_levels,
    'starts_on', l.starts_on, 'fixed_until', l.fixed_until,
    'notice_months', l.notice_months,
    'notice_deadline', case when l.fixed_until is null then null
                            else (l.fixed_until - make_interval(months => l.notice_months))::date end,
    'indexation_note', l.indexation_note, 'deposit_cents', l.deposit_cents,
    'contract_document_id', l.contract_document_id,
    'status', case when l.status = 'notice_given' and l.effective_end <= current_date
                   then 'ended' else l.status end,
    'notice_given_on', l.notice_given_on, 'effective_end', l.effective_end,
    'termination_reason', l.termination_reason,
    'terminated_by_member_id', l.terminated_by_member_id,
    'deposit_due_back_cents', case when l.status in ('notice_given', 'ended') then l.deposit_cents else 0 end,
    'terms', coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'kind', t.kind, 'label', t.label, 'amount_cents', t.amount_cents,
        'every_months', t.every_months, 'effective_from', t.effective_from,
        'effective_to', t.effective_to,
        'occurrences_done', (select es.occurrences_done from public.expense_schedules es
                              where es.id = t.schedule_id))
        order by t.kind, t.label, t.effective_from)
        from public.lease_terms t where t.lease_id = l.id), '[]'::jsonb),
    'occurrences_after_end', case when l.effective_end is null then 0 else
      (select count(*)::int from public.expense_occurrences o
        join public.lease_terms t on t.schedule_id = o.schedule_id
       where t.lease_id = l.id and o.due_on > l.effective_end) end);
$fn$;
revoke execute on function public.premises_lease_json(public.premises_leases)
  from public, anon, authenticated;

create or replace function public.premises_leases_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  perform public.lease_actor(p_workspace_id, false);
  return jsonb_build_object('leases', coalesce((
    select jsonb_agg(public.premises_lease_json(l) order by l.starts_on desc, l.id)
      from public.premises_leases l where l.workspace_id = p_workspace_id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.premises_leases_v1(uuid) from public, anon;
grant execute on function public.premises_leases_v1(uuid) to authenticated;

-- ── save: create a lease or amend its description ───────────────────────
create or replace function public.save_premises_lease_v1(
  p_workspace_id uuid, p_lease_id uuid, p_revision int, p_payload jsonb, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  l public.premises_leases;
  v_supplier uuid := nullif(p_payload ->> 'supplier_id', '')::uuid;
  v_responsible uuid := coalesce(nullif(p_payload ->> 'responsible_member_id', '')::uuid, null);
  v_doc uuid := nullif(p_payload ->> 'contract_document_id', '')::uuid;
  v_site uuid := nullif(p_payload ->> 'site_id', '')::uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_me := public.lease_actor(p_workspace_id, true);
  v_digest := md5(v_me::text || coalesce(p_lease_id::text, '') || coalesce(p_revision, 0)::text
                  || coalesce(p_payload::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'lease_save', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  if v_doc is not null and not exists (select 1 from public.workspace_documents d
                                        where d.id = v_doc and d.workspace_id = p_workspace_id) then
    raise exception 'unknown contract document';
  end if;
  if v_site is not null and not exists (select 1 from public.sites s
                                         where s.id = v_site and s.workspace_id = p_workspace_id) then
    raise exception 'unknown site';
  end if;

  if p_lease_id is null then
    if coalesce(p_revision, 0) <> 0 then raise exception 'stale revision'; end if;
    if v_supplier is null or not exists (
         select 1 from public.suppliers s
          where s.id = v_supplier and s.workspace_id = p_workspace_id and s.status = 'active') then
      raise exception 'the lessor must be an active supplier of this space';
    end if;
    insert into public.premises_leases
      (workspace_id, supplier_id, responsible_member_id, premises, site_id, area_m2, covered_levels,
       starts_on, fixed_until, notice_months, indexation_note, deposit_cents,
       contract_document_id, created_by)
    values (p_workspace_id, v_supplier, coalesce(v_responsible, v_me),
            btrim(coalesce(p_payload ->> 'premises', '')), v_site,
            nullif(p_payload ->> 'area_m2', '')::numeric,
            coalesce(p_payload ->> 'covered_levels', ''),
            (p_payload ->> 'starts_on')::date, nullif(p_payload ->> 'fixed_until', '')::date,
            coalesce(nullif(p_payload ->> 'notice_months', '')::int, 0),
            coalesce(p_payload ->> 'indexation_note', ''),
            coalesce(nullif(p_payload ->> 'deposit_cents', '')::int, 0),
            v_doc, v_me)
    returning * into l;
  else
    select * into l from public.premises_leases
     where id = p_lease_id and workspace_id = p_workspace_id for update;
    if l.id is null then raise exception 'unknown lease'; end if;
    if l.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
    if l.status in ('notice_given', 'ended') then
      raise exception 'a lease that has been terminated is no longer edited';
    end if;
    if l.status = 'active' and (
         (p_payload ? 'supplier_id' and v_supplier is distinct from l.supplier_id)
         or (p_payload ? 'starts_on' and (p_payload ->> 'starts_on')::date is distinct from l.starts_on)) then
      raise exception 'the lessor and the start of an active lease are changed by a new lease';
    end if;
    update public.premises_leases set
      premises = case when p_payload ? 'premises' then btrim(p_payload ->> 'premises') else premises end,
      site_id = case when p_payload ? 'site_id' then v_site else site_id end,
      area_m2 = case when p_payload ? 'area_m2' then nullif(p_payload ->> 'area_m2', '')::numeric else area_m2 end,
      covered_levels = case when p_payload ? 'covered_levels' then p_payload ->> 'covered_levels' else covered_levels end,
      fixed_until = case when p_payload ? 'fixed_until' then nullif(p_payload ->> 'fixed_until', '')::date else fixed_until end,
      notice_months = case when p_payload ? 'notice_months' then (p_payload ->> 'notice_months')::int else notice_months end,
      indexation_note = case when p_payload ? 'indexation_note' then p_payload ->> 'indexation_note' else indexation_note end,
      deposit_cents = case when p_payload ? 'deposit_cents' then (p_payload ->> 'deposit_cents')::int else deposit_cents end,
      contract_document_id = case when p_payload ? 'contract_document_id' then v_doc else contract_document_id end,
      supplier_id = case when l.status = 'draft' and p_payload ? 'supplier_id' then coalesce(v_supplier, supplier_id) else supplier_id end,
      starts_on = case when l.status = 'draft' and p_payload ? 'starts_on' then (p_payload ->> 'starts_on')::date else starts_on end,
      responsible_member_id = case when p_payload ? 'responsible_member_id' and v_responsible is not null
                                   then v_responsible else responsible_member_id end,
      revision = revision + 1
     where id = l.id
    returning * into l;
  end if;
  v_result := public.premises_lease_json(l);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'lease_save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.save_premises_lease_v1(uuid, uuid, int, jsonb, uuid)
  from public, anon;
grant execute on function public.save_premises_lease_v1(uuid, uuid, int, jsonb, uuid)
  to authenticated;

-- ── a term: the amount from a date, superseding the one in force ────────
create or replace function public.add_lease_term_v1(
  p_workspace_id uuid, p_lease_id uuid, p_revision int, p_kind text, p_label text,
  p_amount_cents int, p_every_months int, p_effective_from date, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  l public.premises_leases;
  v_prev public.lease_terms;
  v_name text;
  v_title text;
  v_label text := btrim(coalesce(p_label, ''));
  v_schedule uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_me := public.lease_actor(p_workspace_id, true);
  v_digest := md5(v_me::text || p_lease_id::text || coalesce(p_revision, 0)::text || coalesce(p_kind, '')
                  || v_label || coalesce(p_amount_cents, 0)::text || coalesce(p_every_months, 1)::text
                  || coalesce(p_effective_from::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'lease_term', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  select * into l from public.premises_leases
   where id = p_lease_id and workspace_id = p_workspace_id for update;
  if l.id is null then raise exception 'unknown lease'; end if;
  if l.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if l.status in ('notice_given', 'ended') then
    raise exception 'a lease that has been terminated takes no new term';
  end if;
  if p_kind not in ('rent', 'service_charge_advance', 'other') then raise exception 'unknown term kind'; end if;
  if p_kind = 'other' and v_label = '' then raise exception 'name the other charge'; end if;
  if p_kind <> 'other' then v_label := ''; end if;
  if coalesce(p_amount_cents, 0) <= 0 then raise exception 'the amount must be positive'; end if;
  if coalesce(p_every_months, 1) not in (1, 3, 6, 12) then raise exception 'a term is paid every 1, 3, 6 or 12 months'; end if;
  if p_effective_from is null or p_effective_from < l.starts_on then
    raise exception 'a term cannot start before the lease';
  end if;

  select * into v_prev from public.lease_terms t
   where t.lease_id = l.id and t.kind = p_kind and t.label = v_label and t.effective_to is null
   order by t.effective_from desc limit 1 for update;
  if v_prev.id is not null then
    if p_effective_from <= v_prev.effective_from then
      raise exception 'a new term starts after the one in force';
    end if;
    update public.lease_terms set effective_to = p_effective_from - 1 where id = v_prev.id;
    update public.expense_schedules set ends_on = p_effective_from - 1 where id = v_prev.schedule_id;
  end if;

  select s.name into v_name from public.suppliers s where s.id = l.supplier_id;
  v_title := left(case p_kind when 'rent' then 'Rent' when 'service_charge_advance' then 'Service charges'
                     else v_label end || ' — ' || v_name, 80);
  insert into public.expense_schedules
    (workspace_id, member_id, supplier_id, title, description, amount_cents, starts_on, ends_on,
     unit, every, status, next_due, origin, contract_id)
  values (l.workspace_id, l.responsible_member_id, l.supplier_id, v_title, l.premises, p_amount_cents,
          p_effective_from, null, 'month', coalesce(p_every_months, 1), 'active', p_effective_from,
          'workspace_contract', l.id)
  returning id into v_schedule;
  insert into public.lease_terms
    (workspace_id, lease_id, kind, label, amount_cents, every_months, effective_from, schedule_id, created_by)
  values (l.workspace_id, l.id, p_kind, v_label, p_amount_cents, coalesce(p_every_months, 1),
          p_effective_from, v_schedule, v_me);
  update public.premises_leases
     set status = case when status = 'draft' then 'active' else status end, revision = revision + 1
   where id = l.id
  returning * into l;

  v_result := public.premises_lease_json(l);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'lease_term', v_digest, v_result);
end;
$fn$;
revoke execute on function public.add_lease_term_v1(uuid, uuid, int, text, text, int, int, date, uuid)
  from public, anon;
grant execute on function public.add_lease_term_v1(uuid, uuid, int, text, text, int, int, date, uuid)
  to authenticated;

-- ── notice: who, when, why, and the consequences ────────────────────────
create or replace function public.give_lease_notice_v1(
  p_workspace_id uuid, p_lease_id uuid, p_revision int, p_notice_given_on date,
  p_effective_end date, p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  l public.premises_leases;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_me := public.lease_actor(p_workspace_id, true);
  v_digest := md5(v_me::text || p_lease_id::text || coalesce(p_revision, 0)::text
                  || coalesce(p_notice_given_on::text, '') || coalesce(p_effective_end::text, '')
                  || btrim(coalesce(p_reason, '')));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'lease_notice', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  select * into l from public.premises_leases
   where id = p_lease_id and workspace_id = p_workspace_id for update;
  if l.id is null then raise exception 'unknown lease'; end if;
  if l.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if l.status <> 'active' then raise exception 'only an active lease is terminated'; end if;
  if p_notice_given_on is null or p_effective_end is null then
    raise exception 'state the day notice was given and the day the lease ends';
  end if;
  if p_effective_end < p_notice_given_on or p_effective_end < l.starts_on then
    raise exception 'the lease cannot end before notice is given';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then raise exception 'state why the lease ends'; end if;
  if exists (select 1 from public.lease_terms t where t.lease_id = l.id and t.effective_from > p_effective_end) then
    raise exception 'a term starts after that end; the lease cannot end before its last term begins';
  end if;

  update public.expense_schedules es
     set ends_on = least(coalesce(es.ends_on, p_effective_end), p_effective_end)
   where es.id in (select t.schedule_id from public.lease_terms t where t.lease_id = l.id);
  update public.lease_terms
     set effective_to = least(coalesce(effective_to, p_effective_end), p_effective_end)
   where lease_id = l.id and effective_from <= p_effective_end;
  update public.premises_leases
     set status = case when p_effective_end <= current_date then 'ended' else 'notice_given' end,
         notice_given_on = p_notice_given_on, effective_end = p_effective_end,
         termination_reason = left(btrim(p_reason), 500), terminated_by_member_id = v_me,
         revision = revision + 1
   where id = l.id
  returning * into l;

  v_result := public.premises_lease_json(l);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'lease_notice', v_digest, v_result);
end;
$fn$;
revoke execute on function public.give_lease_notice_v1(uuid, uuid, int, date, date, text, uuid)
  from public, anon;
grant execute on function public.give_lease_notice_v1(uuid, uuid, int, date, date, text, uuid)
  to authenticated;

-- A contract occurrence is not an outlay a member can confirm: confirming it
-- would credit the responsible member's account with the rent. Anchored patch
-- of the live body (asserted to occur exactly once), as 0451.
create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0474: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

select pg_temp.patch_function('public.confirm_expense_occurrence(uuid, integer, text, text)'::regprocedure,
  array[$a$select * into v_s from public.expense_schedules where id = v_o.schedule_id;$a$],
  array[$a$select * into v_s from public.expense_schedules where id = v_o.schedule_id;
  if v_s.origin = 'workspace_contract' then
    raise exception 'a contract occurrence is matched to the supplier invoice, not confirmed as an outlay';
  end if;$a$]);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(474);
