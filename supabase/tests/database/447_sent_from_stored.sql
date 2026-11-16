-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4120 (0795) -- what is sent to a network is built from what the invoice
-- stored, and what was sent can be read again. An invoice issued now freezes
-- the business's own account and the tax reference's revision; a later change
-- of either leaves it as it was, and the sending basis says nothing is today's.
-- An invoice issued before (no frozen values) is sent with today's, and the
-- basis names them. The document that left is read again only by someone who
-- may issue, only as the exact stored bytes, and never once they no longer
-- match their hash. Rolled back.
begin;
select plan(15);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004120' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'sent' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime,
                               feature_flags, street, city, postal_code, payment_instructions)
values (pg_temp.u(101), 'Sent 4120', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'not_subject',
        '{"invoicing": true}', '1 rue de la Paix', 'Paris', '75002',
        '{"iban": "FR7630006000011234567890189", "bic": "AGRIFRPP"}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active', '2026-01-01');
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(301), pg_temp.u(101), 'Client', 'active', 100, 'blocked', '2026-01-01'),
       (pg_temp.u(302), pg_temp.u(101), 'Later', 'active', 100, 'blocked', '2026-01-01');
insert into public.managed_identities (workspace_id, member_id, identity)
values (pg_temp.u(101), pg_temp.u(301),
        public.managed_identity_clean('{"first_name": "Ada", "last_name": "Client", "street": "2 rue du Bac", "city": "Paris", "postal_code": "75007"}')),
       (pg_temp.u(101), pg_temp.u(302),
        public.managed_identity_clean('{"first_name": "Bea", "last_name": "Later", "street": "3 rue du Bac", "city": "Paris", "postal_code": "75007"}'));
delete from public.fee_bands where workspace_id = pg_temp.u(101);
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (pg_temp.u(101), 0, 100, 3500, 1000);

create function pg_temp.as_owner(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return v;
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
create function pg_temp.as_member(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(2), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return v;
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
create function pg_temp.as_admin(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(3), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return v;
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('t.inv', pg_temp.as_owner(format(
  'select public.create_invoice(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(301), '2026-09')), true);

-- ── frozen at issue ──
select is((select legal_snapshot -> 'payment' ->> 'iban' from public.invoices where id = current_setting('t.inv')::uuid),
  'FR7630006000011234567890189', 'an invoice issued now keeps the business''s account as it printed it');
select isnt((select legal_snapshot ->> 'tax_reference_revision' from public.invoices where id = current_setting('t.inv')::uuid),
  null, 'and the revision of the tax reference it was issued under');
update public.workspaces set payment_instructions = '{"iban": "DE89370400440532013000"}' where id = pg_temp.u(101);
select is(pg_temp.as_owner(format('select public.invoice_send_basis(%L)::text', current_setting('t.inv'))),
  jsonb_build_object('payment', jsonb_build_object('iban', 'FR7630006000011234567890189', 'bic', 'AGRIFRPP'),
                     'payment_today', false, 'reference_today', false)::text,
  'after a change of account, the sending is built from the account the invoice stored');
update public.tax_reference set valid_to = '2999-01-01'
 where id = (select id from public.tax_reference where country = 'FR' and valid_to is null order by valid_from desc limit 1);
select is((pg_temp.as_owner(format('select public.invoice_send_basis(%L)::text', current_setting('t.inv')))::jsonb ->> 'reference_today'),
  'true', 'a tax reference changed since the issue is named as today''s');

-- ── an invoice issued before: sent with today's values, and they are named ──
alter table public.invoices disable trigger invoices_no_mutation;
update public.invoices set legal_snapshot = legal_snapshot - 'payment' - 'tax_reference_revision'
 where id = current_setting('t.inv')::uuid;
alter table public.invoices enable trigger invoices_no_mutation;
select is((pg_temp.as_owner(format('select public.invoice_send_basis(%L)::text', current_setting('t.inv')))::jsonb
            - 'payment')::text,
  '{"payment_today": true, "reference_today": true}',
  'an invoice issued before is never rewritten: its sending names the values that are today''s');

-- ── what was sent, read again ──
insert into public.invoice_transmissions (id, workspace_id, invoice_id, provider, status, format)
values (pg_temp.u(901), pg_temp.u(101), current_setting('t.inv')::uuid, 'generic', 'sent', 'peppolBis');
insert into public.invoice_transmission_artifacts (transmission_id, workspace_id, bytes, sha256, file_name, mime_type)
values (pg_temp.u(901), pg_temp.u(101), convert_to('<Invoice>sent</Invoice>', 'UTF8'),
        encode(extensions.digest(convert_to('<Invoice>sent</Invoice>', 'UTF8'), 'sha256'), 'hex'),
        'peppolBis.xml', 'application/xml');
select is(convert_from(decode(
            (pg_temp.as_owner(format('select public.invoice_sent_document(%L)::text', current_setting('t.inv')))::jsonb ->> 'bytes'),
            'base64'), 'UTF8'),
  '<Invoice>sent</Invoice>', 'a person who may issue reads the exact bytes that left');
select is(pg_temp.as_member(format('select public.invoice_sent_document(%L)::text', current_setting('t.inv'))),
  'ERR DKN01', 'a member without the right to issue is refused');
select is(pg_temp.as_admin(format('select public.invoice_sent_document(%L)::text', current_setting('t.inv'))),
  'ERR DKN01', 'and so is an administrator without the right to issue');
select is(pg_temp.as_admin(format('select public.invoice_send_basis(%L)::text', current_setting('t.inv'))),
  'ERR DKN01', 'who is refused the sending basis too');
select is(pg_temp.as_owner(format('select public.invoice_sent_document(%L)::text', gen_random_uuid())),
  'ERR DKN01', 'an unknown invoice gets the same answer');
update public.invoice_transmission_artifacts set bytes = convert_to('<Invoice>changed</Invoice>', 'UTF8')
 where transmission_id = pg_temp.u(901);
select is(pg_temp.as_owner(format('select public.invoice_sent_document(%L)::text', current_setting('t.inv'))),
  'ERR DKI09', 'a stored file that no longer matches its hash is said not intact, never handed out');
select ok(not has_table_privilege('authenticated', 'public.invoice_transmission_artifacts', 'select')
          and not has_table_privilege('anon', 'public.invoice_transmission_artifacts', 'select'),
  'nobody reads the stored files directly');
select is(pg_temp.as_member(format('select public.invoice_send_basis(%L)::text', current_setting('t.inv'))),
  'ERR DKN01', 'nor the sending basis without the right to issue');

-- ── issued without an account: the empty block is the invoice's own ──
update public.workspaces set payment_instructions = '{}' where id = pg_temp.u(101);
select set_config('t.inv2', pg_temp.as_owner(format(
  'select public.create_invoice(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(302), '2026-09')), true);
update public.workspaces set payment_instructions = '{"iban": "DE89370400440532013000"}' where id = pg_temp.u(101);
select is((pg_temp.as_owner(format('select public.invoice_send_basis(%L)::text', current_setting('t.inv2')))::jsonb -> 'payment'),
  '{}'::jsonb, 'an invoice issued without an account stores none, and an account added since is not its own');
select is((pg_temp.as_owner(format('select public.invoice_send_basis(%L)::text', current_setting('t.inv2')))::jsonb ->> 'payment_today'),
  'false', 'so its sending names no account as today''s: none is sent');

select * from finish();
rollback;
