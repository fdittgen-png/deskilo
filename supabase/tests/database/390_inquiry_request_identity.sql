-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3745 (0721) -- an inquiry or a reply repeated after a lost answer
-- arrives once: the same request id with the same content answers the
-- first outcome and writes nothing; the same id with other content is
-- refused; two ids are two messages; a send without an id behaves as
-- before. Rolled back.
begin;
select plan(12);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000003745'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@req3745.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000003745b1','Request space','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003745a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000003745c1','00000000-0000-4000-8000-0000003745b1','00000000-0000-4000-8000-0000003745a1',true,true,'active');

-- a1 owns the space and publishes it; a2 asks.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003745a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000003745b1','{"host_type":"company"}',true)$$,
  'the owner publishes the page');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003745a2","role":"authenticated"}',true);

select set_config('t.inq', public.start_space_inquiry_v1('00000000-0000-4000-8000-0000003745b1', 'Can I visit?',
  '00000000-0000-4000-8000-000000374501')::text, true);
select is(public.start_space_inquiry_v1('00000000-0000-4000-8000-0000003745b1', 'Can I visit?',
            '00000000-0000-4000-8000-000000374501')::text,
          current_setting('t.inq'), 'a start repeated with its request id answers the same inquiry');
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inq')::uuid)), 1,
          'and the space received it once');
select throws_ok($$select public.start_space_inquiry_v1('00000000-0000-4000-8000-0000003745b1', 'Something else',
                   '00000000-0000-4000-8000-000000374501')$$,
  '22023', 'this request id was used for another message', 'the same id with other content is refused');

select set_config('t.m1', public.send_inquiry_message_v1(current_setting('t.inq')::uuid, 'Tomorrow at ten?',
  '00000000-0000-4000-8000-000000374502')::text, true);
select is(public.send_inquiry_message_v1(current_setting('t.inq')::uuid, 'Tomorrow at ten?',
            '00000000-0000-4000-8000-000000374502')::text,
          current_setting('t.m1'), 'a reply repeated with its request id answers the same message');
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inq')::uuid)), 2, 'and arrives once');
select throws_ok(format($$select public.send_inquiry_message_v1(%L, 'Tomorrow at eleven?',
                   '00000000-0000-4000-8000-000000374502')$$, current_setting('t.inq')),
  '22023', 'this request id was used for another message', 'a reply''s id with other content is refused');
select throws_ok(format($$select public.send_inquiry_message_v1(%L, 'Can I visit?',
                   '00000000-0000-4000-8000-000000374501')$$, current_setting('t.inq')),
  '22023', 'this request id was used for another message', 'a start''s id is not a reply''s');

select isnt(public.send_inquiry_message_v1(current_setting('t.inq')::uuid, 'Tomorrow at ten?',
              '00000000-0000-4000-8000-000000374503')::text,
            current_setting('t.m1'), 'another id is another message, even with the same words');
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inq')::uuid)), 3, 'so the thread holds three');

select lives_ok(format($$select public.send_inquiry_message(%L, 'Without an id')$$, current_setting('t.inq')),
  'a send without an id works as before');
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inq')::uuid)), 4, 'and writes its message');

reset role;
select * from finish();
rollback;
