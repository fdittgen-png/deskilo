-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one new read; no table, policy or other function changes)
--
-- #3673 (third part) -- the reminder queue e-mails many reminders in one
-- sitting. It asks once, for the listed invoices of one workspace, what
-- the single read (`reminder_email_target_v1`, 0726) answers for one:
-- whether the customer can be e-mailed, to which address, or why not (the
-- same three reasons: feature_off, no_address, sender_not_configured). With
-- it comes each invoice's latest reminder e-mail as the server recorded it
-- (`reminder_email_sends`): the queue and its result page show what was
-- sent from these rows, not from what the app remembers, so a queue opened
-- again after the app closed mid-way shows the same truth.
--
-- Who may ask: a native session (never an assistant) of someone who issues
-- invoices in that workspace; nothing is returned before that is checked.
-- An invoice of another workspace is simply not in the answer.

create or replace function public.reminder_email_targets_v1(p_workspace_id uuid, p_invoice_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_on boolean;
  v_sender boolean;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  v_on := public.feature_effective(p_workspace_id, 'reminderEmail');
  v_sender := exists (select 1 from public.purchase_order_mail_settings m
                       where m.workspace_id = p_workspace_id and m.has_api_key);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'invoice_id', i.id,
             'available', v_on and v_sender and x.email is not null,
             'recipient', coalesce(x.email, ''),
             'reason', case
               when not v_on then 'feature_off'
               when x.email is null then 'no_address'
               when not v_sender then 'sender_not_configured'
               else '' end,
             'last_send', (select public.reminder_email_send_json(s.id)
                             from public.reminder_email_sends s
                            where s.invoice_id = i.id
                            order by s.created_datetime desc, s.id
                            limit 1))
           order by i.id)
      from public.invoices i
      cross join lateral (select public.invoice_customer_email(i.id) as email) x
     where i.workspace_id = p_workspace_id
       and i.id = any(coalesce(p_invoice_ids, '{}'::uuid[]))), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.reminder_email_targets_v1(uuid, uuid[]) from public, anon;
grant execute on function public.reminder_email_targets_v1(uuid, uuid[]) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(728);
