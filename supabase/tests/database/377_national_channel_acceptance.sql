-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3159 (0701, 0702): the IT and ES issuing gates lift per workspace once the
-- national channel's acceptance is recorded. Before it an Italian or Spanish
-- seller is refused (`seller_country_unsupported`); after a synthetic
-- accepted receipt of the SdI it is not, a second Italian workspace still is,
-- and Spain still is until Verifactu accepts. No client may write the receipt:
-- the table takes no insert from authenticated and the recorder is the
-- service role's only. Rolled back.
begin;
select plan(34);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000003159'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@ch3159.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000003159b1','IT accepted','IT','EUR','Europe/Rome','00000000-0000-4000-8000-0000003159a1','dev','{"invoicing":true}','{}'),
 ('00000000-0000-4000-8000-0000003159b2','IT not yet','IT','EUR','Europe/Rome','00000000-0000-4000-8000-0000003159a2','dev','{"invoicing":true}','{}'),
 ('00000000-0000-4000-8000-0000003159b3','ES not yet','ES','EUR','Europe/Madrid','00000000-0000-4000-8000-0000003159a3','dev','{"invoicing":true}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity) values
 ('00000000-0000-4000-8000-0000003159c1','00000000-0000-4000-8000-0000003159b1','00000000-0000-4000-8000-0000003159a1',true,true,'active','business'),
 ('00000000-0000-4000-8000-0000003159c2','00000000-0000-4000-8000-0000003159b2','00000000-0000-4000-8000-0000003159a2',true,true,'active','business'),
 ('00000000-0000-4000-8000-0000003159c3','00000000-0000-4000-8000-0000003159b3','00000000-0000-4000-8000-0000003159a3',true,true,'active','business');

-- Whether the gate refuses the seller of [p_ws] in [p_country].
create or replace function pg_temp.refused(p_ws text, p_member text, p_country text)
returns boolean language sql as $$
  select 'seller_country_unsupported' = any(public.invoice_essentials_missing(
    ('00000000-0000-4000-8000-0000003159'||p_ws)::uuid,
    ('00000000-0000-4000-8000-0000003159'||p_member)::uuid,
    jsonb_build_object('seller', jsonb_build_object('street','s','city','c','postal_code','00100',
                                                    'country',p_country,'vat_regime','vat_registered'),
                       'buyer', jsonb_build_object('name','Buyer','street','s','city','c',
                                                   'country',p_country)),
    jsonb_build_array(jsonb_build_object('category','S','percent',22,'gross_cents',12200,
                                         'net_cents',10000,'vat_cents',2200))))
$$;

-- before
select ok(pg_temp.refused('b1','c1','IT'), 'an Italian seller is refused before any acceptance');
select ok(pg_temp.refused('b3','c3','ES'), 'a Spanish seller is refused before any acceptance');

-- no client writes an acceptance
select ok(not has_table_privilege('authenticated', 'public.national_channel_acceptances', 'insert'),
          'authenticated cannot insert an acceptance');
select ok(not has_table_privilege('authenticated', 'public.national_channel_acceptances', 'update'),
          'authenticated cannot update an acceptance');
select ok(not has_function_privilege('authenticated',
            'public.record_national_channel_acceptance_v1(uuid, text, text, text, jsonb, timestamptz)', 'execute'),
          'authenticated cannot call the recorder');
select ok(not has_function_privilege('anon',
            'public.record_national_channel_acceptance_v1(uuid, text, text, text, jsonb, timestamptz)', 'execute'),
          'anon cannot call the recorder');
select ok(has_function_privilege('service_role',
            'public.record_national_channel_acceptance_v1(uuid, text, text, text, jsonb, timestamptz)', 'execute'),
          'the service role can');

-- refusals of the recorder
select throws_like(
  $$select public.record_national_channel_acceptance_v1('00000000-0000-4000-8000-0000003159b1', 'FR',
      'it_sdi', 'sandbox', '{"id":"x"}', now())$$,
  '%no national channel is required%', 'a country without a national channel takes no acceptance');
select throws_ok(
  $$select public.record_national_channel_acceptance_v1('00000000-0000-4000-8000-0000003159b1', 'IT',
      'it_sdi', 'sandbox', '{}', now())$$,
  '23514', null, 'an empty receipt is refused');

-- after: a synthetic accepted SdI receipt for the first Italian workspace
select is(public.record_national_channel_acceptance_v1('00000000-0000-4000-8000-0000003159b1', 'IT',
            'it_sdi', 'sandbox',
            '{"identificativo_sdi":"123456789","esito":"RC","ricevuta":"consegna"}', now() - interval '1 minute')
            ->> 'gate_open',
          'true', 'the acceptance is recorded and opens the gate');
select ok(not pg_temp.refused('b1','c1','IT'), 'that Italian seller issues once the SdI accepted');
select ok(pg_temp.refused('b2','c2','IT'), 'another Italian workspace stays refused: the gate lifts per workspace');
select ok(pg_temp.refused('b3','c3','ES'), 'Spain stays refused until Verifactu accepts');

-- 0702: the channel's own answer records the acceptance
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at)
select ('00000000-0000-4000-8000-0000003159'||w)::uuid, ('00000000-0000-4000-8000-0000003159'||ws)::uuid,
       ('00000000-0000-4000-8000-0000003159'||m)::uuid, ('00000000-0000-4000-8000-0000003159'||m)::uuid,
       'T-'||w, 'T', '[]'::jsonb, 1000, 'EUR', 'A', 'B', 'O', 'sig', now()
  from (values ('d2','b2','c2'), ('d3','b3','c3')) v(w, ws, m);
-- #3746: the channel's answer reaches the gate through the real writers
-- (prepare, claim, outcome, lookup), and only a positive DOCUMENT verdict
-- counts: an accepted upload whose document the SdI refused does not.
create or replace function pg_temp.sdi(p_inv text, p_hash text, p_ws text default 'b2', p_user text default 'a2')
returns uuid language plpgsql as $f$
declare v_id uuid; v_owner uuid := ('00000000-0000-4000-8000-0000003159' || p_user)::uuid;
begin
  v_id := (public.prepare_einvoice_v1(('00000000-0000-4000-8000-0000003159' || p_ws)::uuid,
             ('00000000-0000-4000-8000-0000003159' || p_inv)::uuid, 'it_sdi', 'government', 'uat',
             v_owner, 'T', 'fatturapa', p_hash, 'f.xml', 'application/xml', '', '', '\x01'::bytea) ->> 'id')::uuid;
  perform public.claim_einvoice_dispatch_v1(v_id, v_owner, 150);
  perform public.record_einvoice_outcome_v1(v_id, 1, v_owner, 'accepted', 'SDI-' || p_inv, '',
                                            jsonb_build_object('identificativo_sdi', 'SDI-' || p_inv));
  return v_id;
end
$f$;
create or replace function pg_temp.verdict(p_id uuid, p_status text) returns text language sql as $f$
  select public.record_einvoice_lookup_v1(p_id, null, null, null,
           jsonb_build_object('status', p_status, 'detail', p_status), null) ->> 'recorded'
$f$;
create or replace function pg_temp.acceptances() returns int language sql as $f$
  select count(*)::int from public.national_channel_acceptances
   where workspace_id = '00000000-0000-4000-8000-0000003159b2'
$f$;
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at)
values ('00000000-0000-4000-8000-0000003159d4', '00000000-0000-4000-8000-0000003159b2',
        '00000000-0000-4000-8000-0000003159c2', '00000000-0000-4000-8000-0000003159c2',
        'T-d4', 'T', '[]'::jsonb, 1000, 'EUR', 'A', 'B', 'O', 'sig', now()),
       ('00000000-0000-4000-8000-0000003159d7', '00000000-0000-4000-8000-0000003159b2',
        '00000000-0000-4000-8000-0000003159c2', '00000000-0000-4000-8000-0000003159c2',
        'T-d7', 'T', '[]'::jsonb, 1000, 'EUR', 'A', 'B', 'O', 'sig', now());
select set_config('ch.t1', pg_temp.sdi('d2', 'h2')::text, false);
select ok(pg_temp.refused('b2','c2','IT'), 'an accepted upload alone keeps the gate shut: no document verdict yet');
select is(pg_temp.verdict(current_setting('ch.t1')::uuid, 'rejected'), 'true', 'the SdI refuses the document');
select ok(pg_temp.refused('b2','c2','IT'), 'an accepted upload with a rejected document keeps the gate shut');
select is(pg_temp.acceptances(), 0, 'and records no acceptance');
select set_config('ch.t2', pg_temp.sdi('d4', 'h4')::text, false);
select is(pg_temp.verdict(current_setting('ch.t2')::uuid, 'accepted'), 'true', 'the SdI accepts the document');
select ok(not pg_temp.refused('b2','c2','IT'), 'an accepted document opens the gate, through the real writer');
select is((select environment || '|' || (receipt ->> 'transmission_id')
             from public.national_channel_acceptances
            where workspace_id = '00000000-0000-4000-8000-0000003159b2'),
          'sandbox|' || current_setting('ch.t2'),
          'a uat transmission is a sandbox acceptance of that transmission, and the row says so');
select set_config('ch.at', (select accepted_at::text from public.national_channel_acceptances
                             where workspace_id = '00000000-0000-4000-8000-0000003159b2'), false);
select is(pg_temp.verdict(current_setting('ch.t2')::uuid, 'accepted'), 'true', 'the same verdict read again');
select is((select count(*)::int || '|' || max(accepted_at)::text from public.national_channel_acceptances
            where workspace_id = '00000000-0000-4000-8000-0000003159b2'),
          '1|' || current_setting('ch.at'), 'a replay changes nothing');
-- the binding: a sandbox acceptance holds for the issuer and configuration it tested
update public.workspaces set vat_id = 'IT99999999999' where id = '00000000-0000-4000-8000-0000003159b2';
select ok(pg_temp.refused('b2','c2','IT'), 'another issuer identity does not inherit the sandbox acceptance');
update public.workspaces set vat_id = '' where id = '00000000-0000-4000-8000-0000003159b2';
select ok(not pg_temp.refused('b2','c2','IT'), 'the tested identity does');
insert into public.einvoice_credentials (workspace_id, provider, config)
values ('00000000-0000-4000-8000-0000003159b2', 'it_sdi', '{"endpoint":"https://other.example"}');
select ok(pg_temp.refused('b2','c2','IT'), 'a replaced channel configuration does not inherit it either');
-- The new configuration earns its own acceptance (the earlier one dated an
-- hour back, as a later test would be), and that acceptance does not
-- depend on the session that reads it.
update public.national_channel_acceptances set accepted_at = accepted_at - interval '1 hour'
 where workspace_id = '00000000-0000-4000-8000-0000003159b2';
select is(pg_temp.verdict(pg_temp.sdi('d7', 'h7'), 'accepted'), 'true', 'the new configuration sends and is accepted');
select ok(not pg_temp.refused('b2','c2','IT'), 'and its acceptance opens the gate');
set local timezone = 'Pacific/Kiritimati';
set local datestyle = 'SQL, DMY';
select ok(not pg_temp.refused('b2','c2','IT'), 'another session time zone and date style leave the gate open');
reset timezone;
reset datestyle;

-- Credentials saved between the send and the verdict: the verdict is not
-- the new configuration's, and records nothing.
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal)
values ('00000000-0000-4000-8000-0000003159b4','IT late verdict','IT','EUR','Europe/Rome',
        '00000000-0000-4000-8000-0000003159a4','dev','{"invoicing":true}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity)
values ('00000000-0000-4000-8000-0000003159c4','00000000-0000-4000-8000-0000003159b4',
        '00000000-0000-4000-8000-0000003159a4',true,true,'active','business');
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at)
values ('00000000-0000-4000-8000-0000003159d6', '00000000-0000-4000-8000-0000003159b4',
        '00000000-0000-4000-8000-0000003159c4', '00000000-0000-4000-8000-0000003159c4',
        'T-d6', 'T', '[]'::jsonb, 1000, 'EUR', 'A', 'B', 'O', 'sig', now());
select set_config('ch.t6', pg_temp.sdi('d6', 'h6', 'b4', 'a4')::text, false);
insert into public.einvoice_credentials (workspace_id, provider, config, updated_at)
values ('00000000-0000-4000-8000-0000003159b4', 'it_sdi', '{"endpoint":"https://new.example"}',
        now() + interval '1 minute');
select is(pg_temp.verdict(current_setting('ch.t6')::uuid, 'accepted'), 'true', 'the SdI accepts the document later');
select is((select count(*)::int from public.national_channel_acceptances
            where workspace_id = '00000000-0000-4000-8000-0000003159b4'), 0,
          'credentials saved after the send: the verdict records nothing');
select ok(pg_temp.refused('b4','c4','IT'), 'and the gate stays shut');

insert into public.verifactu_records (id, workspace_id, invoice_id, kind, chain_position, issuer_nif,
                                      invoice_number, issue_date, generated_at, huella)
values ('00000000-0000-4000-8000-0000003159f3', '00000000-0000-4000-8000-0000003159b3',
        '00000000-0000-4000-8000-0000003159d3', 'alta', 1, 'B12345678', 'T-d3', '10-11-2026',
        '2026-11-10T10:00:00+01:00', repeat('A', 64));
update public.verifactu_records set submission_status = 'rejected'
 where id = '00000000-0000-4000-8000-0000003159f3';
select ok(pg_temp.refused('b3','c3','ES'), 'a rejected Verifactu record keeps the gate shut');
update public.verifactu_records set submission_status = 'accepted'
 where id = '00000000-0000-4000-8000-0000003159f3';
select ok(not pg_temp.refused('b3','c3','ES'), 'an accepted Verifactu record opens the gate');
select is((select channel from public.national_channel_acceptances
            where workspace_id = '00000000-0000-4000-8000-0000003159b3'),
          'es_verifactu', 'it is recorded as Verifactu''s');

select * from finish();
rollback;
