-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4164 A1 (0821): a customer-only subject is a members row with status
-- 'customer' and no login. Every server function that runs with its definer's
-- rights and reads public.members either cannot reach such a row, or is listed
-- below with why a customer is a legitimate target of it. Read from the
-- database itself: every routine with SECURITY DEFINER, whatever wrote or
-- patched it, keyed by its signature. A reader that no rule below places fails
-- until it is placed or listed with its reason.
--
-- The rules, each checked against the function's source:
--   service      not executable by a signed-in client: no one can ask it.
--   own row      every read of members is by `user_id = auth.uid()`: a customer
--                has no login, so no caller is one.
--   status gate  every read of members names status = / in active, paused or
--                pending (never `<>`: a customer is none of those).
-- The patterns are about the members row itself: qualified by the alias each read
-- gives it (comma joins counted), or unqualified where a read has none. A function
-- that names 'customer' is not placed by that: it is listed too.
-- What no rule places is listed with its reason. The list is closed both ways.
begin;
select plan(7);

create temp table listed (sig text primary key, reason text not null check (length(reason) > 0));
insert into listed (sig, reason) values
  ('who_can_access_me(uuid)',
   'the caller''s own row by id, and the active owners and admins it lists by status: a customer-only subject is neither'),
  ('billing_customers_v1(uuid)',
   'the business''s billing customers, read under manageBillingCustomers or a finance right (billing_customers_readable): a customer-only subject is its purpose'),
  ('workspace_readiness(uuid)',
   'counts under the configuration right; no row, no name'),
  ('save_purchase_draft_v1(uuid,uuid,integer,jsonb)',
   'checks that a purchase''s payer and submitter ids are of this business under the purchases right; the purchase is the business''s own record and grants the subject nothing'),
  ('set_co_owner(uuid,text)',
   'sets the co-owner state of one subject id: frozen for a customer-only row (members_customer_frozen)'),
  ('schedule_member_pause(uuid,date,date,uuid)',
   'a dated pause of one subject id under the right to manage members: a customer-only row never changes status by a command (members_customer_frozen)'),
  ('request_member_status_change(uuid,text)',
   'a member''s own request to pause or leave, by login; a customer-only subject has none, and its status never changes by a command (members_customer_frozen)'),
  ('respond_to_event(uuid,boolean)',
   'the caller''s own rows, by login: a customer-only subject has no login'),
  ('my_inbox()',
   'the caller''s own rows, by login: a customer-only subject has no login'),
  ('negotiated_item_price(uuid,text,uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('member_price_negotiation(uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('member_employment_status(uuid,boolean)',
   'sets employment of one subject id: refused for a customer-only row by the employment table''s trigger'),
  ('member_statement(uuid,text)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('member_account(uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('assign_workspace_role(uuid,uuid,boolean)',
   'assigns a custom role to one subject id: refused for a customer-only row by the role-members table''s trigger'),
  ('billing_party_save_v1(uuid,uuid,jsonb,integer,text)',
   'edits the billing identity of one billing customer under manageBillingCustomers (status customer only; any other id answers as unknown)'),
  ('member_emails(uuid)',
   'lists addresses through a join on auth.users by user_id: a customer-only subject has no login and no address here'),
  ('counter_receipt_draft_v1(uuid,uuid,uuid,integer,jsonb)',
   'checks that the financial subject a counter sale names is a member of this business, under the right to issue and the counter feature: a customer-only subject is a legitimate target (the sale is billed to it), and a sale that names none reads no row'),
  ('room_offer_v1(uuid,uuid)',
   'the caller''s own active member row, by login, then the room''s offer to it'),
  ('activate_co_owner(uuid)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('badge_pin_needs_review(uuid,uuid)',
   'joins the account badge pins through user_id: a customer-only subject has no login'),
  ('bank_statement_lines_v1(uuid)',
   'names a payee through a profile join (user_id): a customer-only subject has no profile and appears unnamed'),
  ('calendar_items(uuid,timestamp with time zone,timestamp with time zone,text[],uuid)',
   'checks that one subject id exists in the business under the caller''s right to read its calendar; a customer-only subject has no calendar item'),
  ('can_manage_managed_profile(uuid)',
   'whether the caller manages the profile of one subject id: the caller''s own row by login, and the target by id'),
  ('clear_sample_data(uuid,uuid)',
   'deletes the sample batch''s own members'),
  ('create_invitation(uuid,boolean,text,text,uuid,boolean)',
   'a membership invitation for one subject id: the invitations table refuses one bound to a customer-only row (it would give it a login before the handover, B2)'),
  ('create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)',
   'the issuer is the business owner or the issuing member, found by role and login; the subject is the billing target'),
  ('customer_statement_period_v1(uuid,uuid,date,date)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('customer_statement_v1(uuid,uuid,date)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('default_tariff_of(uuid)',
   'prices one subject id by its plan share; a customer-only subject has none'),
  ('document_site_for_member(uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('effective_payment_terms(uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('kiosk_devices_v1(uuid)',
   'lists or joins through a login (user_id or a profile): a customer-only subject has none, so it cannot appear'),
  ('list_all_workspaces()',
   'counts members whose status is active, and owners: a customer-only subject is neither'),
  ('managed_identity_of(uuid)',
   'reads the managed identity of one subject id under the right to manage the profile; a customer-only row has none'),
  ('message_history(text,uuid)',
   'lists or joins through a login (user_id or a profile): a customer-only subject has none, so it cannot appear'),
  ('move_payment_credit_v1(uuid,uuid,text,uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('my_conversation_flags()',
   'lists or joins through a login (user_id or a profile): a customer-only subject has none, so it cannot appear'),
  ('my_personal_workspace_refs_v1()',
   'the caller''s own memberships, by login'),
  ('my_workspace_inbox_v1(timestamp with time zone,text)',
   'lists or joins through a login (user_id or a profile): a customer-only subject has none, so it cannot appear'),
  ('posting_parties(uuid,uuid[])',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('preview_invoice(uuid,uuid,text)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('reconcile_workspace(uuid)',
   'integrity check: rows of another workspace; reads and changes nothing for a caller'),
  ('record_rights_request(uuid,uuid,text,text,timestamp with time zone)',
   'a personal-data rights request about one subject id: a customer is a person the business holds data on, so it is a legitimate target'),
  ('request_subscription_change(uuid,integer)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('revoke_handover(uuid)',
   'revokes a managed-profile handover of one subject id; a customer-only row has none'),
  ('save_accounting_map_v1(uuid,text,text,text,text,text)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('schedule_member_share_change(uuid,integer,date,uuid)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('set_managed_access(uuid,jsonb)',
   'the managed-profile handover of one subject id: refused for a customer-only row (its managed columns are frozen by members_customer_frozen)'),
  ('set_member_customer_capacity(uuid,text)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('set_member_einvoice_address(uuid,text,text,text)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('set_member_home_site(uuid,uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('set_member_kiosk(uuid,boolean)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('set_member_level_permission(uuid,boolean)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('set_member_reservation_limit(uuid,integer)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('set_member_simultaneous_limit(uuid,integer)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('set_member_vat_treatment(uuid,text,text)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('set_room_rental_audience_v1(uuid,uuid,jsonb)',
   'checks that an audience entry is of this business; a customer-only subject is refused by the audience table''s trigger'),
  ('set_room_rental_fees_v1(uuid,uuid,jsonb)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('set_tax_exemption_certificate(uuid,uuid,text,text,text,date,date,text)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('space_host_roster(uuid)',
   'lists or joins through a login (user_id or a profile): a customer-only subject has none, so it cannot appear'),
  ('update_managed_identity(uuid,jsonb)',
   'edits a managed identity: refused for a customer-only row (managed columns frozen, and managed_identities carries the refusal trigger); its billing identity is in billing_parties'),
  ('vies_check_subject(uuid,uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('workspace_owners(uuid)',
   'the owners, by role and login');

create function pg_temp.readers() returns table (sig text, tier text) language plpgsql stable as $f$
declare
  r record;
  v_read constant text := '(?:\m(?:from|join)\s+|,\s*)(?:"?public"?\s*\.\s*)?"?members"?\M'
    || '(?:\s+(?:as\s+)?(?!(?:where|on|join|left|right|inner|cross|full|using|for|order|group|limit|union|set|returning|natural|select|and|or|having|offset|window|values)\M)([a-z_][a-z0-9_]*))?';
  v_aliases text[];
  v_reads int;
  v_qual text;
  v_own int;
  v_gated int;
begin
  for r in
    select p.oid::regprocedure::text as signature, p.prosrc,
           has_function_privilege('authenticated', p.oid, 'execute')
             or has_function_privilege('anon', p.oid, 'execute') as client
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef and p.prorettype <> 'trigger'::regtype
       and p.prosrc ~* v_read
     order by 1
  loop
    -- every read of members, with the alias it is given (an empty one when it has none)
    select coalesce(array_agg(coalesce(m[1], '')), '{}'), count(*)
      into v_aliases, v_reads
      from regexp_matches(r.prosrc, v_read, 'gi') m;
    -- a predicate counts only when it is about THE members row: qualified by one of those
    -- aliases, or unqualified where a read has none
    v_qual := '(?:' || coalesce((select string_agg('\m' || a || '\.', '|') from unnest(v_aliases) a where a <> ''), '(?!)')
              || case when '' = any (v_aliases) then '|(?<![\w.])' else '' end || ')';
    select count(*) into v_own from regexp_matches(r.prosrc,
      v_qual || 'user_id\s*=\s*(auth\.uid\(\)|\(\s*select auth\.uid\(\)\s*\))', 'gi');
    select count(*) into v_gated from regexp_matches(r.prosrc,
      v_qual || 'status\s*(=|in)\s*\(?\s*''(active|paused|pending)''', 'gi');
    sig := r.signature;
    tier := case when not r.client then 'service'
                 when v_own >= v_reads then 'own row'
                 when v_gated >= v_reads then 'status gate'
                 else 'unplaced' end;
    return next;
  end loop;
end
$f$;

select is((select coalesce(string_agg(r.sig, ', ' order by r.sig), '') from pg_temp.readers() r
            where r.tier = 'unplaced' and r.sig not in (select sig from listed)), '',
  'every server function that reads members is placed by a rule or listed with its reason');
select is((select coalesce(string_agg(l.sig || ' (' || coalesce(r.tier, 'gone') || ')', ', ' order by l.sig), '')
             from listed l left join pg_temp.readers() r on r.sig = l.sig
            where r.sig is null or r.tier <> 'unplaced'), '',
  'every listed function exists and is still placed by no rule: a placed one leaves the list');
select is((select coalesce(string_agg(l.sig, ', ' order by l.sig), '') from listed l
            where l.reason like 'callable by the service role only%'
              and has_function_privilege('authenticated', l.sig::regprocedure, 'execute')), '',
  'nothing is listed as service-only that a client may call');

create function public.zz_fixture_member_reader(p_ws uuid) returns bigint language sql stable as
  $f$ select count(*) from "members" m where m.workspace_id = p_ws $f$;
alter function public.zz_fixture_member_reader(uuid) security definer;
grant execute on function public.zz_fixture_member_reader(uuid) to authenticated;
create function public.zz_fixture_member_gated(p_ws uuid) returns bigint language sql stable security definer as
  $f$ select count(*) from public.members m where m.workspace_id = p_ws and m.status = 'active' $f$;
grant execute on function public.zz_fixture_member_gated(uuid) to authenticated;
create function public.zz_fixture_member_own(p_ws uuid) returns bigint language sql stable security definer as
  $f$ select count(*) from public.members m where m.workspace_id = p_ws and m.user_id = auth.uid() $f$;
grant execute on function public.zz_fixture_member_own(uuid) to authenticated;
select is((select string_agg(r.sig || ':' || r.tier, ', ' order by r.sig) from pg_temp.readers() r where r.sig like 'zz_fixture_member_%'),
  'zz_fixture_member_gated(uuid):status gate, zz_fixture_member_own(uuid):own row, zz_fixture_member_reader(uuid):unplaced',
  'a reader is found whatever its name''s form and however it became definer; each rule is seen in its source');
select ok((select count(*) from pg_temp.readers() where tier = 'service') > 50, 'the service-only readers are read');
select ok((select count(*) from pg_temp.readers() where tier in ('own row', 'status gate')) > 100, 'the own-row and status-gated readers are read');
select ok((select count(*) from listed) = 63, 'the list holds 63 reasoned exceptions');

select * from finish();
rollback;
