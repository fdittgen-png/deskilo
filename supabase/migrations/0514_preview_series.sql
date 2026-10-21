-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2575 -- a series preview names the dates that would fail BEFORE the
-- person submits: no silently partial series. The preview is the booking
-- itself, run and rolled back: `create_series` with the caller's own
-- rights inside a subtransaction, whose answer (booked, skipped) leaves
-- through the aborting exception. Nothing is written, no event or
-- notification survives, and no rule is restated here, so the preview
-- can never disagree with the booking. Security invoker: it can do
-- nothing the caller's own `create_series` call could not.

create or replace function public.preview_series(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_first_start timestamptz,
  p_first_end timestamptz,
  p_pattern text,
  p_until timestamptz,
  p_desk_id uuid default null,
  p_office_id uuid default null,
  p_level_id uuid default null
) returns jsonb language plpgsql volatile set search_path = public as $fn$
declare
  v_answer jsonb;
  v_detail text;
begin
  begin
    v_answer := public.create_series(p_workspace_id, p_seat_id, p_first_start, p_first_end,
      p_pattern, p_until, p_desk_id, p_office_id, p_level_id);
    raise exception using errcode = 'P0001', message = 'series-preview', detail = v_answer::text;
  exception when others then
    get stacked diagnostics v_detail = pg_exception_detail;
    if sqlerrm = 'series-preview' then
      return (v_detail::jsonb) - 'series_id';
    end if;
    raise;
  end;
end;
$fn$;
revoke execute on function public.preview_series(uuid, uuid, timestamptz, timestamptz, text, timestamptz, uuid, uuid, uuid)
  from public, anon;
grant execute on function public.preview_series(uuid, uuid, timestamptz, timestamptz, text, timestamptz, uuid, uuid, uuid)
  to authenticated;

select public.set_deskilo_schema_version(514);
