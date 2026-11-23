-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4143 (0803): every server function that runs with its definer's rights and
-- reads public.events applies the events' reading rule (event_readable or
-- event_readable_by, or
-- each type's restrictive rule where it returns only the caller''s own events)
-- or is listed below with what it returns. Read from the database itself:
-- every routine with SECURITY DEFINER, whatever wrote or patched it, keyed by
-- its signature. The list is closed: a new reader fails until it applies the
-- rule or is listed; an entry that no longer exists, no longer reads events,
-- or now applies the rule fails too. test/lint/definer_event_readers_test.dart
-- checks each listed signature against the effective contract.
begin;
select plan(7);

create temp table listed (sig text primary key, reason text not null check (length(reason) > 0));
insert into listed (sig, reason) values
  ('admin_create_reservation_for(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('badge_auth_verify(text,text,text,uuid,text)',
   'callable by the service role only'),
  ('bank_line_status(bank_statement_lines)',
   'callable by the service role only'),
  ('business_receivable_rows(uuid)',
   'callable by the service role only'),
  ('clear_sample_data(uuid,uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on (deletes the sample batch)'),
  ('create_sample_data(uuid,uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on (records the sample batch)'),
  ('decide_workspace_application(uuid,boolean,text,uuid)',
   'hands the decision to respond_to_event, which applies its own checks; returns nothing'),
  ('distribute_expense(uuid,text,integer,text,text,jsonb,uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('einvoice_match_candidates(uuid)',
   'expense rows only, to holders of approveExpenses, the expense''s reading right'),
  ('financial_command_outcome_v1(uuid,uuid)',
   'returns only the caller''s own events, none of a restricted type'),
  ('invoice_payment_received(uuid)',
   'callable by the service role only'),
  ('invoice_still_due_cents(uuid)',
   'callable by the service role only'),
  ('join_workspace(text)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on (the joiner''s own request)'),
  ('kpi_item_margins(uuid,text,text)',
   'sums of service charges under the figures'' own reading right (kpi_readable); no row, type or content'),
  ('kpi_pending_actions_current(uuid,text,text)',
   'one aggregate count under the analytics right (kpi_overview_scope); no row, type or content'),
  ('lease_apply_actor(uuid)',
   'callable by the service role only'),
  ('match_einvoice(uuid,uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('mcp_op_request_reservation_deletion(mcp_call_context,jsonb)',
   'callable by the service role only'),
  ('mcp_op_respond_to_validation(mcp_call_context,jsonb)',
   'callable by the service role only; the status of the event it handed to respond_to_event, which applies its own checks'),
  ('message_ref_workspace(text,uuid)',
   'callable by the service role only'),
  ('my_finance_overview()',
   'amounts of the caller''s own invoices; no event'),
  ('open_claim_invoices(uuid)',
   'callable by the service role only'),
  ('payment_attempt_notice(uuid,uuid,text)',
   'callable by the service role only (writes the notice)'),
  ('payment_invoice_capacity_v1(uuid,uuid)',
   'amounts of invoices under its own right; no event'),
  ('record_payment(uuid,uuid,integer,text,text,date,text,uuid[],uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on (a repeat under the same request id returns the id of the caller''s own first declaration)'),
  ('record_standalone_payment_v1(uuid,uuid,integer,text,text,date,uuid[],uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on (a repeat under the same request id returns the id of the caller''s own first declaration)'),
  ('record_badge_auth_failure(text,uuid,uuid,uuid)',
   'callable by the service role only'),
  ('release_invoice_payment(uuid)',
   'callable by the service role only'),
  ('request_house_membership(uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on (the requester''s own request)'),
  ('request_invoice_writeoff(uuid,text)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('request_usage_correction(uuid,text)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('reset_workspace(uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on (deletes the business''s records)'),
  ('sell_guest_pass(uuid,uuid,jsonb,uuid,timestamp with time zone,timestamp with time zone,uuid,boolean,text,integer)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('send_workspace_application_message(uuid,text,uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on, after can_discuss_workspace_application, which applies the rule'),
  ('stock_low_rows(uuid,uuid)',
   'callable by the service role only; the reorder points at or below their level, from the ledger: no event'),
  ('stock_reorder_check(uuid)',
   'writes or checks: returns nothing (opens or ends the point''s own stock_low notice)'),
  ('stock_move_v1(uuid,uuid,jsonb,text,timestamp with time zone,jsonb)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('sweep_pending_events(uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('unmatch_bank_line_in_v1(uuid,text,uuid)',
   'writes or checks: returns an id, nothing, or a refusal about the object the caller acts on'),
  ('vat_input_amounts(uuid,date,date)',
   'callable by the service role only'),
  ('withdraw_payment_declaration(uuid)',
   'returns only the caller''s own events, none of a restricted type');

create function pg_temp.readers() returns table (sig text, applies boolean) language sql stable as $$
  select p.oid::regprocedure::text,
         p.prosrc ~* '\m(event_readable|event_readable_by|event_type_restriction_holds)\s*\('
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and p.prorettype <> 'trigger'::regtype
     and (p.prosrc ~* '(\m(from|join)|,)\s+(only\s+)?("?public"?\s*\.\s*)?"?events"?\M'
          or p.prosrc ~* '\mupdate\s+(only\s+)?("?public"?\s*\.\s*)?"?events"?\M[^;]*\mreturning\M');
$$;

select is((select coalesce(string_agg(r.sig, ', ' order by r.sig), '') from pg_temp.readers() r
            where not r.applies and r.sig not in (select sig from listed)), '',
  'every server function that reads events applies the reading rule or is listed with what it returns');
select is((select coalesce(string_agg(l.sig, ', ' order by l.sig), '') from listed l
            where l.sig not in (select r.sig from pg_temp.readers() r)), '',
  'every listed function exists and reads events');
select is((select coalesce(string_agg(l.sig, ', ' order by l.sig), '') from listed l
            join pg_temp.readers() r on r.sig = l.sig where r.applies), '',
  'no listed function applies the rule: it leaves the list');
select is((select string_agg(r.sig, ', ' order by r.sig) from pg_temp.readers() r where r.applies),
  'calendar_items(uuid,timestamp with time zone,timestamp with time zone,text[],uuid), '
  || 'can_discuss_workspace_application(uuid), export_my_data(uuid), mcp_read_v1(uuid,members,text,jsonb), '
  || 'mcp_target(uuid,text,jsonb), my_workspace_applications(timestamp with time zone,uuid), respond_to_event(uuid,boolean)',
  'the readers that apply the rule');

-- a reader under a quoted, schema-less name, made definer afterwards, is
-- found; one that applies the rule passes
create function public.zz_fixture_reader(p_ws uuid) returns bigint language sql stable as
  $f$ select count(*) from "events" e where e.workspace_id = p_ws $f$;
alter function public.zz_fixture_reader(uuid) security definer;
create function public.zz_fixture_only(p_ws uuid) returns bigint language sql stable security definer as
  $f$ select count(*) from only public.events e where e.workspace_id = p_ws $f$;
create function public.zz_fixture_comma(p_ws uuid) returns bigint language sql stable security definer as
  $f$ select count(*) from public.members m, public.events e where e.actor_member_id = m.id and m.workspace_id = p_ws $f$;
create function public.zz_fixture_returning(p_id uuid) returns text language sql volatile security definer as
  $f$ update public.events set payload = payload where id = p_id returning type $f$;
create function public.zz_fixture_ruled(p_ws uuid) returns bigint language sql stable security definer as
  $f$ select count(*) from public.events e where e.workspace_id = p_ws
        and public.event_readable(e.workspace_id, e.type, e.actor_member_id, e.subject_member_id) $f$;
select is((select string_agg(r.sig || ':' || r.applies, ', ' order by r.sig) from pg_temp.readers() r
            where r.sig like 'zz_fixture_%'),
  'zz_fixture_comma(uuid):false, zz_fixture_only(uuid):false, zz_fixture_reader(uuid):false, '
  || 'zz_fixture_returning(uuid):false, zz_fixture_ruled(uuid):true',
  'a reader is found whatever its name''s form, through only, a comma join or an update that returns, '
  || 'and however it became definer; the rule is seen in its source');
select is((select coalesce(string_agg(l.sig, ', ' order by l.sig), '') from listed l
            where l.reason like 'callable by the service role only%'
              and has_function_privilege('authenticated', l.sig::regprocedure, 'execute')), '',
  'every entry listed as callable by the service role only is not executable by a signed-in client');
select ok((select count(*) from listed) = 40, 'the list holds 40 reasoned exceptions');

select * from finish();
rollback;
