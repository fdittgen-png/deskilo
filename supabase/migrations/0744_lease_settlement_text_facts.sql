-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0744 — #3813 (part of #3657, i18n I11e): a lease settlement's pre-filled
-- texts are facts, not English. Until now `settle_lease_charges_v1` (0482)
-- wrote the lease term's label 'Settlement <from> to <to>' and the expense
-- schedule's title 'Service charge settlement — <supplier>' in English and
-- ISO dates, whatever the business's language.
--
-- Both records keep that text, the fallback any reader prints, and also hold
-- what it says as facts (`text_facts`, the shape of 0738: {kind, version,
-- values}), frozen when the settlement is written: `settlement_period`
-- {from, to} on the term, `service_charge_settlement` {supplier} on the
-- schedule. The app prints the facts in the reader's language. A schedule's
-- title the owner edits is the owner's own text: the edit drops its facts,
-- and the typed title is printed as typed. A lease term is never edited
-- (0474), so its facts stand. Records already written keep their text.

alter table public.lease_terms add column if not exists text_facts jsonb;
alter table public.lease_terms
  drop constraint if exists lease_terms_text_facts_check,
  add constraint lease_terms_text_facts_check check (
    text_facts is null
    or (jsonb_typeof(text_facts) = 'object'
        and jsonb_typeof(text_facts -> 'kind') = 'string'
        and jsonb_typeof(text_facts -> 'version') = 'number'
        and jsonb_typeof(text_facts -> 'values') = 'object'));

alter table public.expense_schedules add column if not exists text_facts jsonb;
alter table public.expense_schedules
  drop constraint if exists expense_schedules_text_facts_check,
  add constraint expense_schedules_text_facts_check check (
    text_facts is null
    or (jsonb_typeof(text_facts) = 'object'
        and jsonb_typeof(text_facts -> 'kind') = 'string'
        and jsonb_typeof(text_facts -> 'version') = 'number'
        and jsonb_typeof(text_facts -> 'values') = 'object'));

-- An owner's title is their own text: an edit of it drops the facts.
create or replace function public.expense_schedules_title_facts()
returns trigger language plpgsql as $fn$
begin
  if new.title is distinct from old.title
     and new.text_facts is not distinct from old.text_facts then
    new.text_facts := null;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.expense_schedules_title_facts() from public, anon, authenticated;
drop trigger if exists expense_schedules_title_facts on public.expense_schedules;
create trigger expense_schedules_title_facts
  before update of title on public.expense_schedules
  for each row execute function public.expense_schedules_title_facts();

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if position(p_old in p_def) = 0 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  -- The settlement writes the facts beside its texts.
  select pg_get_functiondef('public.settle_lease_charges_v1'::regproc) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $r$       unit, every, repeat_count, status, next_due, origin, contract_id)
    values (l.workspace_id, l.responsible_member_id, l.supplier_id,
            left('Service charge settlement — ' || v_name, 80), l.premises, v_balance::int,
            p_due_on, p_due_on, 'month', 1, 1, 'active', p_due_on, 'workspace_contract', l.id)$r$,
    $r$       unit, every, repeat_count, status, next_due, origin, contract_id, text_facts)
    values (l.workspace_id, l.responsible_member_id, l.supplier_id,
            left('Service charge settlement — ' || v_name, 80), l.premises, v_balance::int,
            p_due_on, p_due_on, 'month', 1, 1, 'active', p_due_on, 'workspace_contract', l.id,
            -- #3813: the supplier as it was; the app prints it in its language.
            jsonb_build_object('kind', 'service_charge_settlement', 'version', 1,
              'values', jsonb_build_object('supplier', coalesce(v_name, ''))))$r$);
  v_def := pg_temp.anchor_replace(v_def,
    $r$       schedule_id, created_by)
    values (l.workspace_id, l.id, 'other', v_label, v_balance::int, 1, p_due_on, p_due_on, v_schedule, v_me)$r$,
    $r$       schedule_id, created_by, text_facts)
    values (l.workspace_id, l.id, 'other', v_label, v_balance::int, 1, p_due_on, p_due_on, v_schedule, v_me,
            -- #3813: the period as it was; the app prints it in its language.
            jsonb_build_object('kind', 'settlement_period', 'version', 1,
              'values', jsonb_build_object('from', p_period_start::text, 'to', p_period_end::text)))$r$);
  if v_def is null then
    raise exception 'an anchor of #3813 was not found in settle_lease_charges_v1' using errcode = 'P0001';
  end if;
  execute v_def;

  -- The lease the app reads carries each term's facts.
  select pg_get_functiondef('public.premises_lease_json(public.premises_leases)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $r$'id', t.id, 'kind', t.kind, 'label', t.label, 'amount_cents', t.amount_cents,$r$,
    $r$'id', t.id, 'kind', t.kind, 'label', t.label, 'text', t.text_facts, 'amount_cents', t.amount_cents,$r$);
  if v_def is null then
    raise exception 'the #3813 anchor was not found in premises_lease_json' using errcode = 'P0001';
  end if;
  execute v_def;
end;
$migration$;

select public.set_deskilo_schema_version(744);
