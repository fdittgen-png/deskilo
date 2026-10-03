-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1916: an invoice freezes, at issue, the legal clauses and facts it is
-- rendered from: the customer's stated capacity (the member's own over
-- the workspace default, 'unknown' when neither is stated — never derived
-- from a VAT number), the effective payment clauses (the member's own keys
-- over the workspace's), the seller's country as the parties froze it, and
-- a fingerprint of all of it. Changing the settings afterwards never
-- rewrites the snapshot, and the snapshot itself cannot be edited. Only
-- whoever issues invoices in that space states a member's capacity.
begin;
select plan(17);

-- a1 owner of b1 · a2 member (consumer) · a3 plain member · a4 owner of
-- the foreign b2 · a5 member of b3 (nothing stated anywhere).
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001916'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@clauses.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000001916b1','Clauses','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001916a1','dev',
  '{"invoicing":true}',
  '{"seller_kind":"association","customer_capacity":"business","payment_terms":"Paiement à 30 jours.","legal_form":"Association loi 1901"}'),
 ('00000000-0000-4000-8000-0000001916b2','Foreign','DE','EUR','Europe/Berlin','00000000-0000-4000-8000-0000001916a4','dev','{}','{}'),
 ('00000000-0000-4000-8000-0000001916b3','Unstated','DE','EUR','Europe/Berlin','00000000-0000-4000-8000-0000001916a4','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity,payment_terms) values
 ('00000000-0000-4000-8000-0000001916c1','00000000-0000-4000-8000-0000001916b1','00000000-0000-4000-8000-0000001916a1',true,true,'active',null,null),
 ('00000000-0000-4000-8000-0000001916c2','00000000-0000-4000-8000-0000001916b1','00000000-0000-4000-8000-0000001916a2',false,false,'active',
  'consumer','{"late_penalty":"Intérêts au taux légal."}'),
 ('00000000-0000-4000-8000-0000001916c3','00000000-0000-4000-8000-0000001916b1','00000000-0000-4000-8000-0000001916a3',false,false,'active',null,null),
 ('00000000-0000-4000-8000-0000001916c4','00000000-0000-4000-8000-0000001916b2','00000000-0000-4000-8000-0000001916a4',true,true,'active',null,null),
 ('00000000-0000-4000-8000-0000001916c5','00000000-0000-4000-8000-0000001916b3','00000000-0000-4000-8000-0000001916a5',false,false,'active',null,null);

create or replace function pg_temp.inv(p_id text, p_ws text, p_member text) returns void language sql as $$
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, parties)
  values (('00000000-0000-4000-8000-0000001916' || p_id)::uuid, ('00000000-0000-4000-8000-0000001916' || p_ws)::uuid,
          ('00000000-0000-4000-8000-0000001916' || p_member)::uuid,
          ('00000000-0000-4000-8000-0000001916' || case p_ws when 'b3' then 'c5' else 'c1' end)::uuid,
          'L-' || p_id, 'T', '[]'::jsonb, 12000, 'EUR', 'A', 'Clauses', 'Owner', 'sig',
          '{"seller":{"country":"fr"},"buyer":{"country":"DE","vat_id":"DE123456789"}}');
$$;
create or replace function pg_temp.snap(p_id text) returns jsonb language sql as $$
  select legal_snapshot from public.invoices where id = ('00000000-0000-4000-8000-0000001916' || p_id)::uuid;
$$;

select pg_temp.inv('d1', 'b1', 'c2');
select pg_temp.inv('d2', 'b1', 'c3');
select pg_temp.inv('d3', 'b3', 'c5');

-- ── the snapshot ─────────────────────────────────────────────────────
select is(pg_temp.snap('d1')->>'buyer_capacity', 'consumer', 'the member''s own capacity wins');
select is(pg_temp.snap('d1')->>'capacity_source', 'member', 'and says it is the member''s');
select is(pg_temp.snap('d2')->>'buyer_capacity', 'business', 'unstated, the workspace default applies');
select is(pg_temp.snap('d2')->>'capacity_source', 'workspace', 'and says so');
select is(pg_temp.snap('d3')->>'buyer_capacity', 'unknown',
  'nothing stated is unknown — a buyer VAT number does not make a business');
select is(pg_temp.snap('d1')->'clauses',
  '{"payment_terms":"Paiement à 30 jours.","late_penalty":"Intérêts au taux légal."}'::jsonb,
  'the member''s own keys over the workspace''s');
select is(pg_temp.snap('d1')->>'terms_source', 'member', 'whose conditions were in force');
select is(pg_temp.snap('d1')->>'seller_country', 'FR', 'the seller country as the parties froze it');
select is(pg_temp.snap('d1')->>'seller_kind', 'association', 'the seller kind is a fact beside the capacity');
select is(pg_temp.snap('d1')->>'fingerprint',
  encode(extensions.digest(convert_to((pg_temp.snap('d1') - 'fingerprint')::text, 'UTF8'), 'sha256'), 'hex'),
  'the fingerprint covers the snapshot');

-- ── later settings never rewrite it ──────────────────────────────────
update public.workspaces set invoice_legal = '{"customer_capacity":"consumer","payment_terms":"Comptant."}'
 where id = '00000000-0000-4000-8000-0000001916b1';
update public.members set customer_capacity = 'business', payment_terms = null
 where id = '00000000-0000-4000-8000-0000001916c2';
select is(pg_temp.snap('d1')->>'buyer_capacity', 'consumer', 'a later capacity change leaves the issued invoice alone');
select is(pg_temp.snap('d1')->'clauses'->>'payment_terms', 'Paiement à 30 jours.', 'and so does a later terms change');
select throws_ok($$update public.invoices set legal_snapshot = '{}'::jsonb
                    where id = '00000000-0000-4000-8000-0000001916d1'$$,
  'invoices are immutable', 'the snapshot cannot be edited');

-- ── who states a capacity ────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001916a3","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.set_member_customer_capacity('00000000-0000-4000-8000-0000001916c2', 'consumer')$$,
  'not allowed to set the customer capacity', 'a plain member states nothing');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001916a4","role":"authenticated"}',true);
select throws_ok($$select public.set_member_customer_capacity('00000000-0000-4000-8000-0000001916c2', 'consumer')$$,
  'not allowed to set the customer capacity', 'nor does another space''s owner');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001916a1","role":"authenticated"}',true);
select throws_ok($$select public.set_member_customer_capacity('00000000-0000-4000-8000-0000001916c3', 'company')$$,
  'unknown customer capacity', 'only business or consumer');
select lives_ok($$select public.set_member_customer_capacity('00000000-0000-4000-8000-0000001916c3', 'consumer')$$,
  'whoever issues invoices states it');

select * from finish();
rollback;
