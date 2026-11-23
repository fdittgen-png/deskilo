-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (one function; two per-domain refusal helpers restated to call it)
--
-- #4415 -- one way to refuse. `public.refuse(code, detail, message)` raises with a DK code the app maps, the values of the
-- refusal as JSON in `detail`, and the words for the log in `message` (the code when none is given). From this migration on
-- the lint (`refusal_codes_test`) refuses a run-time `raise exception` with `P0001`, a bare `22023`, `42501` or `28000`, an
-- `exception when others` and a literal `interval '...'`; the per-domain helpers below call this one. It is the server's own:
-- no client role may call it.
--
-- Also (the follow-up of #4398): the decision of a count records what the count recorded, as stock_record did: the mode 'count' joins
-- the modes that skip today's master data (variants, lot tracking, active places) in stock_apply_lines; the piece rule (DKG25) and
-- the choice of lots stay.
--
-- restates 0836 (stock_config_refuse) 0604 (retention_refuse_unless_eligible) 0918 (stock_apply_lines)
create or replace function public.refuse(p_code text, p_detail jsonb default null, p_message text default null)
returns void
language plpgsql
immutable
set search_path = public
as $fn$
begin
  if p_code is null or p_code !~ '^DK[A-Z][A-Z0-9]{2}$' then
    raise exception 'refuse: % is not a DK code', p_code using errcode = 'XX000';
  end if;
  if p_detail is null then
    raise exception '%', coalesce(p_message, p_code) using errcode = p_code;
  end if;
  raise exception '%', coalesce(p_message, p_code) using errcode = p_code, detail = p_detail::text;
end;
$fn$;
revoke execute on function public.refuse(text, jsonb, text) from public, anon, authenticated;

-- restates 0836
create or replace function public.stock_config_refuse(p_field text, p_reason text)
returns void
language plpgsql
immutable
set search_path = public
as $fn$
begin
  perform public.refuse('DKG11', jsonb_build_object('field', p_field, 'reason', p_reason),
    format('the stock configuration is not valid: %s (%s)', p_field, p_reason));
end;
$fn$;
revoke execute on function public.stock_config_refuse(text, text) from public, anon, authenticated;

-- restates 0604
create or replace function public.retention_refuse_unless_eligible(p_what text, p_assessment jsonb)
returns void
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if coalesce(p_assessment ->> 'disposition', 'eligible_for_erasure_review') = 'eligible_for_erasure_review' then
    return;
  end if;
  perform public.refuse('DKE01', p_assessment, format('retention: the %s of this space are kept %s; nothing was deleted', p_what,
      case when (p_assessment ->> 'indefinite')::boolean
             then 'under a legal hold: ' || (p_assessment -> 'holds' -> 0 ->> 'reason')
           when p_assessment ->> 'disposition' = 'retain'
             then 'until ' || (p_assessment ->> 'retain_until') || ' under '
                  || coalesce(p_assessment -> 'rule' ->> 'source', 'the retention rule')
           else 'until a person reviews the retention rule ('
                || array_to_string(array(select jsonb_array_elements_text(p_assessment -> 'reasons')), ', ')
                || coalesce('; its clock ended on ' || (p_assessment ->> 'retain_until'), '') || ')'
      end));
end;
$fn$;
revoke execute on function public.retention_refuse_unless_eligible(text, jsonb) from public, anon, authenticated;

create or replace function pg_temp.occurrences(p_def text, p_old text)
returns int language sql as $f$
  select (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old)
$f$;
create or replace function pg_temp.patch(p_fn regprocedure, p_olds text[], p_news text[])
returns void language plpgsql as $f$
declare
  v_def text := pg_get_functiondef(p_fn);
  k int;
begin
  for k in 1 .. array_length(p_olds, 1) loop
    if pg_temp.occurrences(v_def, p_olds[k]) <> 1 then
      raise exception '0919: anchor % not found exactly once in %', k, p_fn::text using errcode = 'P0001';
    end if;
    v_def := replace(v_def, p_olds[k], p_news[k]);
  end loop;
  execute v_def;
end
$f$;
select pg_temp.patch('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamp with time zone, jsonb, text)'::regprocedure,
  array[
    $o$     where id = (e ->> 'item_id')::uuid and workspace_id = p_workspace_id and (stockable or p_mode in ('bridge', 'open', 'return', 'legacy'));$o$,
    $o$     where id = (e ->> 'from')::uuid and workspace_id = p_workspace_id and (active or p_mode in ('bridge', 'open', 'return', 'legacy'));$o$,
    $o$     where id = (e ->> 'to')::uuid and workspace_id = p_workspace_id and (active or p_mode in ('bridge', 'open', 'return', 'legacy'));$o$,
    $o$         where x.id = v_var and x.workspace_id = p_workspace_id and x.item_id = v_item.id and (x.active or p_mode in ('bridge', 'open', 'return', 'legacy'))) then$o$,
    $o$    if v_var is null and not (p_mode in ('bridge', 'open', 'return', 'legacy')) and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then$o$,
    $o$    if v_item.tracking <> 'none' and v_lot is null and not (p_mode in ('bridge', 'open', 'return', 'legacy')) then$o$],
  array[
    $n$     where id = (e ->> 'item_id')::uuid and workspace_id = p_workspace_id and (stockable or p_mode in ('bridge', 'open', 'return', 'legacy', 'count'));$n$,
    $n$     where id = (e ->> 'from')::uuid and workspace_id = p_workspace_id and (active or p_mode in ('bridge', 'open', 'return', 'legacy', 'count'));$n$,
    $n$     where id = (e ->> 'to')::uuid and workspace_id = p_workspace_id and (active or p_mode in ('bridge', 'open', 'return', 'legacy', 'count'));$n$,
    $n$         where x.id = v_var and x.workspace_id = p_workspace_id and x.item_id = v_item.id and (x.active or p_mode in ('bridge', 'open', 'return', 'legacy', 'count'))) then$n$,
    $n$    if v_var is null and not (p_mode in ('bridge', 'open', 'return', 'legacy', 'count')) and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then$n$,
    $n$    if v_item.tracking <> 'none' and v_lot is null and not (p_mode in ('bridge', 'open', 'return', 'legacy', 'count')) then$n$]);

select public.set_deskilo_schema_version(919);
