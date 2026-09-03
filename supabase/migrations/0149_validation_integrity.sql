-- Copyright (c) 2026 Florian DITTGEN
-- SPDX-License-Identifier: 0BSD
--
-- #840 — the configured validation rule must actually hold.
--
-- Three holes sat around a sound rule. `respond_to_event` has refused the
-- actor since 0086 and still does, so nobody validates an event they
-- created. But:
--
--   1. The four money operations that write their own event
--      (match_invoice, settle_credit_invoice, settle_invoices,
--      distribute_expense) looked for a policy row of their exact type
--      and nothing else. A workspace-wide default rule governed every
--      other event and not those, so marking an invoice paid, refunding
--      it or regrouping it stayed confirmed on the spot by its author.
--      They now consult the default row too.
--
--   2. `v_required` was clamped to the size of the eligible pool. A rule
--      asking for two validations quietly became one whenever the pool
--      shrank to a single person. The configured number now holds; a
--      pool too small to reach it leaves the event pending until it
--      expires, which is the safe outcome, not a silent downgrade.
--
--   3. There was no way to say whether the owner may sign off on their
--      own act. `owner_may_self_validate` says it, and it is the only
--      exception: false by default, and never available to an admin.
--
-- `sequential` asks for the validations one at a time. Each accept that
-- does not complete the quorum raises `payload.validation_stage`, so the
-- next validator is asked for a numbered step instead of joining an
-- open quorum.

alter table public.validation_policies
  add column if not exists owner_may_self_validate boolean not null default false,
  add column if not exists sequential boolean not null default false;

comment on column public.validation_policies.owner_may_self_validate is
  '#840 — the owner, and only the owner, may validate their own event.';
comment on column public.validation_policies.sequential is
  '#840 — validations are requested one after another, not as one quorum.';

-- The money RPCs: a workspace default rule governs them too.
do $patch$
declare
  v_name text;
  v_type text;
  v_def text;
  v_new text;
begin
  for v_name, v_type in
    select * from (values
      ('match_invoice', 'invoice_payment'),
      ('settle_credit_invoice', 'invoice_payment'),
      ('settle_invoices', 'invoice_payment'),
      ('distribute_expense', 'expense_repartition')) as t(n, y)
  loop
    select pg_get_functiondef(p.oid) into v_def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = v_name;
    if v_def is null then
      raise exception 'missing %', v_name;
    end if;
    if position('vp.event_type = ''' || v_type || '''' in v_def) = 0 then
      raise exception '% no longer looks up a % policy', v_name, v_type;
    end if;
    v_new := replace(v_def,
      'vp.event_type = ''' || v_type || ''')',
      '(vp.event_type = ''' || v_type || ''' or vp.event_type is null))');
    if v_new = v_def then
      raise exception '% policy lookup did not change', v_name;
    end if;
    execute v_new;
  end loop;
end;
$patch$;

-- respond_to_event: the owner exception, and the count that holds.
do $patch$
declare
  v_def text;
  v_new text;
  v_actor_guard constant text := 'v_caller.id <> v_event.actor_member_id';
  v_owner_ok constant text :=
    '(v_caller.id <> v_event.actor_member_id'
    || ' or (v_caller.is_owner'
    || ' and coalesce(v_policy.owner_may_self_validate, false)))';
  v_clamp constant text :=
    'v_required := greatest(1, least(v_policy.required_count,' || E'\n'
    || '    v_pool_size + case when v_subject_decides then 1 else 0 end));';
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'respond_to_event';
  if v_def is null then
    raise exception 'respond_to_event is missing';
  end if;
  if position('owner_may_self_validate' in v_def) > 0 then
    return;  -- already patched
  end if;
  if (length(v_def) - length(replace(v_def, v_actor_guard, '')))
     / length(v_actor_guard) <> 2 then
    raise exception 'expected exactly two self-validation guards';
  end if;
  if position(v_clamp in v_def) = 0 then
    raise exception 'the required-count clamp is not where it was';
  end if;

  -- The no-row fallback builds v_policy by hand: it has to carry the new
  -- fields, or reading them raises "record has no field".
  v_new := replace(v_def,
    'false as owner_required, ''admins''::text as validator_scope',
    'false as owner_required, ''admins''::text as validator_scope,' || E'\n'
    || '           false as owner_may_self_validate, false as sequential');
  if v_new = v_def then
    raise exception 'the no-policy fallback is not where it was';
  end if;
  v_new := replace(v_new, v_actor_guard, v_owner_ok);
  v_new := replace(v_new, v_clamp,
    '-- #840 — the configured number holds.' || E'\n'
    || '  v_required := greatest(1, v_policy.required_count);');
  -- #840 — sequential rules number the step that is now being asked for.
  v_new := replace(v_new,
    'select count(*) into v_accepts from public.event_decisions' || E'\n'
    || '    where event_id = p_event_id and decision = ''accept'';',
    'select count(*) into v_accepts from public.event_decisions' || E'\n'
    || '    where event_id = p_event_id and decision = ''accept'';' || E'\n'
    || '  if coalesce(v_policy.sequential, false) then' || E'\n'
    || '    update public.events set payload = payload' || E'\n'
    || '      || jsonb_build_object(''validation_stage'', v_accepts + 1)' || E'\n'
    || '     where id = p_event_id;' || E'\n'
    || '  end if;');
  if v_new = v_def then
    raise exception 'respond_to_event did not change';
  end if;
  execute v_new;
end;
$patch$;
