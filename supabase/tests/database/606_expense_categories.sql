-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4512 (0998): the categories an expense is filed under are the business's own records. A business starts with coffee,
-- supplies, equipment and other (and the retired scheduled); an expense or a purchase draft names one by identity or by its
-- code (case-folded) and keeps the label it had; anything else, a category of another business, an empty one or a retired
-- one is DKX01 -- on a draft that already holds a category retired since, the draft keeps it; the owner adds, renames and
-- retires with the right and the feature, a plain member cannot; a name is kept once among the active ones; a category is
-- never deleted and its code never moves. Rolled back.
begin;
select plan(19);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004512' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.run_as(n int, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  execute 'reset role';
  return coalesce(v, 'null');
end $f$;
create function pg_temp.cat(p_ws int, p_code text) returns uuid language sql stable as $f$
  select id from public.expense_categories where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create function pg_temp.exp(p_user int, p_ws int, p_cat text) returns text language sql as $f$
  select pg_temp.run_as(p_user, format('select public.submit_expense(%L, 1200, %L, ''x'', null, null)::text', pg_temp.u(p_ws), p_cat))
$f$;
create function pg_temp.save(p_user int, p_ws int, p_body jsonb) returns text language sql as $f$
  select pg_temp.run_as(p_user, format('select public.expense_category_save_v1(%L, gen_random_uuid(), %L::jsonb)::text', pg_temp.u(p_ws), p_body))
$f$;
create function pg_temp.draft(p_user int, p_ws int, p_payload jsonb, p_rev int default 0) returns text language sql as $f$
  select pg_temp.run_as(p_user, format('select public.save_purchase_draft_v1(%L, gen_random_uuid(), %s, %L::jsonb)::text', pg_temp.u(p_ws), p_rev, p_payload))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'expcat' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
  (pg_temp.u(101), 'Categories 4512', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"purchases": true, "expenseCategories": true}'),
  (pg_temp.u(102), 'Other 4512', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"purchases": true, "expenseCategories": true}'),
  (pg_temp.u(103), 'Off 4512', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"purchases": true, "expenseCategories": false}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(1), true, true, 'active', '2026-01-01'),
  (pg_temp.u(204), pg_temp.u(103), pg_temp.u(1), true, true, 'active', '2026-01-01');

-- ── what a business starts with ──
select is((select string_agg(code || case when retired_at is null then '' else '!' end, ',' order by sort_order)
             from public.expense_categories where workspace_id = pg_temp.u(101)),
  'coffee,supplies,equipment,other,scheduled!', 'a business starts with four active categories and the retired scheduled');

-- ── naming one ──
select is(pg_temp.exp(2, 101, 'Coffee') ~ '^[0-9a-f-]{36}$', true, 'an expense names a category by its code, case-folded');
select is((select payload ->> 'category' || '|' || (payload ->> 'category_id') from public.events
            where workspace_id = pg_temp.u(101) and type = 'expense' and payload ->> 'category_id' = pg_temp.cat(101, 'coffee')::text limit 1),
  'coffee|' || pg_temp.cat(101, 'coffee'), 'and keeps its label and its identity');
select is(pg_temp.exp(2, 101, 'tea'), 'ERR DKX01 expense_category_unknown', 'a text that names no category is refused');
select is(pg_temp.exp(2, 101, ''), 'ERR DKX01 expense_category_unknown', 'so is an empty one');
select is(pg_temp.exp(2, 101, 'c_nowhere'), 'ERR DKX01 expense_category_unknown', 'and a category of another business, which this one does not have');
select is(pg_temp.exp(2, 101, 'scheduled'), 'ERR DKX01 expense_category_unknown', 'and a retired one');

-- ── the owner keeps the list ──
select set_config('c.a', pg_temp.save(1, 101, '{"label": "Cleaning", "sort_order": 15}'), false);
select ok(current_setting('c.a') like '{%', 'the owner adds a category: ' || current_setting('c.a'));
select is(pg_temp.save(2, 101, '{"label": "Printing"}'), 'ERR DKN01', 'a plain member cannot');
select is(pg_temp.save(1, 103, '{"label": "Printing"}'), 'ERR DKN01', 'nor can anyone while the feature is off');
select is(pg_temp.save(1, 101, '{"label": " cleaning "}'), 'ERR DKX01 label_taken', 'a name is kept once among the active ones');
select is(pg_temp.exp(2, 101, current_setting('c.a')::jsonb ->> 'code') ~ '^[0-9a-f-]{36}$', true, 'an expense names the new category by its code');
select is((select payload ->> 'category' from public.events where workspace_id = pg_temp.u(101) and type = 'expense'
            and payload ->> 'category_id' = current_setting('c.a')::jsonb ->> 'id' limit 1), 'Cleaning', 'and keeps the label it had');
select set_config('c.r', pg_temp.save(1, 101, format('{"id": "%s", "label": "Cleaning supplies"}', current_setting('c.a')::jsonb ->> 'id')::jsonb), false);
select is((select string_agg(payload ->> 'category', ',' order by created_at) from public.events
            where workspace_id = pg_temp.u(101) and type = 'expense' and payload ->> 'category_id' = current_setting('c.a')::jsonb ->> 'id'),
  'Cleaning', 'a rename changes no expense already filed');

-- ── a draft keeps a category retired since ──
select set_config('d.a', pg_temp.draft(2, 101, jsonb_build_object('kind', 'member_receipt', 'category_id', current_setting('c.a')::jsonb ->> 'id', 'lines', jsonb_build_array(jsonb_build_object('description', 'Mop', 'gross_cents', 1200)))), false);
select is((select category from public.purchase_documents where id = (current_setting('d.a')::jsonb ->> 'purchase_id')::uuid), 'Cleaning supplies',
  'a receipt draft keeps the label of the category it was filed under');
select ok(pg_temp.run_as(1, format('select public.expense_category_retire_v1(%L, gen_random_uuid(), %L, true)::text', pg_temp.u(101), current_setting('c.a')::jsonb ->> 'id')) like '{%', 'the owner retires it');
select is(pg_temp.draft(2, 101, jsonb_build_object('kind', 'member_receipt', 'purchase_id', current_setting('d.a')::jsonb ->> 'purchase_id',
  'category_id', current_setting('c.a')::jsonb ->> 'id', 'lines', jsonb_build_array(jsonb_build_object('description', 'Mop', 'gross_cents', 1200))), 1) ~ '^\{', true, 'the draft that holds it keeps it');
select is(pg_temp.draft(2, 101, jsonb_build_object('kind', 'member_receipt', 'category_id', current_setting('c.a')::jsonb ->> 'id', 'lines', jsonb_build_array(jsonb_build_object('description', 'Mop', 'gross_cents', 1200)))),
  'ERR DKX01 expense_category_unknown', 'a new draft cannot start on it');

select is(pg_temp.run_as(2, format('select (public.submit_purchase_v1(%L, %L, 2, gen_random_uuid()) ->> ''state'')', pg_temp.u(101), current_setting('d.a')::jsonb ->> 'purchase_id')),
  'pending', 'the draft that holds the retired category is submitted: the expense it files keeps that category');

select * from finish();
rollback;
