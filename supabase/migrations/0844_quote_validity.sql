-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #4291 (Refs #4166) -- a quote's default and longest validity are business
-- settings, not literals. `save_customer_quote_draft_v1` (0828) defaulted the end
-- of validity to the offer date plus 30 days and refused one beyond 365; those
-- two numbers are now the registry settings `quotes.default_validity_days` and
-- `quotes.max_validity_days`, with their current values as defaults, read through
-- `public.setting_value(workspace, key)` like every other business value. A
-- business that never sets them behaves exactly as before.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('quotes.default_validity_days', 'int', '30'::jsonb, 1, 365, 'days', 'billing', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'customer quotes (#4166, #4291)', 'How many days a new quote stays valid when its author states no end date: the offer date plus this many days, never more than the longest validity.'),
('quotes.max_validity_days', 'int', '365'::jsonb, 1, 1825, 'days', 'billing', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'customer quotes (#4166, #4291)', 'The longest a quote may stay valid, counted from its offer date. A longer validity is refused when the quote is saved, by the app and by save_customer_quote_draft_v1.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function public.save_customer_quote_draft_v1(
  p_workspace_id uuid, p_quote_id uuid, p_expected_version integer, p_subject uuid,
  p_issued_on date, p_valid_until date, p_buyer_reference text, p_purchase_order text,
  p_notes text, p_lines jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_lines jsonb;
  v_on date;
  v_until date;
  v_default integer;
  v_max integer;
begin
  v_actor := public.customer_quote_actor(p_workspace_id);
  perform public.standalone_invoice_subject(p_workspace_id, p_subject);
  v_lines := public.customer_quote_lines_clean(p_lines);
  v_on := coalesce(p_issued_on, public.workspace_today(p_workspace_id));
  -- the business's own validity: the registry's default is the fallback
  v_max := (public.setting_value(p_workspace_id, 'quotes.max_validity_days') #>> '{}')::int;
  v_default := least((public.setting_value(p_workspace_id, 'quotes.default_validity_days') #>> '{}')::int, v_max);
  v_until := coalesce(p_valid_until, v_on + v_default);
  if v_until < v_on or v_until > v_on + v_max then
    raise exception 'the validity is out of range' using errcode = 'DKQ06', detail = 'valid_until';
  end if;
  if p_quote_id is null then
    insert into public.customer_quotes (workspace_id, subject_member_id)
    values (p_workspace_id, p_subject) returning * into v_q;
    insert into public.customer_quote_revisions
      (quote_id, workspace_id, revision, issued_on, valid_until, buyer_reference, purchase_order, notes, lines)
    values (v_q.id, p_workspace_id, 1, v_on, v_until, coalesce(btrim(p_buyer_reference), ''),
            coalesce(btrim(p_purchase_order), ''), coalesce(btrim(p_notes), ''), v_lines)
    returning * into v_rev;
    -- the series exists before the first number, so the owner may set it first
    insert into public.number_sequences (workspace_id, journal, prefix, date_part, reset)
    select p_workspace_id, 'quote', d.prefix, d.date_part, d.reset
      from public.number_sequence_defaults('quote') d
    on conflict (workspace_id, journal) do nothing;
  else
    select * into v_q from public.customer_quotes
     where id = p_quote_id and workspace_id = p_workspace_id for update;
    if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
    if v_q.subject_member_id is distinct from p_subject then
      raise exception 'a quote keeps its customer' using errcode = 'DKQ03';
    end if;
    select * into v_rev from public.customer_quote_revisions r
     where r.quote_id = v_q.id and r.status = 'draft' order by r.revision desc limit 1 for update;
    if v_rev.id is null then
      raise exception 'no draft revision: amend the quote first' using errcode = 'DKQ03';
    end if;
    if v_rev.draft_version is distinct from p_expected_version then
      raise exception 'the draft changed since it was read' using errcode = 'DKQ02';
    end if;
    update public.customer_quote_revisions set
      issued_on = v_on, valid_until = v_until,
      buyer_reference = coalesce(btrim(p_buyer_reference), ''),
      purchase_order = coalesce(btrim(p_purchase_order), ''),
      notes = coalesce(btrim(p_notes), ''), lines = v_lines,
      draft_version = draft_version + 1
     where id = v_rev.id returning * into v_rev;
  end if;
  return jsonb_build_object('quote_id', v_q.id, 'revision', v_rev.revision, 'version', v_rev.draft_version);
end
$fn$;
revoke execute on function public.save_customer_quote_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, text, jsonb)
  from public, anon;
grant execute on function public.save_customer_quote_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, text, jsonb)
  to authenticated;

select public.set_deskilo_schema_version(844);
