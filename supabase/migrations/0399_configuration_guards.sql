-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0399 (#2332) — configuration mistakes a new owner could still make.
--
-- 1. The currency and the country are fixed once the space has issued a
--    document or recorded money: amounts are stored in minor units with no
--    conversion, and the country decides the invoice rules. A BEFORE UPDATE
--    trigger refuses the change (SQLSTATE DK423) for every writer —
--    save_workspace_settings (0241), the direct row update of an import,
--    anything else.
-- 2. workspace_readiness v7, restated whole from 0307's body:
--    * roles_validation is REQUIRED whenever a rule needs more validators
--      than exist, in every domain (it was required only for bookings);
--    * member_permissions (new, required): members cannot book until the
--      owner grants makeReservations — a real space starts with an empty
--      member matrix (0373); count = everyday permissions granted;
--    * legal_identity (new, required while invoicing is effective): no
--      invoice can be issued without it; the optional local_setup section
--      stops repeating that slot.
--    Older apps drop sections they do not know.

create or replace function public.workspaces_money_locale_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if (new.currency_code is distinct from old.currency_code
      or new.country_code is distinct from old.country_code)
     and (exists (select 1 from public.invoices i where i.workspace_id = new.id)
          or exists (select 1 from public.ledger_entries l where l.workspace_id = new.id)) then
    raise exception 'money_locale_locked: the currency and the country are fixed once this space has issued a document or recorded money'
      using errcode = 'DK423';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_money_locale_guard() from public, anon;

drop trigger if exists workspaces_money_locale_guard on public.workspaces;
create trigger workspaces_money_locale_guard
  before update of currency_code, country_code on public.workspaces
  for each row execute function public.workspaces_money_locale_guard();

create or replace function public.workspace_readiness(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  w public.workspaces;
  v_seats integer;
  v_members integer;
  v_invitations integer;
  v_pricing boolean;
  v_payments boolean;
  v_local jsonb;
  v_gap jsonb;
  v_policies integer;
  v_short jsonb;
  v_exposed boolean;
  v_eligibility text;
  v_booked boolean;
  v_export timestamptz;
  v_recent boolean;
  v_invoicing boolean;
  v_identity boolean;
  v_everyday integer;
  v_out jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace sees how ready it is';
  end if;
  select * into w from public.workspaces where id = p_workspace_id;
  select count(*) into v_seats from public.seats where workspace_id = p_workspace_id;
  select count(*) into v_members from public.members where workspace_id = p_workspace_id and status = 'active';
  select count(*) into v_invitations from public.invitations where workspace_id = p_workspace_id;
  v_pricing := exists (select 1 from public.plans where workspace_id = p_workspace_id)
            or exists (select 1 from public.fee_bands where workspace_id = p_workspace_id)
            or coalesce(jsonb_typeof(w.subscription_levels) = 'object' and w.subscription_levels <> '{}'::jsonb, false);
  v_payments := exists (select 1 from jsonb_each_text(coalesce(w.payment_instructions, '{}'::jsonb)) e where trim(e.value) <> '')
             or exists (select 1 from public.payment_credentials c where c.workspace_id = p_workspace_id);
  -- #1636 — what the features switched on still need locally (0280),
  -- as one section: its first gap is where it is set up.
  v_local := public.workspace_local_readiness(p_workspace_id);
  -- #2332 (0399) — under invoicing the legal identity is its own REQUIRED
  -- section below, so the optional local section no longer repeats it.
  v_invoicing := public.feature_effective(p_workspace_id, 'invoicing');
  v_identity := coalesce(trim(w.legal_id), '') <> ''
            and (coalesce(trim(w.street), '') <> '' or coalesce(trim(w.address), '') <> '');
  if v_invoicing then
    v_local := coalesce((select jsonb_agg(e) from jsonb_array_elements(v_local) e
                          where e->>'slot' is distinct from 'legal_identity'), '[]'::jsonb);
  end if;
  -- #2332 (0399) — a real space starts with an empty member matrix (0373):
  -- until the owner grants makeReservations a plain member cannot book.
  -- The count is how many of the six everyday permissions members hold.
  select count(*) into v_everyday
    from jsonb_array_elements_text(case when jsonb_typeof(w.role_permissions->'member') = 'array'
                                        then w.role_permissions->'member' else '[]'::jsonb end) g
   where g in ('useMessages', 'makeReservations', 'viewCalendar', 'viewDirectory', 'viewMyMoney', 'viewDocuments');
  select e into v_gap from jsonb_array_elements(v_local) e
   where not coalesce((e->>'filled')::boolean, false) limit 1;
  -- #1636 (0294) — a validation policy nobody can satisfy leaves its
  -- requests pending forever. The pool per policy is the one the decision
  -- functions use (0135): the owner, then by scope every active member,
  -- the listed ones, or the admins it admits.
  select count(*) into v_policies from public.validation_policies where workspace_id = p_workspace_id;
  select coalesce(jsonb_agg(p.event_type), '[]'::jsonb) into v_short
    from public.validation_policies p
   where p.workspace_id = p_workspace_id
     and p.required_count > (
       select count(*) from public.members m
        where m.workspace_id = p_workspace_id and m.status = 'active'
          and (m.is_owner
               or coalesce(p.validator_scope, 'admins') = 'members'
               or (coalesce(p.validator_scope, 'admins') = 'listed'
                   and m.id = any(p.eligible_admin_ids))
               or (coalesce(p.validator_scope, 'admins') = 'admins'
                   and m.is_admin and p.admins_may_validate
                   and (cardinality(p.eligible_admin_ids) = 0
                        or m.id = any(p.eligible_admin_ids)))));
  -- #1636 (0294) — assistant access is optional, and listed only while
  -- mcpAccess is on. Two of its gates are readable here: the owner's
  -- exposure of this workspace (0271) and the caller's own current
  -- database eligibility (my_database_capabilities, 1718), which a
  -- database administrator grants once per database.
  v_exposed := exists (select 1 from public.workspace_mcp_policies mp
                        where mp.workspace_id = p_workspace_id and mp.enabled
                          and cardinality(mp.operations) > 0);
  v_eligibility := public.my_database_capabilities()->>'mcp_eligibility';
  -- #1636 (0296) — has the space been used yet: one booking that was not
  -- cancelled or released. Read, never made to find out.
  v_booked := exists (select 1 from public.reservations r
                       where r.workspace_id = p_workspace_id
                         and r.status in ('reserved', 'checked_in', 'completed'));
  -- #1636 (0301) — recovery evidence is a completed export the app
  -- recorded (record_workspace_export), never a checkbox: recent within
  -- 90 days, stale after, none at all otherwise.
  select max(e.recorded_at) into v_export from public.workspace_recovery_evidence e
   where e.workspace_id = p_workspace_id and e.kind = 'export';
  v_recent := v_export is not null and v_export >= now() - interval '90 days';
  v_out := jsonb_build_array(
    jsonb_build_object('section', 'region_rules', 'actor', 'owner', 'required', true, 'route', '/availability',
      'state', case when coalesce(w.timezone, '') <> '' and coalesce(w.currency_code, '') <> ''
                     and case when jsonb_typeof(w.booking_rules->'open_weekdays') = 'array'
                              then jsonb_array_length(w.booking_rules->'open_weekdays') > 0 else false end
                    then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'resources', 'actor', 'owner', 'required', true, 'route', '/editor',
      'state', case when v_seats > 0 then 'ready' else 'needs_configuration' end, 'count', v_seats),
    jsonb_build_object('section', 'pricing', 'actor', 'owner', 'required', false, 'route', '/billing',
      'state', case when v_pricing then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'invitations', 'actor', 'owner', 'required', false, 'route', '/workspace-code',
      'state', case when v_members > 1 or v_invitations > 0 then 'ready' else 'needs_configuration' end,
      'count', v_members),
    jsonb_build_object('section', 'payments', 'actor', 'owner', 'required', false, 'route', '/payment-methods',
      'state', case when v_payments then 'ready' else 'needs_configuration' end),
    -- #2332 (0399) — a rule nobody can satisfy leaves its requests pending
    -- forever in EVERY domain, not only bookings: required whenever short.
    jsonb_build_object('section', 'roles_validation', 'actor', 'owner', 'required',
      jsonb_array_length(v_short) > 0,
      'route', '/validation',
      'state', case when v_policies = 0 then 'not_applicable'
                    when jsonb_array_length(v_short) > 0 then 'needs_configuration' else 'ready' end,
      'reason', case when v_policies = 0 then 'no_policies'
                     when jsonb_array_length(v_short) > 0 then 'too_few_validators' end,
      'count', jsonb_array_length(v_short)),
    jsonb_build_object('section', 'recovery', 'actor', 'operator', 'required', false,
      'route', '/workspace-settings',
      'state', case when v_recent then 'ready' else 'unverified' end,
      'reason', case when v_export is null then 'no_evidence'
                     when v_recent then 'recent_export' else 'stale_export' end,
      'recorded_at', v_export),
    -- #2332 (0399) — what members may do: required, since without
    -- makeReservations a plain member cannot book at all.
    jsonb_build_object('section', 'member_permissions', 'actor', 'owner', 'required', true,
      'route', '/roles',
      'state', case when coalesce(w.role_permissions->'member', '[]'::jsonb) ? 'makeReservations'
                    then 'ready' else 'needs_configuration' end,
      'reason', case when not coalesce(w.role_permissions->'member', '[]'::jsonb) ? 'makeReservations'
                     then 'members_cannot_book' end,
      'count', v_everyday))
    -- #2332 (0399) — invoicing on without the seller's legal identity: no
    -- invoice can be issued, so the identity is a required step.
    || case when not v_invoicing then '[]'::jsonb
       else jsonb_build_array(jsonb_build_object('section', 'legal_identity', 'actor', 'owner', 'required', true,
         'route', '/legal-identity',
         'state', case when v_identity then 'ready' else 'needs_configuration' end,
         'reason', case when not v_identity then 'invoicing_needs_identity' end))
       end
    || case when jsonb_array_length(v_local) = 0 then '[]'::jsonb
       else jsonb_build_array(jsonb_build_object('section', 'local_setup', 'actor', 'owner', 'required', false,
         'route', coalesce(v_gap->>'route', '/workspace-settings'),
         'state', case when v_gap is null then 'ready' else 'needs_configuration' end,
         'count', (select count(*) from jsonb_array_elements(v_local) e
                    where not coalesce((e->>'filled')::boolean, false))))
       end
    || case when not public.feature_effective(p_workspace_id, 'mcpAccess') then '[]'::jsonb
       else jsonb_build_array(jsonb_build_object('section', 'assistant', 'required', false,
         'actor', case when v_exposed then 'administrator' else 'owner' end,
         'route', case when v_exposed then '/assistants' else '/settings/assistants' end,
         'state', case when not v_exposed then 'needs_configuration'
                       when v_eligibility is distinct from 'eligible' then 'needs_operator' else 'ready' end,
         'reason', case when not v_exposed then 'not_exposed'
                        when v_eligibility is distinct from 'eligible'
                        then 'eligibility_' || coalesce(v_eligibility, 'unknown') end))
       end
    || jsonb_build_array(jsonb_build_object('section', 'first_booking', 'actor', 'owner',
         'required', false, 'route', '/reserve',
         'state', case when v_booked then 'ready' else 'needs_configuration' end));
  -- #1636 (0307) -- "I'll do it later": a section the caller set aside
  -- reads acknowledged only while it is still optional, still open, and
  -- still what it was when they set it aside (the same material revision,
  -- in this installation, for this caller). It never changes the state:
  -- an acknowledged recovery section stays unverified.
  return (
    select coalesce(jsonb_agg(
      case when not coalesce((t.e->>'required')::boolean, false)
             and t.e->>'state' not in ('ready', 'not_applicable')
             and exists (select 1 from public.readiness_acknowledgements a
                          where a.installation_id = public.installation_id()
                            and a.workspace_id = p_workspace_id
                            and a.user_id = auth.uid()
                            and a.section = t.e->>'section'
                            and a.material_revision = public.readiness_section_revision(t.e))
           then t.e || jsonb_build_object('acknowledged', true) else t.e end
      order by t.n), '[]'::jsonb)
      from jsonb_array_elements(v_out) with ordinality t(e, n));
end;
$fn$;
revoke execute on function public.workspace_readiness(uuid) from public, anon;
grant execute on function public.workspace_readiness(uuid) to authenticated;

select public.set_deskilo_schema_version(399);
