-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (set_payment_credentials, set_einvoice_credentials, clear_einvoice_credentials
-- and event_type_view_permissions restated whole from their current
-- definitions: same signatures, same ACLs; each credential function gains one
-- call. events_type_check and validation_policies_event_type_check each gain
-- one type.)
--
-- #3914 -- a change of a workspace's payment or e-invoicing credentials leaves
-- an entry where its other administrative events are read: who, when, which
-- provider, whether they were set, replaced or cleared, and the NAMES of the
-- keys changed. A value is never recorded.

-- ── the event type ─────────────────────────────────────────────────────
do $constraints$
declare r record; v_def text;
begin
  for r in select * from (values
    ('events','events_type_check','type'),
    ('validation_policies','validation_policies_event_type_check','event_type')
  ) as c(table_name,constraint_name,column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid=('public.'||r.table_name)::regclass and conname=r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception 'event type constraint anchor missing: %',r.constraint_name using errcode = 'P0001';
    end if;
    if position('credential_change' in v_def)=0 then
      execute format('alter table public.%I drop constraint %I',r.table_name,r.constraint_name);
      execute format('alter table public.%I add constraint %I ',r.table_name,r.constraint_name)
        || replace(v_def,'CHECK (',format('CHECK (%I = %L OR ',r.column_name,'credential_change'));
    end if;
  end loop;
end;
$constraints$;

-- Who reads the entry: whoever may manage the integrations, the right that
-- changes the credentials (the owner holds every permission). The current
-- body (0650, patched by 0722, 0723 and 0734), one type more.
create or replace function public.event_type_view_permissions(p_type text)
returns text[] language sql immutable set search_path = public as $fn$
  select case
    when p_type in ('payment', 'adjustment', 'service_charge', 'invoice_payment',
                    'invoice_payment_reversed',
                    'invoice_writeoff', 'invoice_reminder', 'invoice_issue',
                    'invoice_void', 'refund', 'usage_correction', 'usage_record_delete')
      then array['viewFinances', 'issueInvoices']
    when p_type in ('expense', 'expense_schedule', 'expense_repartition')
      then array['approveExpenses', 'viewFinances']
    when p_type in ('reservation', 'space_reservation', 'reservation_delete')
      then array['manageReservations']
    when p_type = 'quota'
      then array['manageReservations', 'viewFinances', 'issueInvoices']
    when p_type in ('member_join', 'member_status_change', 'subscription_change', 'role_change')
      then array['manageMembers']
    when p_type = 'matrix_change'
      then array['manageRoles', 'manageMembers']
    when p_type = 'price_negotiation'
      then array['viewNegotiations']
    when p_type = 'payment_terms_change'
      then array['paymentTermsEdit', 'viewNegotiations']
    when p_type = 'lease_change'
      then array['manageLease', 'viewFinances']
    when p_type = 'commitment_variance'
      then array['managePurchases', 'viewFinances']
    when p_type = 'badge_security_alert'
      then array['workspaceSettings']
    when p_type in ('payment_instructions_change', 'credential_change')
      then array['manageIntegrations']
    when p_type = 'privacy_incident'
      then array['managePrivacy']
    when p_type = 'invoice_issued'
      then array['viewFinances', 'issueInvoices']
    when p_type = 'settlement_review'
      then array['viewFinances']
    when p_type = 'kiosk_device'
      then array['workspaceSettings']
    else array['manageConfiguration']
  end;
$fn$;
revoke execute on function public.event_type_view_permissions(text) from public,anon;
grant execute on function public.event_type_view_permissions(text) to authenticated;

-- ── the one helper ─────────────────────────────────────────────────────
-- Records that credentials of p_workspace_id changed: p_area 'payment' or
-- 'einvoice', the provider, the names of the keys (sorted, never a value) and
-- the change: 'set' (nothing was stored), 'replace' (something was), 'clear'.
-- Called only by the credential functions, which have checked the right.
create or replace function public.record_credential_change(
  p_workspace_id uuid, p_area text, p_provider text, p_keys text[], p_change text
) returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_actor uuid;
  v_owner uuid;
begin
  if p_area not in ('payment', 'einvoice') or p_change not in ('set', 'replace', 'clear') then
    raise exception 'unknown credential change % %', p_area, p_change using errcode = '22023';
  end if;
  select m.id into v_actor from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  select m.id into v_owner from public.members m
   where m.workspace_id = p_workspace_id and m.is_owner and m.status = 'active'
   order by m.joined_at, m.id limit 1;
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (p_workspace_id, 'credential_change', 'modified',
    coalesce(v_actor, v_owner), coalesce(v_owner, v_actor),
    jsonb_build_object(
      'area', p_area,
      'provider', coalesce(p_provider, ''),
      'change', p_change,
      'keys', to_jsonb(coalesce((select array_agg(k order by k) from unnest(p_keys) k), '{}'::text[]))),
    'applied');
end;
$fn$;
revoke execute on function public.record_credential_change(uuid, text, text, text[], text)
  from public, anon, authenticated;

-- ── payment credentials ────────────────────────────────────────────────
create or replace function public.set_payment_credentials(p_workspace_id uuid, p_provider text, p_config jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $fn$
declare
  v_clean jsonb;
  v_stored_before boolean;
begin
  if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'not the owner of this workspace' using errcode = 'DKN01';
  end if;
  if p_provider not in ('paypal','stripe','mollie','wero') then
    raise exception 'unknown provider' using errcode = '22023';
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_clean
    from jsonb_each(coalesce(p_config, '{}'::jsonb))
    where value is not null and trim(both '"' from value::text) <> '';
  if v_clean = '{}'::jsonb then return; end if;

  v_stored_before := exists (select 1 from public.payment_credentials
                              where workspace_id = p_workspace_id and provider = p_provider);
  insert into public.payment_credentials (workspace_id, provider, config, updated_at)
  values (p_workspace_id, p_provider, v_clean, now())
  on conflict (workspace_id, provider)
    do update set config = public.payment_credentials.config || v_clean,
                  updated_at = now();
  -- #3914 -- the names of the keys, never their values.
  perform public.record_credential_change(p_workspace_id, 'payment', p_provider,
    array(select jsonb_object_keys(v_clean)),
    case when v_stored_before then 'replace' else 'set' end);
end;
$fn$;
revoke execute on function public.set_payment_credentials(uuid, text, jsonb) from public, anon;

-- ── e-invoicing credentials ────────────────────────────────────────────
create or replace function public.set_einvoice_credentials(p_workspace_id uuid, p_config jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $fn$
declare
  v_clean jsonb;
  v_stored jsonb := '{}'::jsonb;
  v_provider text;
  v_entry record;
  v_old jsonb;
  v_key text;
begin
  if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'not the owner of this workspace' using errcode = 'DKN01';
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_clean
    from jsonb_each(coalesce(p_config, '{}'::jsonb))
    where value is not null and trim(both '"' from value::text) <> '';
  if v_clean = '{}'::jsonb then return; end if;

  -- #2358 — the connector is a column, never a config value.
  v_provider := v_clean ->> 'provider';
  v_clean := v_clean - 'provider';
  if v_provider is not null and v_provider not in
       ('generic', 'peppol', 'fr_pa', 'it_sdi', 'pl_ksef', 'ro_efactura') then
    raise exception 'unknown e-invoice provider %', v_provider
      using errcode = '22023';
  end if;

  for v_entry in select key, value from jsonb_each(v_clean) loop
    if public.einvoice_config_is_secret(v_entry.key) then
      v_stored := v_stored || jsonb_build_object(v_entry.key,
        public.einvoice_store_secret(p_workspace_id, v_entry.key,
                                     v_entry.value #>> '{}'));
    else
      v_stored := v_stored || jsonb_build_object(v_entry.key, v_entry.value);
    end if;
  end loop;

  -- A connection moved to another host keeps no secret it was not sent
  -- with: the secrets are entered again for the new host.
  select config into v_old from public.einvoice_credentials where workspace_id = p_workspace_id for update;
  if v_old is not null and exists (
       select 1 from jsonb_each(v_stored) n
        where n.key ~ '^(customer_)?(endpoint|base_url|token_url|login_url)(_uat|_dev)?$'
          and n.value is distinct from v_old -> n.key) then
    for v_key in select key from jsonb_each(v_old) loop
      if public.einvoice_config_is_secret(v_key) and not (v_stored ? v_key) then
        delete from vault.secrets where name = public.einvoice_secret_name(p_workspace_id, v_key);
        update public.einvoice_credentials set config = config - v_key where workspace_id = p_workspace_id;
      end if;
    end loop;
  end if;
  insert into public.einvoice_credentials
    (workspace_id, provider, config, updated_at)
  values (p_workspace_id, coalesce(v_provider, 'generic'), v_stored, now())
  on conflict (workspace_id) do update
    set config = public.einvoice_credentials.config || v_stored,
        provider = coalesce(v_provider, public.einvoice_credentials.provider),
        updated_at = now();
  -- #3914 -- the names of the keys, never their values.
  perform public.record_credential_change(p_workspace_id, 'einvoice',
    (select c.provider from public.einvoice_credentials c where c.workspace_id = p_workspace_id),
    array(select jsonb_object_keys(v_clean)),
    case when v_old is not null then 'replace' else 'set' end);
end;
$fn$;
revoke execute on function public.set_einvoice_credentials(uuid, jsonb) from public, anon;

create or replace function public.clear_einvoice_credentials(p_workspace_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'vault'
as $fn$
declare
  v_old record;
begin
  if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'not the owner of this workspace' using errcode = 'DKN01';
  end if;
  select c.provider, c.config into v_old from public.einvoice_credentials c
   where c.workspace_id = p_workspace_id;
  delete from vault.secrets
   where name like public.einvoice_secret_name(p_workspace_id, '') || '%';
  delete from public.einvoice_credentials where workspace_id = p_workspace_id;
  -- #3914 -- what was cleared, by the names of its keys; nothing stored,
  -- nothing to record.
  if found then
    perform public.record_credential_change(p_workspace_id, 'einvoice', v_old.provider,
      array(select jsonb_object_keys(coalesce(v_old.config, '{}'::jsonb))), 'clear');
  end if;
end;
$fn$;
revoke execute on function public.clear_einvoice_credentials(uuid) from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(796);
