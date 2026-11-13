-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0745 — #3821 (part of #3657, i18n I11f): a permission refusal carries the
-- code DKN01 ("not allowed"), as the booking and invoicing refusals carry
-- theirs since 0739 and 0742, so the app maps the code, never the sentence.
-- The 58 refusals a business raises when a person may not do something
-- ("not an admin of this workspace", "only admins may", ...) in 56 functions
-- keep their English message for an app from before and add the code, with
-- no detail: the code tells a caller who is not allowed nothing the sentence
-- did not already tell, no permission, role or record. Where a function
-- answers the same for "not allowed" and "does not exist", it still does.
--
-- DKN01 is not 42501: a row-level-security denial (42501) and a business
-- refusal are different facts and stay different. What catches a refusal
-- catches DKN01 as it catches the other codes, so the assistant's answer is
-- what it was: "refused", with its reason.

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

do $refusals$
declare
  v_def text;
begin
  -- activate_co_owner
  select pg_get_functiondef('public.activate_co_owner(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in activate_co_owner' using errcode = 'P0001';
  end if;
  execute v_def;

  -- admin_create_reservation_for
  select pg_get_functiondef('public.admin_create_reservation_for(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in admin_create_reservation_for' using errcode = 'P0001';
  end if;
  execute v_def;

  -- clear_einvoice_credentials
  select pg_get_functiondef('public.clear_einvoice_credentials(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in clear_einvoice_credentials' using errcode = 'P0001';
  end if;
  execute v_def;

  -- clear_payment_provider
  select pg_get_functiondef('public.clear_payment_provider(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in clear_payment_provider' using errcode = 'P0001';
  end if;
  execute v_def;

  -- confirm_tax_reference
  select pg_get_functiondef('public.confirm_tax_reference(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'platform owners only';$r$,
    $r$raise exception 'platform owners only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in confirm_tax_reference' using errcode = 'P0001';
  end if;
  execute v_def;

  -- create_invitation
  select pg_get_functiondef('public.create_invitation(uuid,boolean,text,text,uuid,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only owners may invite admins';$r$,
    $r$raise exception 'only owners may invite admins' using errcode = 'DKN01';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only admins may invite members';$r$,
    $r$raise exception 'only admins may invite members' using errcode = 'DKN01';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to manage this profile';$r$,
    $r$raise exception 'not allowed to manage this profile' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in create_invitation' using errcode = 'P0001';
  end if;
  execute v_def;

  -- create_managed_member
  select pg_get_functiondef('public.create_managed_member(uuid,jsonb,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only admins may add managed profiles';$r$,
    $r$raise exception 'only admins may add managed profiles' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in create_managed_member' using errcode = 'P0001';
  end if;
  execute v_def;

  -- create_workspace_twin
  select pg_get_functiondef('public.create_workspace_twin(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only owners may create the twin';$r$,
    $r$raise exception 'only owners may create the twin' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in create_workspace_twin' using errcode = 'P0001';
  end if;
  execute v_def;

  -- delete_site
  select pg_get_functiondef('public.delete_site(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'admins only';$r$,
    $r$raise exception 'admins only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in delete_site' using errcode = 'P0001';
  end if;
  execute v_def;

  -- einvoice_status
  select pg_get_functiondef('public.einvoice_status(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in einvoice_status' using errcode = 'P0001';
  end if;
  execute v_def;

  -- issue_member_badge
  select pg_get_functiondef('public.issue_member_badge(uuid,uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in issue_member_badge' using errcode = 'P0001';
  end if;
  execute v_def;

  -- list_all_workspaces
  select pg_get_functiondef('public.list_all_workspaces()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'platform owners only';$r$,
    $r$raise exception 'platform owners only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in list_all_workspaces' using errcode = 'P0001';
  end if;
  execute v_def;

  -- managed_identity_of
  select pg_get_functiondef('public.managed_identity_of(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to read this profile';$r$,
    $r$raise exception 'not allowed to read this profile' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in managed_identity_of' using errcode = 'P0001';
  end if;
  execute v_def;

  -- payment_credentials_status
  select pg_get_functiondef('public.payment_credentials_status(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in payment_credentials_status' using errcode = 'P0001';
  end if;
  execute v_def;

  -- record_service_charge
  select pg_get_functiondef('public.record_service_charge(uuid,uuid,uuid,integer,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only admins may add services for other members';$r$,
    $r$raise exception 'only admins may add services for other members' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in record_service_charge' using errcode = 'P0001';
  end if;
  execute v_def;

  -- register_nfc_badge
  select pg_get_functiondef('public.register_nfc_badge(uuid,uuid,text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in register_nfc_badge' using errcode = 'P0001';
  end if;
  execute v_def;

  -- request_invoice_writeoff
  select pg_get_functiondef('public.request_invoice_writeoff(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only admins may cancel outstanding amounts';$r$,
    $r$raise exception 'only admins may cancel outstanding amounts' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in request_invoice_writeoff' using errcode = 'P0001';
  end if;
  execute v_def;

  -- request_matrix_change
  select pg_get_functiondef('public.request_matrix_change(uuid,text,text[])'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only role managers may edit permissions';$r$,
    $r$raise exception 'only role managers may edit permissions' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in request_matrix_change' using errcode = 'P0001';
  end if;
  execute v_def;

  -- request_matrix_permission
  select pg_get_functiondef('public.request_matrix_permission(uuid,text,text,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only role managers may edit permissions';$r$,
    $r$raise exception 'only role managers may edit permissions' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in request_matrix_permission' using errcode = 'P0001';
  end if;
  execute v_def;

  -- request_role_change
  select pg_get_functiondef('public.request_role_change(uuid,uuid,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only owners may change roles';$r$,
    $r$raise exception 'only owners may change roles' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in request_role_change' using errcode = 'P0001';
  end if;
  execute v_def;

  -- reset_work_hours
  select pg_get_functiondef('public.reset_work_hours(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only workspace settings managers may change the booking rules';$r$,
    $r$raise exception 'only workspace settings managers may change the booking rules' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in reset_work_hours' using errcode = 'P0001';
  end if;
  execute v_def;

  -- reset_workspace
  select pg_get_functiondef('public.reset_workspace(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only owners may reset the workspace';$r$,
    $r$raise exception 'only owners may reset the workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in reset_workspace' using errcode = 'P0001';
  end if;
  execute v_def;

  -- revoke_handover
  select pg_get_functiondef('public.revoke_handover(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to manage this profile';$r$,
    $r$raise exception 'not allowed to manage this profile' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in revoke_handover' using errcode = 'P0001';
  end if;
  execute v_def;

  -- revoke_member_badge
  select pg_get_functiondef('public.revoke_member_badge(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in revoke_member_badge' using errcode = 'P0001';
  end if;
  execute v_def;

  -- send_member_note
  select pg_get_functiondef('public.send_member_note(uuid,uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only admins may notify all admins';$r$,
    $r$raise exception 'only admins may notify all admins' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in send_member_note' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_billing_rule
  select pg_get_functiondef('public.set_billing_rule(uuid,text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only workspace settings managers may change the billing rules';$r$,
    $r$raise exception 'only workspace settings managers may change the billing rules' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_billing_rule' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_booking_rule
  select pg_get_functiondef('public.set_booking_rule(uuid,text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only workspace settings managers may change the booking rules';$r$,
    $r$raise exception 'only workspace settings managers may change the booking rules' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_booking_rule' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_co_owner
  select pg_get_functiondef('public.set_co_owner(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_co_owner' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_dev_mode
  select pg_get_functiondef('public.set_dev_mode(uuid,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_dev_mode' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_einvoice_credentials
  select pg_get_functiondef('public.set_einvoice_credentials(uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_einvoice_credentials' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_level_site
  select pg_get_functiondef('public.set_level_site(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'admins only';$r$,
    $r$raise exception 'admins only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_level_site' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_managed_access
  select pg_get_functiondef('public.set_managed_access(uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to manage this profile';$r$,
    $r$raise exception 'not allowed to manage this profile' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_managed_access' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_member_home_site
  select pg_get_functiondef('public.set_member_home_site(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'admins only';$r$,
    $r$raise exception 'admins only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_member_home_site' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_member_kiosk
  select pg_get_functiondef('public.set_member_kiosk(uuid,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_member_kiosk' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_member_level_permission
  select pg_get_functiondef('public.set_member_level_permission(uuid,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_member_level_permission' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_member_reservation_limit
  select pg_get_functiondef('public.set_member_reservation_limit(uuid,integer)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_member_reservation_limit' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_member_simultaneous_limit
  select pg_get_functiondef('public.set_member_simultaneous_limit(uuid,integer)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_member_simultaneous_limit' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_number_sequence
  select pg_get_functiondef('public.set_number_sequence(uuid,text,text,text,text,integer,text,bigint)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only owners may configure number sequences';$r$,
    $r$raise exception 'only owners may configure number sequences' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_number_sequence' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_payment_credentials
  select pg_get_functiondef('public.set_payment_credentials(uuid,text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_payment_credentials' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_repartition_rule
  select pg_get_functiondef('public.set_repartition_rule(uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'admins only';$r$,
    $r$raise exception 'admins only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_repartition_rule' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_role_permission
  select pg_get_functiondef('public.set_role_permission(uuid,text,text,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only role managers may edit permissions';$r$,
    $r$raise exception 'only role managers may edit permissions' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_role_permission' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_role_permissions
  select pg_get_functiondef('public.set_role_permissions(uuid,text,text[])'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only role managers may edit permissions';$r$,
    $r$raise exception 'only role managers may edit permissions' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_role_permissions' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_setting
  select pg_get_functiondef('public.set_setting(uuid,text,jsonb,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'platform owners only';$r$,
    $r$raise exception 'platform owners only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_setting' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_tax_reference
  select pg_get_functiondef('public.set_tax_reference(text,text,text,jsonb,text,boolean,date)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'platform owners only';$r$,
    $r$raise exception 'platform owners only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_tax_reference' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_vat_rates
  select pg_get_functiondef('public.set_vat_rates(uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not the owner of this workspace';$r$,
    $r$raise exception 'not the owner of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_vat_rates' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_workspace_branding
  select pg_get_functiondef('public.set_workspace_branding(uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only workspace settings managers may change the colours';$r$,
    $r$raise exception 'only workspace settings managers may change the colours' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_workspace_branding' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_workspace_code
  select pg_get_functiondef('public.set_workspace_code(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only owners may change the workspace ID';$r$,
    $r$raise exception 'only owners may change the workspace ID' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_workspace_code' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_workspace_environment
  select pg_get_functiondef('public.set_workspace_environment(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only owners may change the environment';$r$,
    $r$raise exception 'only owners may change the environment' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_workspace_environment' using errcode = 'P0001';
  end if;
  execute v_def;

  -- set_workspace_lexicon_term
  select pg_get_functiondef('public.set_workspace_lexicon_term(uuid,text,text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only workspace settings managers may change the wording';$r$,
    $r$raise exception 'only workspace settings managers may change the wording' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in set_workspace_lexicon_term' using errcode = 'P0001';
  end if;
  execute v_def;

  -- sweep_billing_invoices
  select pg_get_functiondef('public.sweep_billing_invoices(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in sweep_billing_invoices' using errcode = 'P0001';
  end if;
  execute v_def;

  -- sweep_payment_reminders
  select pg_get_functiondef('public.sweep_payment_reminders(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an admin of this workspace';$r$,
    $r$raise exception 'not an admin of this workspace' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in sweep_payment_reminders' using errcode = 'P0001';
  end if;
  execute v_def;

  -- update_managed_identity
  select pg_get_functiondef('public.update_managed_identity(uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to manage this profile';$r$,
    $r$raise exception 'not allowed to manage this profile' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in update_managed_identity' using errcode = 'P0001';
  end if;
  execute v_def;

  -- upsert_site
  select pg_get_functiondef('public.upsert_site(uuid,uuid,text,text,text,text,text,text,integer,text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'admins only';$r$,
    $r$raise exception 'admins only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in upsert_site' using errcode = 'P0001';
  end if;
  execute v_def;

  -- withdraw_tax_reference
  select pg_get_functiondef('public.withdraw_tax_reference(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'platform owners only';$r$,
    $r$raise exception 'platform owners only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in withdraw_tax_reference' using errcode = 'P0001';
  end if;
  execute v_def;

  -- workspace_owners
  select pg_get_functiondef('public.workspace_owners(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'platform owners only';$r$,
    $r$raise exception 'platform owners only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in workspace_owners' using errcode = 'P0001';
  end if;
  execute v_def;

  -- workspace_status
  select pg_get_functiondef('public.workspace_status(uuid,text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'admins only';$r$,
    $r$raise exception 'admins only' using errcode = 'DKN01';$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in workspace_status' using errcode = 'P0001';
  end if;
  execute v_def;
end;
$refusals$;

-- What catches a refusal catches DKN01 too.
do $handlers$
declare
  v_def text;
begin
  -- create_sample_data
  select pg_get_functiondef('public.create_sample_data(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$or sqlstate 'DKD01' then$r$,
    $r$or sqlstate 'DKD01'
      -- #3821: a permission refusal carries its code (0745).
      or sqlstate 'DKN01' then$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in create_sample_data' using errcode = 'P0001';
  end if;
  execute v_def;

  -- join_by_invitation
  select pg_get_functiondef('public.join_by_invitation(text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$or sqlstate 'DKD01' then$r$,
    $r$or sqlstate 'DKD01'
      -- #3821: a permission refusal carries its code (0745).
      or sqlstate 'DKN01' then$r$);
  if v_def is null then
    raise exception 'an anchor of #3821 was not found in join_by_invitation' using errcode = 'P0001';
  end if;
  execute v_def;
end;
$handlers$;

-- The assistant's reads and writes, and the outcome they answer, restated
-- whole (an MCP function's gate changes whole, #2392).
-- mcp_execute_v1: restated whole, as 0742 restated it, with DKN01.
CREATE OR REPLACE FUNCTION public.mcp_execute_v1(p_installation_id uuid, p_workspace_id uuid, p_operation text, p_arguments jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.mcp_call_context;
  v_args jsonb := coalesce(p_arguments, '{}'::jsonb);
  v_read boolean;
  v_digest text;
  v_stop jsonb;
  v_retry integer;
  v_out jsonb;
  v_envelope jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = 'P0001'; end if;
  c := public.mcp_authorize(p_installation_id, p_workspace_id, p_operation);
  c.request_id := p_request_id;
  if c.refusal is null and to_regprocedure(
       format('public.%I(public.mcp_call_context, jsonb)', 'mcp_op_' || p_operation)) is null then
    c.refusal := 'unknown_operation';
  end if;
  if c.refusal is not null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
      case when c.refusal = 'unknown_operation' then 'validation_error' else 'denied' end, null, c.refusal));
  end if;
  v_read := c.spec->>'mutation' = 'read';
  if not v_read then
    if p_request_id is null then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
        'validation_error', null, 'invalid_arguments', jsonb_build_object('request_id', 'required')));
    end if;
    v_digest := md5(p_workspace_id::text || '|' || p_operation || '|' || (v_args - 'request_id')::text);
    v_stop := public.mcp_idempotent(c, p_request_id, v_digest);
    if v_stop is not null then return v_stop; end if;
  end if;
  -- #1630 — limited once authorised (a replay is not a new call), before work.
  v_retry := public.mcp_limit_retry_after(p_workspace_id, c.client_id, not v_read);
  if v_retry is not null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
      'rate_limited', null, 'rate_limited') || jsonb_build_object('data', jsonb_build_object('retry_after', v_retry)));
  end if;
  if not v_read and c.spec->>'confirmation' = 'native' then
    v_stop := public.mcp_confirm(c, p_request_id, v_digest, v_args);
    if v_stop is not null then return v_stop; end if;
  end if;
  begin
    execute format('select public.%I($1, $2)', 'mcp_op_' || p_operation) into v_out using c, v_args;
  exception
    when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      v_out := public.mcp_outcome_of(sqlstate, sqlerrm);
    when raise_exception or check_violation or exclusion_violation or unique_violation
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0742).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01'
      -- #3821: a permission refusal carries its code (0745).
      or sqlstate 'DKN01' then
      if v_read then raise; end if;
      v_out := public.mcp_outcome_of(sqlstate, sqlerrm);
  end;
  v_envelope := public.mcp_envelope(p_request_id, p_operation, p_workspace_id, v_out->>'status',
    case when v_out->>'status' = 'validation_error' then null else v_out->'data' end, v_out->>'code', v_out->'fields');
  if not v_read and v_out->>'status' <> 'validation_error' then
    insert into public.mcp_idempotency (installation_id, local_user_id, client_id, request_id,
      workspace_id, operation, args_digest, status, outcome)
    values (public.installation_id(), auth.uid(), c.client_id, p_request_id, p_workspace_id, p_operation, v_digest,
            case when v_out->>'status' in ('completed', 'pending_validation') then 'applied' else 'refused' end,
            v_envelope);
  end if;
  return public.mcp_usage_note(c.spec, v_envelope);
end;
$function$;
revoke execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) to authenticated;

-- mcp_read_v1: restated whole, as 0742 restated it, with DKN01.
CREATE OR REPLACE FUNCTION public.mcp_read_v1(p_workspace_id uuid, p_member members, p_operation text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit integer := least(greatest(coalesce((p_args->>'limit')::integer, 25), 1), 100);
  v_from timestamptz;
  v_to timestamptz;
  v_after_at timestamptz;
  v_after_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_event public.events;
  v_can boolean;
  v_reason text;
  v_level uuid;
  v_office uuid;
  v_kind text;
  v_page jsonb;
  v_more boolean;
  -- #2391 — beyond her own rows only when her consent reaches the
  -- workspace (the facade always says which; a direct definer call is the
  -- service role's).
  v_wide boolean := coalesce(p_args->>'_ceiling', 'workspace') = 'workspace';
begin
  select at, id into v_after_at, v_after_id
    from public.mcp_cursor_position(p_args->>'cursor', p_operation, p_workspace_id);

  if p_operation in ('get_availability', 'list_my_reservations') then
    v_from := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'starts_at' else 'from' end);
    v_to := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'ends_at' else 'to' end);
    if v_to <= v_from or v_to - v_from > make_interval(days => (public.setting_value(null, 'mcp.read_range_days') #>> '{}')::int) then
      return jsonb_build_object('refused', 'validation_error', 'code', 'window');
    end if;
  end if;

  if p_operation = 'list_my_reservations' then
    select coalesce(jsonb_agg(r order by (r->>'starts_at')::timestamptz, r->>'reservation_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('reservation_id', x.id, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id, x.desk_id, x.office_id, x.level_id),
                 'starts_at', x.starts_at, 'ends_at', x.ends_at, 'status', x.status) as r
          from public.reservations x
         where x.workspace_id = p_workspace_id and x.member_id = p_member.id
           and x.starts_at < v_to and x.ends_at > v_from
           and (v_after_at is null or (x.starts_at, x.id) > (v_after_at, v_after_id))
         order by x.starts_at, x.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'starts_at')::timestamptz, (v_last->>'reservation_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_availability' then
    -- #2145 — optionally one level or one office; #2391 — every kind the app
    -- books (seats, and desks, offices and levels booked as a whole),
    -- optionally one kind. A page is the next place ids in order; it is
    -- shown by label, and the cursor follows the ids it paged by. "free" is
    -- the booking engine's own verdict (0345), asked only for this page.
    v_level := public.mcp_uuid_arg(p_args, 'level_id', false);
    v_office := public.mcp_uuid_arg(p_args, 'office_id', false);
    v_kind := nullif(p_args->>'kind', '');
    if v_kind is not null and v_kind not in ('seat', 'desk', 'office', 'level', 'room', 'parking') then
      raise exception using errcode = '22023', message = 'kind';
    end if;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.id), '[]'::jsonb) into v_page
      from (select p.*
              from (select s.resource_kind as kind, s.id, s.id as seat_id, d.id as desk_id, o.id as office_id,
                           o.level_id, s.name
                      from public.seats s
                      join public.desks d on d.id = s.desk_id
                      join public.offices o on o.id = d.office_id
                     where s.workspace_id = p_workspace_id
                       and public.resource_kind_enabled(p_workspace_id, s.resource_kind)
                    union all
                    select 'desk', d.id, null, d.id, o.id, o.level_id, d.name
                      from public.desks d
                      join public.offices o on o.id = d.office_id
                     where d.workspace_id = p_workspace_id and d.bookable_as_whole
                    union all
                    select 'office', o.id, null, null, o.id, o.level_id, o.name
                      from public.offices o
                     where o.workspace_id = p_workspace_id and o.bookable_as_whole
                    union all
                    select 'level', l.id, null, null, null, l.id, l.name
                      from public.levels l
                     where l.workspace_id = p_workspace_id and l.bookable_as_whole) p
             where public.place_visible_to(p_member.id, p.office_id, case when p.kind = 'level' then p.level_id end)
               and (v_kind is null or p.kind = v_kind)
               and (v_level is null or p.level_id = v_level)
               and (v_office is null or p.office_id = v_office)
               and (v_after_id is null or p.id > v_after_id)
             order by p.id
             limit v_limit + 1) q;
    v_more := jsonb_array_length(v_page) > v_limit;
    if v_more then
      v_page := v_page - v_limit;
    end if;
    select coalesce(jsonb_agg(r order by r->>'label', r->>'kind', coalesce(r->>'seat_id', r->>'desk_id',
                                 r->>'office_id', r->>'level_id')), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('kind', x.kind, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end),
                 'name', x.name,
                 'free', public.mcp_place_bookable(p_workspace_id, x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end, v_from, v_to) is null) as r
          from jsonb_to_recordset(v_page) as x(kind text, id uuid, seat_id uuid, desk_id uuid,
                                               office_id uuid, level_id uuid, name text)) q;
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', v_rows,
      'next_cursor', case when v_more then
        public.mcp_cursor(p_operation, p_workspace_id, now(),
          (v_page->(jsonb_array_length(v_page) - 1)->>'id')::uuid) end,
      'not_checked', jsonb_build_array('price', 'approval'));
  end if;

  if p_operation = 'list_my_invoices' then
    select coalesce(jsonb_agg(r order by (r->>'issued_at')::timestamptz desc, r->>'invoice_id' desc), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('invoice_id', i.id, 'number', i.number, 'period', i.period,
                 'kind', i.kind, 'total_cents', i.total_cents, 'currency', i.currency,
                 'issued_at', i.issued_at, 'voided', i.voided_at is not null) as r
          from public.invoices i
         where i.workspace_id = p_workspace_id and i.member_id = p_member.id
           and (v_after_at is null or (i.issued_at, i.id) < (v_after_at, v_after_id))
         order by i.issued_at desc, i.id desc
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'issued_at')::timestamptz, (v_last->>'invoice_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'list_pending_validations' then
    -- Pending events the caller authored or is the subject of; under a
    -- workspace ceiling also the ones she may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and (e.actor_member_id = p_member.id or e.subject_member_id = p_member.id
                or (v_wide and (p_member.is_owner or p_member.is_admin
                                or public.may_validate_event_type(p_workspace_id, e.type))))
           and (v_after_at is null or (e.created_at, e.id) > (v_after_at, v_after_id))
         order by e.created_at, e.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'requested_at')::timestamptz, (v_last->>'event_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null
       or not (v_event.actor_member_id = p_member.id or v_event.subject_member_id = p_member.id
               or (v_wide and (p_member.is_owner or p_member.is_admin
                               or public.may_validate_event_type(p_workspace_id, v_event.type)))) then
      return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
    end if;
    v_can := false;
    if v_event.status = 'pending' then
      begin
        perform public.respond_to_event(v_event.id, true);
        raise exception using errcode = 'P0002', message = 'mcp preview';
      exception
        when no_data_found then
          v_can := sqlerrm = 'mcp preview';
        when raise_exception
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0742).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01'
      -- #3821: a permission refusal carries its code (0745).
      or sqlstate 'DKN01' then
          v_reason := left(sqlerrm, 120);
        when others then
          v_reason := 'unavailable';
      end;
    end if;
    return jsonb_build_object(
      'event_id', v_event.id, 'type', v_event.type, 'status', v_event.status,
      'requested_at', v_event.created_at,
      'decisions', (select count(*) from public.event_decisions d where d.event_id = v_event.id),
      'can_respond', v_can, 'reason', v_reason);
  end if;

  if p_operation = 'list_my_favorites' then
    return public.mcp_favorites_v1(p_workspace_id);
  end if;
  if p_operation = 'get_place' then
    return public.mcp_place_v1(p_workspace_id, p_member, p_args);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$function$;
revoke execute on function public.mcp_read_v1(uuid, public.members, text, jsonb) from public, anon, authenticated;

-- mcp_outcome_of: restated whole, as 0742 restated it, with DKN01.
CREATE OR REPLACE FUNCTION public.mcp_outcome_of(p_sqlstate text, p_message text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_sqlstate = '22023' and p_message ilike '%not in this workspace%'
      then public.mcp_outcome('not_found', null, 'not_found')
    when p_sqlstate in ('22023', '22P02', '22007', '22008')
      then public.mcp_outcome('validation_error', null, 'invalid_arguments')
    else public.mcp_outcome('conflict',
           jsonb_build_object('reason', case when p_sqlstate = 'P0001' or p_sqlstate like 'DKK%'
      or p_sqlstate in ('DKI01', 'DKI03', 'DKI04', 'DKI05', 'DKI06', 'DKI07', 'DKD01', 'DKN01') then left(p_message, 200) end), 'refused')
  end;
$function$;
revoke execute on function public.mcp_outcome_of(text, text) from public, anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(745);
