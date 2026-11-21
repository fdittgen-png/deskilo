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
--   customer     the function states the rule itself (it names 'customer').
-- What no rule places is listed with its reason. The list is closed both ways.
begin;
select plan(7);

create temp table listed (sig text primary key, reason text not null check (length(reason) > 0));
insert into listed (sig, reason) values
  ('member_emails(uuid)',
   'lists addresses through a join on auth.users by user_id: a customer-only subject has no login and no address here'),
  ('room_offer_v1(uuid,uuid)',
   'the caller''s own active member row, by login, then the room''s offer to it'),
  ('activate_co_owner(uuid)',
   'a community attribute of one subject id: refused for a customer-only row by members_customer_frozen (role, plan, door, limits) or by the grant-table triggers'),
  ('badge_pin_needs_review(uuid,uuid)',
   'joins the account badge pins through user_id: a customer-only subject has no login'),
  ('bank_statement_lines_v1(uuid)',
   'names a payee through a profile join (user_id): a customer-only subject has no profile and appears unnamed'),
  ('billing_party_save_v1(uuid,uuid,jsonb,integer,text)',
   'edits the billing identity of one subject id under the manageBillingCustomers right: a customer-only subject is its purpose'),
  ('calendar_items(uuid,timestamp with time zone,timestamp with time zone,text[],uuid)',
   'checks that one subject id exists in the business under the caller''s right to read its calendar; a customer-only subject has no calendar item'),
  ('can_manage_managed_profile(uuid)',
   'whether the caller manages the profile of one subject id: the caller''s own row by login, and the target by id'),
  ('clear_sample_data(uuid,uuid)',
   'deletes the sample batch''s own members'),
  ('create_invitation(uuid,boolean,text,text,uuid,boolean)',
   'a membership invitation for one subject id: accepting it sets a login, which the no-login check refuses for a customer-only row; handing a customer over as a member is an explicit later step (B2)'),
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
   'the managed-profile handover of one subject id (a claim sets a login, refused for a customer-only row); a customer-only row has no managed identity of its own'),
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
   'edits the managed identity of one subject id under the right to manage the profile; a customer-only row keeps its billing identity in billing_parties, which this does not read'),
  ('vies_check_subject(uuid,uuid)',
   'by one subject id, under an explicit finance or customer right: a customer-only subject is a legitimate target, the seller bills it'),
  ('workspace_owners(uuid)',
   'the owners, by role and login');

create function pg_temp.readers() returns table (sig text, tier text) language sql stable as $$
  with r as (
    select p.oid::regprocedure::text as sig, p.prosrc,
           has_function_privilege('authenticated', p.oid, 'execute')
             or has_function_privilege('anon', p.oid, 'execute') as client,
           (select count(*) from regexp_matches(p.prosrc, '\m(from|join)\s+("?public"?\s*\.\s*)?"?members"?\M', 'gi')) as reads,
           (select count(*) from regexp_matches(p.prosrc, 'status\s*(=|in)\s*\(?\s*''(active|paused|pending)', 'gi')) as gated,
           (select count(*) from regexp_matches(p.prosrc, 'user_id\s*=\s*(auth\.uid\(\)|\(\s*select auth\.uid\(\)\s*\))', 'gi')) as own
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef and p.prorettype <> 'trigger'::regtype
       and p.prosrc ~* '\m(from|join)\s+("?public"?\s*\.\s*)?"?members"?\M')
  select sig, case when not client then 'service'
                   when prosrc ~* '''customer''' then 'customer'
                   when own >= reads then 'own row'
                   when gated >= reads then 'status gate'
                   else 'unplaced' end
    from r;
$$;

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
select ok((select count(*) from listed) = 48, 'the list holds 48 reasoned exceptions');

select * from finish();
rollback;
