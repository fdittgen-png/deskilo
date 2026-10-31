-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- Security alerts belong to workspace administrators, never a kiosk-only role.
create or replace function public.event_type_view_permissions(p_type text)
returns text[] language sql immutable set search_path = public as $fn$
  select case
    when p_type in ('payment', 'adjustment', 'service_charge', 'invoice_payment',
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
    else array['manageConfiguration']
  end;
$fn$;
revoke execute on function public.event_type_view_permissions(text) from public,anon;
grant execute on function public.event_type_view_permissions(text) to authenticated;

select public.set_deskilo_schema_version(630);
