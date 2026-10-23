-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2564 (the handoff of #2587) / 0558: accounting_source_snapshot_v1 names,
-- beside its cutoff, the revision of the settings, the tax reference, the
-- book profiles and the calendar it was read with -- four tokens, each a
-- digest of the rows read in the same statement, naming data and not rows.
-- Two reads with nothing changed between them name the same four. A new
-- setting version of this workspace, a new platform-wide setting version,
-- a new tax-reference version, a new book-profile version, a changed
-- working day, a new closure day and a changed time zone each move exactly
-- their own token; an invoice booked in between moves none, while the read
-- after it does deliver the invoice; another workspace's own setting
-- version leaves this workspace's tokens alone; the book-profile token is
-- the digest of the very rows the answer delivers; every key version 1 had
-- is still there.
--
-- Two sessions: pgTAP runs a file in ONE transaction and cannot interleave
-- a second writer, so "a revision committed during an export is not mixed
-- into it" is emulated here as two sequential reads around each change --
-- the read before names the old token, the read after the new one, never a
-- third. That rows and tokens of ONE read belong to one snapshot rests on
-- the one statement that produces them, which
-- scripts/snapshot_concurrency_check.sh exercises with real psql processes
-- in the database job.
--
-- Seeded by direct insert as the replay's superuser and impersonated through
-- request.jwt.claims only, never `set local role`: the access rules of the
-- function (the role, the policies, the refusals) are pgTAP 200's claim,
-- not this file's.
begin;
select plan(20);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000025640'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@revisions.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
-- a1 owns W1 (the workspace under test), a2 owns W2 (the isolation control).
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by) values
 ('00000000-0000-4000-8000-0000025640b1','Revisions','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025640a1'),
 ('00000000-0000-4000-8000-0000025640b2','Revisions other','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025640a2');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000025640c1','00000000-0000-4000-8000-0000025640b1','00000000-0000-4000-8000-0000025640a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000025640c2','00000000-0000-4000-8000-0000025640b2','00000000-0000-4000-8000-0000025640a2',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id) values
 ('00000000-0000-4000-8000-0000025640d1','00000000-0000-4000-8000-0000025640b1','Atelier','111');
insert into public.book_profiles(workspace_id,issuer_site_id,authority_mode,external_system,functional_currency,
  fiscal_year_start_month,fiscal_year_start_day,accounting_basis,effective_from,revision) values
 ('00000000-0000-4000-8000-0000025640b1','00000000-0000-4000-8000-0000025640d1','pre_accounting','','EUR',1,1,'accrual','2025-01-01',1);

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000025640' || p)::uuid;
$$;
-- The caller is named by a claim only (see the header). Every call is one
-- statement of the file's transaction: a read of its own.
create function pg_temp.snap(p_user text, p_ws text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  select public.accounting_source_snapshot_v1(pg_temp.u(p_ws), date '2026-01-01', date '2026-12-31') into v;
  return v;
end;
$$;
-- The revisions that differ between two answers, by name.
create function pg_temp.moved(a jsonb, b jsonb) returns text[] language sql as $$
  select coalesce(array_agg(k order by k), '{}'::text[])
    from jsonb_object_keys(a -> 'revisions') k
   where a -> 'revisions' ->> k is distinct from b -> 'revisions' ->> k;
$$;
create function pg_temp.r(p text) returns jsonb language sql as $$
  select current_setting(p)::jsonb;
$$;

-- Two reads, nothing changed between them.
select set_config('r.s1', pg_temp.snap('a1', 'b1')::text, true);
select set_config('r.s2', pg_temp.snap('a1', 'b1')::text, true);
select set_config('r.o1', pg_temp.snap('a2', 'b2')::text, true);

select is(pg_temp.r('r.s1') ->> 'status', 'ok', 'the owner is answered');
select is((select array_agg(k order by k) from jsonb_object_keys(pg_temp.r('r.s1') -> 'revisions') k),
  array['book_profile', 'calendar', 'settings', 'tax_reference'],
  'the answer names the four revisions beside its cutoff');
select ok((select bool_and(t.v ~ '^[0-9a-f]{32}$') from jsonb_each_text(pg_temp.r('r.s1') -> 'revisions') t(k, v)),
  'each revision is a digest (32 hex characters), never empty');
select is(pg_temp.r('r.s2') -> 'revisions', pg_temp.r('r.s1') -> 'revisions',
  'two reads with nothing changed between them name the same four revisions');

-- A new setting version of the workspace (the registry's own writer).
select ok(public.store_setting(pg_temp.u('b1'), 'booking.walk_up_window_minutes', '300'::jsonb, 'pgTAP 261', pg_temp.u('a1')),
  'a new setting version of the workspace is stored');
select set_config('r.s3', pg_temp.snap('a1', 'b1')::text, true);
select set_config('r.o2', pg_temp.snap('a2', 'b2')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s2'), pg_temp.r('r.s3')), array['settings'],
  'a new setting version of the workspace moves the settings revision and nothing else');
select is(pg_temp.moved(pg_temp.r('r.o1'), pg_temp.r('r.o2')), '{}'::text[],
  'another workspace''s own setting version leaves this workspace''s revisions alone');

-- A new platform-wide setting version feeds every workspace's effective values.
select ok(public.store_setting(null, 'directory.upcoming_window_days', '33'::jsonb, 'pgTAP 261', pg_temp.u('a1')),
  'a new platform-wide setting version is stored');
select set_config('r.s4', pg_temp.snap('a1', 'b1')::text, true);
select set_config('r.o3', pg_temp.snap('a2', 'b2')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s3'), pg_temp.r('r.s4')), array['settings'],
  'a platform-wide setting version moves the settings revision of this workspace and nothing else');
select is(pg_temp.moved(pg_temp.r('r.o2'), pg_temp.r('r.o3')), array['settings'],
  'and that of the other workspace too, whose effective values it feeds as well');

-- A new tax-reference version (a platform value the law decides).
insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed) values
 ('rate', 'FR', 'pgtap_2564', '2026-01-01',
  '{"label": "Taux test", "percent": 5.5, "group": "reduced", "category": "S"}'::jsonb, 'pgTAP 261', false);
select set_config('r.s5', pg_temp.snap('a1', 'b1')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s4'), pg_temp.r('r.s5')), array['tax_reference'],
  'a new tax-reference version moves the tax-reference revision and nothing else');

-- A new book-profile version of the one issuer.
insert into public.book_profiles(workspace_id,issuer_site_id,authority_mode,external_system,functional_currency,
  fiscal_year_start_month,fiscal_year_start_day,accounting_basis,effective_from,revision) values
 ('00000000-0000-4000-8000-0000025640b1','00000000-0000-4000-8000-0000025640d1','pre_accounting','','EUR',7,1,'accrual','2026-07-01',2);
select set_config('r.s6', pg_temp.snap('a1', 'b1')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s5'), pg_temp.r('r.s6')), array['book_profile'],
  'a new book-profile version moves the book-profile revision and nothing else');
select is((pg_temp.r('r.s6') #>> '{totals,book_profiles,count}')::int, 2,
  'and the read after it delivers both versions (positive control)');
select is(pg_temp.r('r.s6') #>> '{revisions,book_profile}',
  (select md5(string_agg((p - 'id')::text, '|' order by p->>'issuer_site_id', p->>'effective_from', (p->>'revision')::int))
     from jsonb_array_elements(pg_temp.r('r.s6') -> 'book_profiles') p),
  'the book-profile revision is the digest of the very profile rows the answer delivers');

-- The calendar: a working day, a closure day, the time zone.
update public.workspaces
   set booking_rules = coalesce(booking_rules, '{}'::jsonb) || '{"work_end_minutes": 1080}'::jsonb
 where id = pg_temp.u('b1');
select set_config('r.s7', pg_temp.snap('a1', 'b1')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s6'), pg_temp.r('r.s7')), array['calendar'],
  'a changed working day moves the calendar revision and nothing else');
insert into public.closure_days(workspace_id, day, reason) values (pg_temp.u('b1'), '2026-08-14', 'pont');
select set_config('r.s8', pg_temp.snap('a1', 'b1')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s7'), pg_temp.r('r.s8')), array['calendar'],
  'a new closure day moves the calendar revision and nothing else');
update public.workspaces set timezone = 'Europe/Berlin' where id = pg_temp.u('b1');
select set_config('r.s9', pg_temp.snap('a1', 'b1')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s8'), pg_temp.r('r.s9')), array['calendar'],
  'a changed time zone moves the calendar revision and nothing else');

-- A row of the books themselves is not a reference: no revision moves.
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
 values (pg_temp.u('b1'), pg_temp.u('c1'), pg_temp.u('c1'), 'R-1', 'R-1', '[]'::jsonb, 1200, 'EUR', 'M', 'W', 'O', 's', '2026-03-10 10:00+00');
select set_config('r.s10', pg_temp.snap('a1', 'b1')::text, true);
select is(pg_temp.moved(pg_temp.r('r.s9'), pg_temp.r('r.s10')), '{}'::text[],
  'an invoice booked between two reads moves none of the four revisions');
select is((pg_temp.r('r.s10') #>> '{totals,invoices,count}')::int, 1,
  'while the read after it does deliver the invoice (positive control)');

select ok((select bool_and(pg_temp.r('r.s10') ? k)
             from unnest(array['version', 'status', 'workspace_id', 'from', 'to', 'timezone', 'principal',
                               'cutoff', 'at', 'invoices', 'matches', 'ledger', 'repartitions',
                               'book_profiles', 'purchases', 'totals']) k),
  'every key version 1 had is still there');

select * from finish();
rollback;
