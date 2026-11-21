-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3932 (0819): the Spanish connector's sandbox test opens the Spanish issuing
-- gate through the real writers, and nothing else moves. Walk: refused; a test
-- whose document the AEAT refused leaves it shut; an accepted one opens it
-- (a sandbox acceptance of that transmission); another issuer identity does
-- not inherit it. Throughout, the live chain (verifactu_records), the issued
-- invoices and the transmissions of invoices are byte for byte what they were,
-- and the next live record continues the live chain: a test record starts its
-- own and never claims a live huella. Rolled back.
begin;
select plan(17);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000003932a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated',
        'es3932gate@example.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal,vat_id)
values ('00000000-0000-4000-8000-0000003932b1','ES gate','ES','EUR','Europe/Madrid',
        '00000000-0000-4000-8000-0000003932a1','dev','{"invoicing":true}','{}','');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity)
values ('00000000-0000-4000-8000-0000003932c1','00000000-0000-4000-8000-0000003932b1',
        '00000000-0000-4000-8000-0000003932a1',true,true,'active','business');

-- three issued invoices, the first two chained as the live chain
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, issued_at, title, lines,
                             total_cents, currency, member_name, workspace_name, issuer_name, signature, parties, vat_totals)
select ('00000000-0000-4000-8000-00000039320' || n)::uuid, '00000000-0000-4000-8000-0000003932b1',
       '00000000-0000-4000-8000-0000003932c1', '00000000-0000-4000-8000-0000003932c1',
       'F-2027-000' || n, ('2027-02-0' || n || ' 09:00+01')::timestamptz, 'Febrero', '[]', 12100, 'EUR', 'Cliente',
       'ES gate', 'Admin', 'sig',
       '{"seller": {"name": "Cowork Sevilla SL", "country": "ES", "vat_id": "ES B12345674"},
         "buyer": {"name": "Cliente SA", "country": "ES", "vat_id": "A58818501"}}'::jsonb,
       '[{"percent": 21, "category": "S", "net_cents": 10000, "vat_cents": 2100, "gross_cents": 12100}]'::jsonb
  from generate_series(1, 3) n;
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-0000003932a1', 'role', 'authenticated')::text, false);
select public.record_verifactu_v1('00000000-0000-4000-8000-000000393201'::uuid);
select public.record_verifactu_v1('00000000-0000-4000-8000-000000393202'::uuid);

create function pg_temp.snapshot() returns text language sql as $f$
  select md5(
    coalesce((select string_agg(row_to_json(r)::text, '|' order by r.chain_position)
                from public.verifactu_records r where r.workspace_id = '00000000-0000-4000-8000-0000003932b1'), '')
    || '#' ||
    coalesce((select string_agg(row_to_json(i)::text, '|' order by i.number)
                from public.invoices i where i.workspace_id = '00000000-0000-4000-8000-0000003932b1'), ''))
$f$;
select set_config('es.before', pg_temp.snapshot(), false);

create function pg_temp.refused() returns boolean language sql as $$
  select 'seller_country_unsupported' = any(public.invoice_essentials_missing(
    '00000000-0000-4000-8000-0000003932b1'::uuid, '00000000-0000-4000-8000-0000003932c1'::uuid,
    jsonb_build_object('seller', jsonb_build_object('street','s','city','c','postal_code','41001',
                                                    'country','ES','vat_regime','vat_registered'),
                       'buyer', jsonb_build_object('name','Buyer','street','s','city','c','country','ES')),
    jsonb_build_array(jsonb_build_object('category','S','percent',21,'gross_cents',12100,
                                         'net_cents',10000,'vat_cents',2100))))
$$;
-- one sandbox test through the real writers: prepare, claim, outcome
create function pg_temp.test(p_hash text) returns uuid language plpgsql as $f$
declare v_id uuid; v_owner constant uuid := '00000000-0000-4000-8000-0000003932a1';
begin
  v_id := (public.prepare_einvoice_test_v1('00000000-0000-4000-8000-0000003932b1', 'es_verifactu', v_owner, 'T',
             'verifactu', p_hash, 't.xml', 'application/xml', '\x01'::bytea) ->> 'id')::uuid;
  perform public.claim_einvoice_dispatch_v1(v_id, v_owner, 150);
  perform public.record_einvoice_outcome_v1(v_id, 1, v_owner, 'accepted', 'CSV-' || p_hash, '',
                                            jsonb_build_object('csv', 'CSV-' || p_hash));
  return v_id;
end $f$;
create function pg_temp.verdict(p_id uuid, p_status text) returns text language sql as $f$
  select public.record_einvoice_lookup_v1(p_id, null, null, null,
           jsonb_build_object('status', p_status, 'detail', p_status), null) ->> 'recorded'
$f$;
create function pg_temp.acceptances() returns int language sql as $f$
  select count(*)::int from public.national_channel_acceptances
   where workspace_id = '00000000-0000-4000-8000-0000003932b1' and channel = 'es_verifactu'
$f$;

select ok(pg_temp.refused(), 'a Spanish seller is refused before any test');
select set_config('es.t1', pg_temp.test('h1')::text, false);
select ok(pg_temp.refused(), 'an accepted upload alone keeps the gate shut: no document verdict yet');
select is(pg_temp.verdict(current_setting('es.t1')::uuid, 'rejected'), 'true', 'the AEAT refuses the record');
select ok(pg_temp.refused(), 'a refused record keeps the gate shut');
select is(pg_temp.acceptances(), 0, 'and records no acceptance');
select set_config('es.t2', pg_temp.test('h2')::text, false);
select is(pg_temp.verdict(current_setting('es.t2')::uuid, 'accepted'), 'true', 'the AEAT accepts the record');
select ok(not pg_temp.refused(), 'an accepted record opens the gate, through the real writers');
select is((select environment || '|' || (receipt ->> 'transmission_id')
             from public.national_channel_acceptances
            where workspace_id = '00000000-0000-4000-8000-0000003932b1' and channel = 'es_verifactu'),
          'sandbox|' || current_setting('es.t2'), 'a uat test is a sandbox acceptance of that transmission');
select is(pg_temp.verdict(current_setting('es.t2')::uuid, 'accepted'), 'true', 'the same verdict read again');
select is(pg_temp.acceptances(), 1, 'a replay changes nothing');
update public.workspaces set vat_id = 'ESB99999999' where id = '00000000-0000-4000-8000-0000003932b1';
select ok(pg_temp.refused(), 'another issuer identity does not inherit the sandbox acceptance');
update public.workspaces set vat_id = '' where id = '00000000-0000-4000-8000-0000003932b1';
select ok(not pg_temp.refused(), 'the tested identity does');

-- the live chain, the invoices and the invoices'' transmissions: unchanged
select is(pg_temp.snapshot(), current_setting('es.before'),
          'the live chain and the issued invoices are byte for byte what they were');
select is((select count(*)::int from public.invoice_transmissions
            where workspace_id = '00000000-0000-4000-8000-0000003932b1' and invoice_id is not null),
          0, 'no transmission of an invoice was made');
select is((select count(*)::int from public.invoice_transmissions
            where workspace_id = '00000000-0000-4000-8000-0000003932b1' and kind = 'test'),
          2, 'the two tests are transmissions of their own kind');
-- the next live record continues the live chain: no test huella is its predecessor
select is((select chain_position || '|' || (previous_huella = (select huella from public.verifactu_records
                                                                where chain_position = 2
                                                                  and workspace_id = '00000000-0000-4000-8000-0000003932b1'))::text
              from public.record_verifactu_v1('00000000-0000-4000-8000-000000393203'::uuid)),
          '3|true', 'the next live record is the third of the live chain, after the second');
select is((select count(*)::int from public.verifactu_records
            where workspace_id = '00000000-0000-4000-8000-0000003932b1'), 3,
          'and a test left no record in the live chain');

select * from finish();
rollback;
