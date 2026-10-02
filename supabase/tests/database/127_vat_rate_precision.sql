-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1870: a tax rate is stored exactly. Quebec's QST (9.975 %) and the
-- combined GST+QST rate (14.975 %) keep all their decimals, a rate of
-- six decimals fits, the 0 <= rate < 100 rule still holds, and the
-- independent CAD 1000.00 example computes 50.00 + 99.75 = 1149.75 from
-- the stored values rather than from 9.98.
begin;
select plan(9);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000001871a1','00000000-0000-0000-0000-000000000000','authenticated',
        'authenticated','a1@rates.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values ('00000000-0000-4000-8000-0000001871b1','Rates','CA','CAD','America/Toronto',
        '00000000-0000-4000-8000-0000001871a1','dev');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values
 ('00000000-0000-4000-8000-0000001871c1','00000000-0000-4000-8000-0000001871b1','GST',5,'S',true,'standard'),
 ('00000000-0000-4000-8000-0000001871c2','00000000-0000-4000-8000-0000001871b1','QST',9.975,'S',false,'standard'),
 ('00000000-0000-4000-8000-0000001871c3','00000000-0000-4000-8000-0000001871b1','GST+QST',14.975,'S',false,'standard'),
 ('00000000-0000-4000-8000-0000001871c4','00000000-0000-4000-8000-0000001871b1','Six decimals',7.123456,'S',false,'standard');

select col_type_is('public','vat_rates','percent','numeric(9,6)','vat_rates.percent holds six decimals');
select col_type_is('public','ledger_entries','vat_percent','numeric(9,6)','ledger_entries.vat_percent holds six decimals');
select is((select percent from public.vat_rates where id='00000000-0000-4000-8000-0000001871c2'),9.975::numeric,'QST stays 9.975, not 9.98');
select is((select percent from public.vat_rates where id='00000000-0000-4000-8000-0000001871c3'),14.975::numeric,'the combined rate stays 14.975');
select is((select percent from public.vat_rates where id='00000000-0000-4000-8000-0000001871c4'),7.123456::numeric,'six decimals survive');
select is((select round(100000 * percent / 100) from public.vat_rates where id='00000000-0000-4000-8000-0000001871c2'),
          9975::numeric,'QST on CAD 1000.00 is 99.75 (9975 cents), not 99.80');
select is((select sum(round(100000 * percent / 100)) + 100000 from public.vat_rates
            where id in ('00000000-0000-4000-8000-0000001871c1','00000000-0000-4000-8000-0000001871c2')),
          114975::numeric,'net 1000.00 + GST 50.00 + QST 99.75 = 1149.75');
select throws_ok($$insert into public.vat_rates (workspace_id, label, percent, category, is_default, group_key)
  values ('00000000-0000-4000-8000-0000001871b1','Too much',100,'S',false,'standard')$$,'23514',null,'a rate of 100 % is still refused');
select throws_ok($$insert into public.vat_rates (workspace_id, label, percent, category, is_default, group_key)
  values ('00000000-0000-4000-8000-0000001871b1','Negative',-1,'S',false,'standard')$$,'23514',null,'and a negative one');

select * from finish();
rollback;
