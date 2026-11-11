-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (an event type with a unique key per invoice, a notices table, an AFTER
--  INSERT trigger on invoices that records the notice and queues the push)
--
-- #3672 -- a new invoice tells its customer: an entry in their account's
-- feed and a push in their language, through the path reminders use.
--
--  * Issuing records, in the SAME transaction, one `invoice_issued` event
--    per invoice (a unique key on the invoice id): actor the issuing member,
--    subject the invoice's customer, applied. Every path that creates an
--    invoice row is covered (create_invoice and its wrappers, the regroup,
--    the guest pass, the month's sweep), because the trigger sits on the row.
--    A dry run (invoice_issue_readiness) rolls it back with everything else.
--  * The push is queued from that event to send-push (pg_net sends after the
--    commit), and what happened is recorded in `invoice_issue_notices`:
--    queued, or failed with why (no push configured, the request could not
--    be queued). A failed or uncertain push never fails or repeats the
--    issue. A screen claims only what is recorded here.
--  * The recipient is the invoice's customer and that person's devices,
--    also when the owner issues an invoice to themselves (send-push).

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  r record;
begin
  for r in select * from (values
    ('events','events_type_check','type'),
    ('validation_policies','validation_policies_event_type_check','event_type')
  ) as c(table_name,constraint_name,column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid=('public.'||r.table_name)::regclass and conname=r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception 'event type constraint anchor missing: %',r.constraint_name;
    end if;
    if position('invoice_issued' in v_def)=0 then
      execute format('alter table public.%I drop constraint %I',r.table_name,r.constraint_name);
      execute format('alter table public.%I add constraint %I ',r.table_name,r.constraint_name)
        || replace(v_def,'CHECK (',format('CHECK (%I = %L OR ',r.column_name,'invoice_issued'));
    end if;
  end loop;

  -- who reads it besides its customer: whoever reads the invoices
  select pg_get_functiondef('public.event_type_view_permissions(text)'::regprocedure) into v_def;
  if position('invoice_issued' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $a$when p_type = 'privacy_incident'
      then array['managePrivacy']$a$,
      $a$when p_type = 'privacy_incident'
      then array['managePrivacy']
    when p_type = 'invoice_issued'
      then array['viewFinances', 'issueInvoices']$a$);
    if v_def is null then raise exception '0723: event_type_view_permissions anchor missing'; end if;
    execute v_def;
  end if;
end
$migration$;

create unique index if not exists events_invoice_issued_once
  on public.events ((payload ->> 'invoice_id'))
  where type = 'invoice_issued';

create table public.invoice_issue_notices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid not null unique references public.invoices(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  push_outcome text not null check (push_outcome in ('queued', 'failed')),
  net_request_id bigint,
  detail text not null default '' check (length(detail) <= 300),
  queued_at timestamptz not null default now()
);
select public.ensure_system_columns('invoice_issue_notices');

comment on table public.invoice_issue_notices is
  '#3672 -- what was recorded of telling a customer about a new invoice: the feed event, and whether its push was queued.';

alter table public.invoice_issue_notices enable row level security;
revoke all on public.invoice_issue_notices from public, anon;
revoke insert, update, delete on public.invoice_issue_notices from authenticated;
grant select on public.invoice_issue_notices to authenticated;
create policy invoice_issue_notices_select on public.invoice_issue_notices
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'issueInvoices'])));
create policy mcp_delegated_deny on public.invoice_issue_notices as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.invoice_issued_notice()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_event uuid;
  v_cfg public.push_config;
  v_request bigint;
begin
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (new.workspace_id, 'invoice_issued', 'created', new.issuer_member_id, new.member_id,
          jsonb_build_object('invoice_id', new.id, 'number', new.number,
                             'amount_cents', new.total_cents, 'currency', new.currency),
          'applied')
  on conflict ((payload ->> 'invoice_id')) where type = 'invoice_issued' do nothing
  returning id into v_event;
  if v_event is null then return new; end if;

  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is null then
    insert into public.invoice_issue_notices (workspace_id, invoice_id, event_id, push_outcome, detail)
    values (new.workspace_id, new.id, v_event, 'failed', 'push delivery is not configured on this installation');
    return new;
  end if;
  begin
    v_request := net.http_post(
      url := v_cfg.functions_url || '/send-push',
      headers := public.push_delivery_headers(v_cfg.anon_key),
      body := jsonb_build_object('event_id', v_event),
      timeout_milliseconds := 5000);
    insert into public.invoice_issue_notices (workspace_id, invoice_id, event_id, push_outcome, net_request_id)
    values (new.workspace_id, new.id, v_event, 'queued', v_request);
  exception when others then
    insert into public.invoice_issue_notices (workspace_id, invoice_id, event_id, push_outcome, detail)
    values (new.workspace_id, new.id, v_event, 'failed', 'the push request could not be queued');
  end;
  return new;
end;
$fn$;
revoke execute on function public.invoice_issued_notice() from public, anon, authenticated;

drop trigger if exists invoice_issued_notice on public.invoices;
create trigger invoice_issued_notice
  after insert on public.invoices
  for each row execute function public.invoice_issued_notice();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(723);
