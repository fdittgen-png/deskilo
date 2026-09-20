-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1295 — a template may carry the invoice series, never the counter.
--
-- Numbering is configuration: a template that sets tariffs and hours but
-- leaves the invoice series on a product default has not configured the
-- space. It is also the one piece of configuration that can destroy
-- something by arriving — re-issuing a number that is already on a
-- customer's invoice.
--
-- So the split is asserted from both ends: the state never leaves the
-- source (there is no payload anywhere that could carry a counter), and
-- a target that has already issued keeps its own counter exactly.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000000b1';
  fresh uuid; used uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'seq@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('SeqFresh', 'FR', 'EUR', 'Europe/Paris', u) returning id into fresh;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('SeqUsed', 'FR', 'EUR', 'Europe/Paris', u) returning id into used;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (fresh, u, true, true), (used, u, true, true);

  -- SeqUsed has already issued 73 invoices under its own prefix.
  insert into public.number_sequences (workspace_id, journal, prefix, suffix,
                                       date_part, digits, reset, gapless, next_value)
  values (used, 'invoice', 'OLD-', '', 'year', 4, 'yearly', true, 73);

  perform set_config('deskilo.seq.fresh', fresh::text, false);
  perform set_config('deskilo.seq.used', used::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end
$seed$;

create or replace function pg_temp.template(p_date text default 'year',
                                           p_reset text default 'yearly')
returns jsonb language sql as $$
  select jsonb_build_object('workspace', '{}'::jsonb, 'tables',
    jsonb_build_object('number_sequences', jsonb_build_array(
      jsonb_build_object('journal', 'invoice', 'prefix', 'TPL-', 'suffix', '',
                         'date_part', p_date, 'digits', 5,
                         'reset', p_reset, 'gapless', true))));
$$;

create or replace function pg_temp.seq(p_ws text, p_field text)
returns text language sql as $$
  select case p_field
           when 'next' then next_value::text
           when 'prefix' then prefix
           when 'digits' then digits::text
         end
    from public.number_sequences
   where workspace_id = current_setting('deskilo.seq.' || p_ws)::uuid
     and journal = 'invoice';
$$;

select pg_temp.seed();

-- ------------------------------------------- the state never travels
select is(
  (select string_agg(k, ',' order by k)
     from jsonb_object_keys(
       public.export_workspace_configuration(current_setting('deskilo.seq.used')::uuid)
         ->'tables'->'number_sequences'->0) k),
  'date_part,digits,gapless,journal,prefix,reset,suffix',
  'the export carries the FORMAT columns and nothing else');

select is(
  (public.export_workspace_configuration(current_setting('deskilo.seq.used')::uuid)
     ->'tables'->'number_sequences'->0) ? 'next_value',
  false,
  'no payload anywhere carries a counter — it cannot be leaked because '
  'it is never exported');

-- --------------------------------- a journal never used here is INSERTED
select public.import_workspace_configuration(
  current_setting('deskilo.seq.fresh')::uuid, pg_temp.template(), 'merge');

select is(pg_temp.seq('fresh', 'prefix'), 'TPL-',
  'a fresh workspace takes the template series');
select is(pg_temp.seq('fresh', 'next'), '1',
  'and starts at one: rows appear lazily, so this was an insert');

-- ------------------------ a journal that has issued keeps its counter
select public.import_workspace_configuration(
  current_setting('deskilo.seq.used')::uuid, pg_temp.template(), 'merge');

select is(pg_temp.seq('used', 'prefix'), 'TPL-',
  'an issued series takes the template FORMAT');
select is(pg_temp.seq('used', 'digits'), '5',
  'including the width');
select is(pg_temp.seq('used', 'next'), '73',
  'and keeps its own counter EXACTLY — 73 invoices were issued under it');

-- --------------------------------------------------- the two refusals
select throws_matching(
  format($$ select public.import_workspace_configuration(%L, %s, 'merge') $$,
         current_setting('deskilo.seq.fresh'),
         quote_literal(pg_temp.template('none', 'yearly')::text) || '::jsonb'),
  'restart more often',
  'a series that restarts more often than it prints its date is refused, '
  'not applied — it would re-issue numbers in the target (#1320)');

select throws_matching(
  format($$ select public.import_workspace_configuration(%L, %s, 'merge') $$,
         current_setting('deskilo.seq.used'),
         quote_literal(pg_temp.template('none', 'never')::text) || '::jsonb'),
  'could repeat one',
  'taking the date away from a series that already issued is refused');

select * from finish();
rollback;
