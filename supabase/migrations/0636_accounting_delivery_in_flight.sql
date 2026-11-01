-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (record_accounting_delivery patched at one anchor and given one defaulted
-- parameter; the old eleven-argument signature is dropped, its callers keep
-- working through the default)
--
-- 0636 (#2370) -- two runs that are truly concurrent could both read back
-- nothing and both create at a target without request-level idempotency.
-- A run now names how long a run can still be working (the delivery
-- function's wall-clock budget, which the function owns and passes in
-- seconds). Asked to prepare ('generated') a delivery that is 'generated'
-- or 'sent' and was last touched within that window, the log answers
-- outcome 'in_flight' and the adapter stops: it reads nothing back and
-- creates nothing. Older rows, and every other status, behave as before; a
-- window of 0 (the default) never answers it.
--
-- Token rotation (the other follow-up of #2370) needs no change here: 0628
-- already keeps the connection, its maps and its deliveries when the new
-- token names the company the connection recorded.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef(
    'public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text)'::regprocedure
  ) into v_def;
  -- each anchor must name exactly one place, or the patch is refused
  if (length(v_def) - length(replace(v_def, $a$p_error text$a$, ''))) / length($a$p_error text$a$) <> 1 then
    raise exception '0636: record_accounting_delivery signature anchor is not unique';
  end if;
  if (length(v_def) - length(replace(v_def,
        $a$return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'existing');$a$, '')))
     / length($a$return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'existing');$a$) <> 1 then
    raise exception '0636: record_accounting_delivery prepare anchor is not unique';
  end if;
  -- the signature
  v_def := pg_temp.anchor_replace(v_def, $a$p_error text$a$,
    $a$p_error text, p_in_flight_seconds int default 0$a$);
  if v_def is null or position($a$p_in_flight_seconds int default 0$a$ in v_def) = 0 then
    raise exception '0636: record_accounting_delivery signature anchor missing';
  end if;
  -- preparing a delivery another run touched within the window
  v_def := pg_temp.anchor_replace(v_def,
    $a$    return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'existing');$a$,
    $a$    if coalesce(p_in_flight_seconds, 0) > 0 and d.status in ('generated', 'sent')
       and greatest(d.created_datetime, coalesce(d.sent_at, d.created_datetime))
           > now() - make_interval(secs => p_in_flight_seconds) then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'in_flight');
    end if;
    return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'existing');$a$);
  if v_def is null or position($a$'outcome', 'in_flight'$a$ in v_def) = 0 then
    raise exception '0636: record_accounting_delivery prepare anchor missing';
  end if;
  drop function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text);
  execute v_def;
end
$migration$;

revoke execute on function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text, int)
  from public, anon, authenticated;
grant execute on function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text, int)
  to service_role;

select public.set_deskilo_schema_version(636);
