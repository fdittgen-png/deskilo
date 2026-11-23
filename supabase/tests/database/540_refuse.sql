-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4415 (0919): public.refuse raises with the code it is given, its detail as JSON and its words; a malformed code is an internal
-- error; the two per-domain helpers that call it raise what they raised before; no client role may call it. Rolled back.
begin;
select plan(7);

create or replace function pg_temp.caught(p_sql text) returns text language plpgsql as $f$
declare s text; m text; d text;
begin
  execute p_sql;
  return 'none';
exception when others then
  get stacked diagnostics s = returned_sqlstate, m = message_text, d = pg_exception_detail;
  return s || '|' || m || '|' || coalesce(d, '-');
end
$f$;

select is(pg_temp.caught($$select public.refuse('DKG11', '{"field": "x", "n": 2}'::jsonb, 'some words')$$), 'DKG11|some words|{"n": 2, "field": "x"}', 'a refusal arrives with its code, its words and its values as JSON');
select is(pg_temp.caught($$select public.refuse('DKG11')$$), 'DKG11|DKG11|', 'without words the message is the code, without values there is no detail');
select is(left(pg_temp.caught($$select public.refuse('P0001', null, 'x')$$), 5), 'XX000', 'a code that is not a DK code is an internal error, never a refusal');
select is(pg_temp.caught($$select public.stock_config_refuse('lines[0]', 'malformed')$$), 'DKG11|the stock configuration is not valid: lines[0] (malformed)|{"field": "lines[0]", "reason": "malformed"}', 'the stock helper raises what it raised before');
select ok(pg_temp.caught($$select public.retention_refuse_unless_eligible('records', '{"disposition": "retain", "retain_until": "2030-01-01", "rule": {"source": "the code"}}'::jsonb)$$)
  like 'DKE01|retention: the records of this space are kept until 2030-01-01 under the code; nothing was deleted|{%"retain_until": "2030-01-01"%}', 'and so does the retention helper');
select is(pg_temp.caught($$select public.retention_refuse_unless_eligible('records', '{"disposition": "eligible_for_erasure_review"}'::jsonb)$$), 'none', 'an eligible assessment refuses nothing');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'refuse'
            and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 0, 'no client role calls the helper');

select * from finish();
rollback;
