-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one function; two per-domain refusal helpers restated to call it)
--
-- #4415 -- one way to refuse. `public.refuse(code, detail, message)` raises with a DK code the app maps, the values of the
-- refusal as JSON in `detail`, and the words for the log in `message` (the code when none is given). From this migration on
-- the lint (`refusal_codes_test`) refuses a run-time `raise exception` with `P0001`, a bare `22023`, `42501` or `28000`, an
-- `exception when others` and a literal `interval '...'`; the per-domain helpers below call this one. It is the server's own:
-- no client role may call it.
--
-- restates 0836 (stock_config_refuse) 0604 (retention_refuse_unless_eligible)
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

select public.set_deskilo_schema_version(919);
