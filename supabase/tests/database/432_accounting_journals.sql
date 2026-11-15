-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3470: the business's accounting journals. An owner sets all four
-- journals, each with a code and a label; '{}' keeps the defaults. A value
-- with a line break, a tab or a pipe, a blank label, a code used twice or a
-- journal missing is refused whole and the stored value stays; a member is
-- refused; a direct write meets the same rules; any other update of the row
-- still works.
begin;
select plan(14);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000003470'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@journals.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
-- a1 owns W1, a2 is a plain member of W1.
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment) values
 ('00000000-0000-4000-8000-0000003470b1','Journals','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003470a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000003470c1','00000000-0000-4000-8000-0000003470b1','00000000-0000-4000-8000-0000003470a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000003470c2','00000000-0000-4000-8000-0000003470b1','00000000-0000-4000-8000-0000003470a2',false,false,'active');

create function pg_temp.mapping(p_sales_code text default 'VT', p_bank_label text default 'Banque BNP')
returns jsonb language sql as $$
  select jsonb_build_object(
    'sales', jsonb_build_object('code', p_sales_code, 'label', 'Ventes'),
    'bank', jsonb_build_object('code', 'BNP', 'label', p_bank_label),
    'purchases', jsonb_build_object('code', 'HA', 'label', 'Achats'),
    'misc', jsonb_build_object('code', 'OD', 'label', 'Opérations diverses'));
$$;
create function pg_temp.stored() returns jsonb language sql as $$
  select accounting_journals from public.workspaces where id = '00000000-0000-4000-8000-0000003470b1';
$$;
grant execute on all functions in schema pg_temp to authenticated;

select is(pg_temp.stored(), '{}'::jsonb, 'a business starts on the defaults');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003470a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping()) -> 'sales' ->> 'code',
  'VT', 'an owner sets the four journals');
select is(pg_temp.stored() -> 'bank' ->> 'code', 'BNP', 'and they are kept');
select throws_ok($$select public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping(E'VT\nX'))$$,
  '22023', 'the accounting journals are not whole', 'a line break in a code is refused');
select throws_ok($$select public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping('VT', E'Bank\tOther'))$$,
  '22023', 'the accounting journals are not whole', 'a tab in a label is refused');
select throws_ok($$select public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping('V|T'))$$,
  '22023', 'the accounting journals are not whole', 'a pipe in a code is refused');
select throws_ok($$select public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping('VT', '   '))$$,
  '22023', 'the accounting journals are not whole', 'a blank label is refused');
select throws_ok($$select public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping('BNP'))$$,
  '22023', 'the accounting journals are not whole', 'a code used twice is refused');
select throws_ok($$select public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping() - 'misc')$$,
  '22023', 'the accounting journals are not whole', 'a journal missing is refused');
select is(pg_temp.stored() -> 'sales' ->> 'code', 'VT', 'a refused value leaves the stored one');
select throws_ok($$update public.workspaces set accounting_journals = pg_temp.mapping(E'VT\r')
  where id = '00000000-0000-4000-8000-0000003470b1'$$,
  '23514', null, 'a direct write meets the same rules');
select lives_ok($$update public.workspaces set name = 'Journals renamed'
  where id = '00000000-0000-4000-8000-0000003470b1'$$, 'any other update of the row still works');
select is(public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', '{}'::jsonb), '{}'::jsonb,
  'an owner goes back to the defaults');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003470a2","role":"authenticated"}',true);
select throws_ok($$select public.set_accounting_journals('00000000-0000-4000-8000-0000003470b1', pg_temp.mapping())$$,
  '42501', 'only an owner sets the accounting journals', 'a member is refused');

select * from finish();
rollback;
