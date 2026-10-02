-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0345 (MCP parity) -- an assistant's "free" is the booking engine's own
-- verdict.
--
-- get_availability answered "free" from two facts only: no active booking
-- on the seat and no seat block. The app's booking engine refuses far more
-- (closed days, opening hours, booking granularity -- "bookings must cover
-- a half-day" --, the desk/office/level reserved as a whole, the member's
-- own one-place and simultaneous limits). Measured on the hosted project:
-- a half-day workspace's seats read "free" for a window the engine
-- refuses. MCP is another UI over the same process, so it asks the same
-- engine: `mcp_seat_bookable` tries the booking as the member inside a
-- subtransaction and always rolls it back (no row, no event, no
-- notification survives); null = the engine would accept it, otherwise the
-- engine's own refusal text.

create or replace function public.mcp_seat_bookable(p_workspace_id uuid, p_seat_id uuid, p_from timestamptz, p_to timestamptz)
returns text language plpgsql volatile set search_path = public as $fn$
begin
  if auth.uid() is null then return 'not authenticated'; end if;
  begin
    perform public.create_reservation(p_workspace_id => p_workspace_id, p_seat_id => p_seat_id,
      p_office_id => null, p_starts_at => p_from, p_ends_at => p_to);
    raise exception using errcode = 'P0001', message = 'mcp-availability-probe';
  exception when others then
    return case when sqlerrm = 'mcp-availability-probe' then null else sqlerrm end;
  end;
end;
$fn$;
revoke execute on function public.mcp_seat_bookable(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;

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
  v_next text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'mcp_read_v1';
  if v_def is null then raise exception '0345: mcp_read_v1 not found'; end if;
  if position('mcp_seat_bookable' in v_def) > 0 then
    raise exception '0345: mcp_read_v1 already asks the engine';
  end if;
  v_next := pg_temp.anchor_replace(v_def,
    $a$'free', not exists (select 1 from public.reservations x
                                      where x.seat_id = s.id and x.status in ('reserved', 'checked_in')
                                        and x.starts_at < v_to and x.ends_at > v_from)
                         and not (s.blocked_from is not null and s.blocked_from < v_to
                                  and coalesce(s.blocked_to, 'infinity') > v_from)) as r$a$,
    $b$'free', public.mcp_seat_bookable(p_workspace_id, s.id, v_from, v_to) is null) as r$b$);
  if v_next is null then raise exception '0345: get_availability anchor missing'; end if;
  execute v_next;
end
$migration$;

select public.set_deskilo_schema_version(345);
