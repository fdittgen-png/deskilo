-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (the new device-named offline sale takes a receipt source of its own; no table, column or stored figure moves, and the
--  signature and the answers of the last release's clients stay as they are)
--
-- #4451 (E00) -- two devices of one till session may both ring sale 1 offline.
--
-- 0944 numbers an offline sale per (session, device), but the receipt it makes was still sourced by the session and the
-- sequence alone (`<session>:<seq>`), and a finalized source is unique per business (`counter_receipts_source_once`, 0893;
-- refused DKL04 by 0947). Device B's sale 1 therefore met device A's receipt and was refused. The identity of a device-named
-- offline source is now (business, session, device, seq):
--   * the all-zero device (a caller that names none, the documented legacy device) keeps `<session>:<seq>`;
--   * any other device is `<session>:<device>:<seq>`.
-- A sale accepted before this change keeps its stored source, and its request id still replays it (the request digest is read
-- before a source is built), so nothing already recorded is touched. At most 36 + 1 + 36 + 1 + 20 characters, inside the cap of 200.
--
-- patches 0944 (the live definer of counter_offline_sync_v1)

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

do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_offline_sync_v1(uuid, uuid, timestamptz, jsonb)'::regprocedure);
  v_old text := $o$'source_ref', p_session_id::text || ':' || v_seq))$o$;
  v_new text := $n$'source_ref', case when v_dev = '00000000-0000-0000-0000-000000000000'::uuid
                                          then p_session_id::text || ':' || v_seq::text
                                          else p_session_id::text || ':' || v_dev::text || ':' || v_seq::text end))$n$;
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, v_old, v_new);
  if v_next is null then
    raise exception '0957: the receipt source of counter_offline_sync_v1 was not found' using errcode = 'P0001';
  end if;
  if position('p_session_id::text || '':'' || v_dev::text' in v_next) = 0 then
    raise exception '0957: counter_offline_sync_v1 does not name the device in the receipt source' using errcode = 'P0001';
  end if;
  execute v_next;
end
$patch$;

select public.set_deskilo_schema_version(957);
