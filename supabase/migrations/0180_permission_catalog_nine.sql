-- SPDX-License-Identifier: 0BSD
-- 0180 — #982: nine permissions. The matrix now guards what "is admin"
-- and "is owner" guarded: sites, tariffs and billing rules,
-- reservations of others, the kiosk and badges, exports, document
-- designs, members' personal data, integrations, the configuration.
--
-- Defaults keep today's behaviour: an admin row that was never edited
-- grants manageSites, manageReservations, operateKiosk, exportData and
-- viewPersonalData (what admins could do), and not manageBilling,
-- designDocuments, manageIntegrations or manageConfiguration (what only
-- owners could do). An edited row replaces the defaults whole, as
-- before. Owners hold everything; co-owners default to everything.
--
-- The document designs move from an owner-only row update to
-- set_invoice_pdf_template, so the matrix can delegate them. Every
-- guard is patched at an asserted anchor; the harness drove an admin
-- through a refusal, a grant through the matrix, and the owner through
-- everything.
create or replace function public.has_permission(ws uuid, perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m join public.workspaces w on w.id = ws
    where m.workspace_id = ws and m.user_id = auth.uid() and m.status = 'active'
      and ( m.is_owner
        or (m.co_owner = 'active' and (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end))
        or (m.is_admin and (
             (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
                   else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses',
                                 'viewFinances','viewNegotiations','manageNegotiations','paymentTermsEdit',
                                 'manageSites','manageReservations','operateKiosk','exportData','viewPersonalData') end)
             or (perm = 'issueInvoices' and coalesce(w.feature_flags -> 'adminInvoicing' = to_jsonb(true), false))))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active' and w.role_permissions ? 'member' and w.role_permissions->'member' ? perm)));
$$;
create or replace function public.member_has_permission(p_member_id uuid, perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members m join public.workspaces w on w.id = m.workspace_id
    where m.id = p_member_id and m.status = 'active'
      and ( m.is_owner
        or (m.co_owner = 'active' and (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end))
        or (m.is_admin and (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
              else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses','viewFinances','viewNegotiations','manageNegotiations',
                            'manageSites','manageReservations','operateKiosk','exportData','viewPersonalData') end))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active' and w.role_permissions ? 'member' and w.role_permissions->'member' ? perm)));
$$;
create or replace function public.set_role_permissions(p_workspace_id uuid, p_role text, p_permissions text[])
returns void language plpgsql security definer set search_path = public as $$
declare
  v_catalog text[] := array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration'];
  v_perm text;
begin
  if not public.has_permission(p_workspace_id, 'manageRoles') then
    raise exception 'only role managers may edit permissions';
  end if;
  if p_role not in ('co_owner','admin','member') then raise exception 'unknown role'; end if;
  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not (v_perm = any(v_catalog)) then raise exception 'unknown permission %', v_perm; end if;
  end loop;
  update public.workspaces set role_permissions = jsonb_set(coalesce(role_permissions, '{}'::jsonb), array[p_role], coalesce(to_jsonb(p_permissions), '[]'::jsonb))
   where id = p_workspace_id;
end $$;
create or replace function public.set_invoice_pdf_template(p_workspace_id uuid, p_template jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission(p_workspace_id, 'designDocuments') then
    raise exception 'not allowed to design the documents';
  end if;
  if p_template is null or jsonb_typeof(p_template) <> 'object' then raise exception 'template must be an object'; end if;
  update public.workspaces set invoice_pdf_template = p_template where id = p_workspace_id;
end $$;
revoke execute on function public.set_invoice_pdf_template(uuid, jsonb) from public, anon;
grant execute on function public.set_invoice_pdf_template(uuid, jsonb) to authenticated;
do $patch$
declare r record; v_def text; v_n int := 0;
  v_rules constant text[][] := array[
    ['upsert_site', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageSites'')'],
    ['delete_site', 'public.is_admin_of(v_site.workspace_id)', 'public.has_permission(v_site.workspace_id, ''manageSites'')'],
    ['set_level_site', 'public.is_admin_of(v_ws)', 'public.has_permission(v_ws, ''manageSites'')'],
    ['set_member_home_site', 'public.is_admin_of(v_ws)', 'public.has_permission(v_ws, ''manageSites'')'],
    ['replace_fee_bands', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageBilling'')'],
    ['set_vat_rates', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageBilling'')'],
    ['set_number_sequence', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageBilling'')'],
    ['set_repartition_rule', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageBilling'')'],
    ['set_billing_rules', 'public.has_permission(p_workspace_id, ''workspaceSettings'')', '(public.has_permission(p_workspace_id, ''workspaceSettings'') or public.has_permission(p_workspace_id, ''manageBilling''))'],
    ['set_dunning_rules', 'public.has_permission(p_workspace_id, ''workspaceSettings'')', '(public.has_permission(p_workspace_id, ''workspaceSettings'') or public.has_permission(p_workspace_id, ''manageBilling''))'],
    ['cancel_reservation', 'public.is_admin_of(v_res.workspace_id)', 'public.has_permission(v_res.workspace_id, ''manageReservations'')'],
    ['check_in_reservation', 'public.is_admin_of(v_res.workspace_id)', 'public.has_permission(v_res.workspace_id, ''manageReservations'')'],
    ['check_out_reservation', 'public.is_admin_of(v_res.workspace_id)', 'public.has_permission(v_res.workspace_id, ''manageReservations'')'],
    ['set_seat_block', 'public.is_admin_of(v_workspace_id)', 'public.has_permission(v_workspace_id, ''manageReservations'')'],
    ['calendar_items', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageReservations'')'],
    ['set_member_kiosk', 'public.is_owner_of(v_member.workspace_id)', 'public.has_permission(v_member.workspace_id, ''operateKiosk'')'],
    ['issue_member_badge', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''operateKiosk'')'],
    ['register_nfc_badge', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''operateKiosk'')'],
    ['revoke_member_badge', 'public.is_admin_of(v_ws)', 'public.has_permission(v_ws, ''operateKiosk'')'],
    ['delete_revoked_badge', 'public.is_admin_of(b.workspace_id)', 'public.has_permission(b.workspace_id, ''operateKiosk'')'],
    ['export_workspace_configuration', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''exportData'')'],
    ['workspace_status', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''viewFinances'')'],
    ['member_emails', 'public.has_permission(p_workspace_id, ''manageMembers'')', 'public.has_permission(p_workspace_id, ''viewPersonalData'')'],
    ['set_payment_credentials', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageIntegrations'')'],
    ['clear_payment_provider', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageIntegrations'')'],
    ['payment_credentials_status', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageIntegrations'')'],
    ['set_einvoice_credentials', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageIntegrations'')'],
    ['clear_einvoice_credentials', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageIntegrations'')'],
    ['einvoice_status', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageIntegrations'')'],
    ['set_feature_flags', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageConfiguration'')'],
    ['set_workspace_environment', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageConfiguration'')'],
    ['set_workspace_code', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageConfiguration'')'],
    ['import_workspace_configuration', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageConfiguration'')'],
    ['import_floor_plan_v3', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageConfiguration'')'],
    ['reset_workspace', 'public.is_owner_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageConfiguration'')'],
    ['set_dev_mode', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageConfiguration'')'],
    ['create_managed_member', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''manageMembers'')'],
    ['sweep_billing_invoices', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''issueInvoices'')'],
    ['sweep_payment_reminders', 'public.is_admin_of(p_workspace_id)', 'public.has_permission(p_workspace_id, ''issueInvoices'')']
  ];
begin
  for i in 1..array_length(v_rules, 1) loop
    for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = v_rules[i][1] and p.prokind = 'f' loop
      v_def := pg_get_functiondef(r.oid);
      if position(v_rules[i][2] in v_def) = 0 then raise exception '0180: anchor missing in %: %', v_rules[i][1], v_rules[i][2]; end if;
      v_def := replace(v_def, v_rules[i][2], v_rules[i][3]);
      execute v_def;
      v_n := v_n + 1;
    end loop;
  end loop;
  raise notice '0180: % function bodies patched', v_n;
end $patch$;
