-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3159 (0701): the IT and ES issuing gates lift per workspace once the
-- national channel's acceptance is recorded. Before it an Italian or Spanish
-- seller is refused (`seller_country_unsupported`); after a synthetic
-- accepted receipt of the SdI it is not, a second Italian workspace still is,
-- and Spain still is until Verifactu accepts. No client may write the receipt:
-- the table takes no insert from authenticated and the recorder is the
-- service role's only. Rolled back.
begin;
select plan(13);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000003159'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@ch3159.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
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

select * from finish();
rollback;
