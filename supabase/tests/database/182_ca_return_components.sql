-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2361 (0425): the return of a Canadian registrant carries its taxes apart.
-- vat_return_summary adds `components` to a line whose taxes are known: the
-- GST and QST frozen on the issued invoices (CAD 1 000.00 -> 50.00 + 99.75), a
-- GST-only line, and the input tax of an expense split at the same rates (fully
-- and half deductible). A seller outside Canada gets the lines it always got,
-- and a line holding an invoice with no components carries none. Rolled back.
begin;
select plan(11);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000002361a2','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a2@ca2361.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,vat_regime,vat_id,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000002361b2','CA return','CA','CAD','America/Toronto','00000000-0000-4000-8000-0000002361a2','dev',
  'vat_registered','123456789 RT0001','{"invoicing":true,"inputVat":true}', '{}'),
 ('00000000-0000-4000-8000-0000002361b3','DE return','DE','EUR','Europe/Berlin','00000000-0000-4000-8000-0000002361a2','dev',
  'vat_registered','DE123456789','{"invoicing":true,"inputVat":true}', '{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002361c2','00000000-0000-4000-8000-0000002361b2','00000000-0000-4000-8000-0000002361a2',true,true,'active'),
 ('00000000-0000-4000-8000-0000002361c3','00000000-0000-4000-8000-0000002361b3','00000000-0000-4000-8000-0000002361a2',true,true,'active');

create or replace function pg_temp.inv(ws uuid, mm uuid, n text, cc text, percent numeric, gross int, net int, comps jsonb)
returns void language sql as $$
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (ws, mm, mm, n, 'Invoice', jsonb_build_array(jsonb_build_object('label','Desk','amount_cents',gross,'vat_percent',percent)),
          gross, case cc when 'CA' then 'CAD' else 'EUR' end, 'M', 'W', 'M', 's' || n, 'full', '2026-09-20 10:00+00',
          jsonb_build_array(jsonb_build_object('percent', percent, 'category', 'S', 'gross_cents', gross,
                'net_cents', net, 'vat_cents', gross - net) || comps),
          jsonb_build_object('seller_country', cc, 'vat_exigibility', 'invoice'));
$$;
select pg_temp.inv('00000000-0000-4000-8000-0000002361b2','00000000-0000-4000-8000-0000002361c2','CA-1','CA',14.975,114975,100000,
                   public.vat_components_entry('CA',14.975,100000,14975));
select pg_temp.inv('00000000-0000-4000-8000-0000002361b2','00000000-0000-4000-8000-0000002361c2','CA-2','CA',5,10500,10000,
                   public.vat_components_entry('CA',5,10000,500));
select pg_temp.inv('00000000-0000-4000-8000-0000002361b3','00000000-0000-4000-8000-0000002361c3','DE-1','DE',19,11900,10000,'{}'::jsonb);

insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at) values
 ('00000000-0000-4000-8000-0000002361b2','expense','submitted','00000000-0000-4000-8000-0000002361c2','00000000-0000-4000-8000-0000002361c2',
  '{"amount_cents": 57487, "vat": {"percent": 14.975, "deductible_pct": 100}}','confirmed','2026-09-15 10:00+00');

create or replace function pg_temp.line(ws uuid, p numeric, dir text) returns jsonb language sql as $$
  select l from public.vat_return_summary(ws, '2026-09-01', '2026-12-31') s, jsonb_array_elements(s.lines) l
   where (l ->> 'percent')::numeric = p and coalesce(l ->> 'direction', 'output') = dir;
$$;

select is((select string_agg(c ->> 'scheme' || ':' || (c ->> 'tax_cents'), ' ' order by o)
             from jsonb_array_elements(pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'output') -> 'components') with ordinality t(c, o)),
          'GST:5000 QST:9975', 'Quebec sales: GST 50.00 and QST 99.75 apart');
select is((pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'output') -> 'components' -> 1 ->> 'base_cents'),
          '100000', 'both on the price without the GST');
select is((pg_temp.line('00000000-0000-4000-8000-0000002361b2', 5, 'output') -> 'components' -> 0 ->> 'scheme'),
          'GST', 'a 5 % line is GST alone');
select is(jsonb_array_length(pg_temp.line('00000000-0000-4000-8000-0000002361b2', 5, 'output') -> 'components'), 1, 'one component');
select is((pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'output') ->> 'vat_cents')::int,
          (select sum((c ->> 'tax_cents')::int)::int from jsonb_array_elements(
             pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'output') -> 'components') c),
          'the components add up to the line tax');
select is((select string_agg(c ->> 'scheme' || ':' || (c ->> 'tax_cents'), ' ' order by o)
             from jsonb_array_elements(pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'input') -> 'components') with ordinality t(c, o)),
          'GST:2500 QST:4987', 'input tax: the ITC and the ITR are claimed apart');
select is((pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'input') ->> 'vat_cents')::int, 7487,
          'and they add up to the deductible tax');
select ok(not (pg_temp.line('00000000-0000-4000-8000-0000002361b3', 19, 'output') ? 'components'),
          'a German line carries no components');
select is((select count(*)::int from public.vat_return_summary('00000000-0000-4000-8000-0000002361b3', '2026-09-01', '2026-12-31') s,
                  jsonb_array_elements(s.lines) l where l ? 'components'), 0, 'none anywhere on a German return');

-- A line with an invoice that has no components is not split at all.
select pg_temp.inv('00000000-0000-4000-8000-0000002361b2','00000000-0000-4000-8000-0000002361c2','CA-OLD','CA',14.975,11498,10000,'{}'::jsonb);
select ok(not (pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'output') ? 'components'),
          'one invoice without components and the line is not split');
select is((pg_temp.line('00000000-0000-4000-8000-0000002361b2', 14.975, 'output') ->> 'invoice_count')::int, 2, 'both invoices are still counted');
select * from finish();
rollback;
