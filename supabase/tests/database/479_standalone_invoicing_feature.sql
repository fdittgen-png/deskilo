-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4165 (0826): the standalone commands refuse while the business has not
-- switched `standaloneInvoicing` on; the server decides, with the existing
-- `invoice_feature_disabled` refusal, and the registry names the feature.
begin;
select plan(12);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004176' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'sf' || n || '@example.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Feature 4176', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"invoicing": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01');

create function pg_temp.as_owner(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select ok((public.feature_registry() -> 'standaloneInvoicing' ->> 'parent') = 'invoicing'
      and (public.feature_registry() -> 'standaloneInvoicing' ->> 'default') = 'false',
  'the registry names the feature, under invoicing, off by default');
select is(pg_temp.as_owner(format($$select public.save_standalone_invoice_draft_v1(%L, null, null, %L, current_date, current_date + 30, '', '', '[]'::jsonb)::text$$,
  pg_temp.u(101), pg_temp.u(202))), 'ERR DKI01', 'while it is off, a draft is not saved');
select is(pg_temp.as_owner(format($$select public.preview_standalone_invoice_v1(%L, %L, 1)::text$$,
  pg_temp.u(101), pg_temp.u(202))), 'ERR DKI01', 'nor previewed');
select is(pg_temp.as_owner(format($$select public.issue_standalone_invoice_v1(%L, %L, 1, %L)::text$$,
  pg_temp.u(101), pg_temp.u(202), pg_temp.u(301))), 'ERR DKI01', 'nor issued');
update public.workspaces set feature_flags = '{"invoicing": true, "standaloneInvoicing": true}' where id = pg_temp.u(101);
select set_config('d.a', (pg_temp.as_owner(format($$select (public.save_standalone_invoice_draft_v1(%L, null, null, %L, current_date, current_date + 30, '', '', '[]'::jsonb) ->> 'draft_id')$$,
  pg_temp.u(101), pg_temp.u(202)))), false);
select ok(current_setting('d.a') ~ '^[0-9a-f-]{36}$', 'once it is on, a draft is saved');
select is(pg_temp.as_owner(format($$select (public.preview_standalone_invoice_v1(%L, %L, 1) -> 'missing')::text$$,
  pg_temp.u(101), current_setting('d.a'))), '["lines"]', 'and previewed: the empty draft says what it lacks');
update public.workspaces set feature_flags = '{"invoicing": true}' where id = pg_temp.u(101);
select is(pg_temp.as_owner(format($$select public.preview_standalone_invoice_v1(%L, %L, 1)::text$$,
  pg_temp.u(101), current_setting('d.a'))), 'ERR DKI01', 'switched off again, it refuses again');

-- ── the approval policy is applied by the core (#4262, #4166) ──
-- A business that requires approval for an invoice cannot issue a standalone
-- one directly, and its preview says why; without the policy it issues.
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(2);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01')
on conflict do nothing;
update public.workspaces set feature_flags = '{"invoicing": true, "standaloneInvoicing": true}' where id = pg_temp.u(101);
select set_config('d.b', (pg_temp.as_owner(format($$select (public.save_standalone_invoice_draft_v1(%L, null, null, %L, current_date, current_date + 30, '', '',
  '[{"description":"Consulting","quantity":"1","unit_price":"100","basis":"net","supply":"general","base_quantity":"1",
     "unit":{"code":"hour","label":"h","un_ece_code":"HUR"}}]'::jsonb) ->> 'draft_id')$$,
  pg_temp.u(101), pg_temp.u(202)))), false);
select is(pg_temp.as_owner(format($$select (public.preview_standalone_invoice_v1(%L, %L, 1) -> 'missing')::text$$,
  pg_temp.u(101), current_setting('d.b'))), '[]', 'without a policy the preview finds nothing missing');
insert into public.validation_policies (workspace_id, event_type, required_count)
values (pg_temp.u(101), 'invoice_issue', 1);
select is(pg_temp.as_owner(format($$select (public.preview_standalone_invoice_v1(%L, %L, 1) -> 'missing')::text$$,
  pg_temp.u(101), current_setting('d.b'))), '["approval_required"]', 'with a policy requiring approval the preview names it');
select is(pg_temp.as_owner(format($$select public.issue_standalone_invoice_v1(%L, %L, 1, %L)::text$$,
  pg_temp.u(101), current_setting('d.b'), pg_temp.u(302))), 'ERR DKI01', 'and the issue is refused');
select is((select count(*)::int from public.invoices where workspace_id = pg_temp.u(101)), 0, 'the refusal left no invoice');
delete from public.validation_policies where workspace_id = pg_temp.u(101) and event_type = 'invoice_issue';
select is(pg_temp.as_owner(format($$select (public.issue_standalone_invoice_v1(%L, %L, 1, %L) ->> 'replayed')$$,
  pg_temp.u(101), current_setting('d.b'), pg_temp.u(302))), 'false', 'without the policy the same draft issues');

select * from finish();
rollback;
