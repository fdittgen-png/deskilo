-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0397 (#2313) — a workspace's colour PATTERN: the owner picks how the
-- space's colour is drawn where it must be told apart from the others
-- (its card on Me, its chip, the entry transition). One more key in
-- `workspaces.branding`, from a curated set; `branding_clean` (0378) is
-- restated whole with the key added, strict refusing an unknown value
-- and lenient (an import, a template) dropping it.

create or replace function public.branding_clean(p_incoming jsonb, p_strict boolean default true)
returns jsonb
language plpgsql immutable set search_path = public as $fn$
declare
  v_out jsonb := '{}'::jsonb;
  v_key text;
  v_seed text;
  v_palette jsonb;
  v_seat text;
begin
  if p_incoming is null or jsonb_typeof(p_incoming) <> 'object' then
    if p_strict then raise exception 'branding is an object'; end if;
    return v_out;
  end if;
  for v_key in select jsonb_object_keys(p_incoming) loop
    if v_key not in ('seed_color', 'office_palette', 'seat_palette', 'symbol_text', 'symbol_color', 'pattern') then
      if p_strict then raise exception 'unknown branding key %', v_key; end if;
    end if;
  end loop;
  if jsonb_typeof(p_incoming->'seed_color') = 'string' then
    v_seed := p_incoming->>'seed_color';
    if v_seed !~ '^#[0-9A-Fa-f]{6}$' then
      if p_strict then raise exception 'seed_color must be #RRGGBB, not %', v_seed; end if;
    else
      v_out := v_out || jsonb_build_object('seed_color', upper(v_seed));
    end if;
  elsif p_incoming ? 'seed_color' and jsonb_typeof(p_incoming->'seed_color') <> 'null' and p_strict then
    raise exception 'seed_color must be #RRGGBB';
  end if;
  v_palette := p_incoming->'office_palette';
  if jsonb_typeof(v_palette) = 'array' then
    if jsonb_array_length(v_palette) between 1 and 8
       and not exists (select 1 from jsonb_array_elements(v_palette) c
                        where jsonb_typeof(c) <> 'string' or (c #>> '{}') !~ '^#[0-9A-Fa-f]{6}$') then
      v_out := v_out || jsonb_build_object('office_palette',
        (select jsonb_agg(upper(c #>> '{}')) from jsonb_array_elements(v_palette) c));
    elsif p_strict then
      raise exception 'office_palette is one to eight #RRGGBB colours';
    end if;
  elsif p_incoming ? 'office_palette' and jsonb_typeof(v_palette) <> 'null' and p_strict then
    raise exception 'office_palette is one to eight #RRGGBB colours';
  end if;
  if jsonb_typeof(p_incoming->'seat_palette') = 'string' then
    v_seat := p_incoming->>'seat_palette';
    if v_seat not in ('default') then
      if p_strict then raise exception 'seat_palette % is not a curated set', v_seat; end if;
    else
      v_out := v_out || jsonb_build_object('seat_palette', v_seat);
    end if;
  elsif p_incoming ? 'seat_palette' and jsonb_typeof(p_incoming->'seat_palette') <> 'null' and p_strict then
    raise exception 'seat_palette is a curated set''s key';
  end if;
  -- 0397: the pattern the space's colour is drawn in where it is told
  -- apart from the others (its card on Me, its chip, the entry).
  if jsonb_typeof(p_incoming->'pattern') = 'string' then
    if p_incoming->>'pattern' not in ('solid', 'stripes', 'dots', 'grid', 'waves') then
      if p_strict then raise exception 'pattern % is not a curated pattern', p_incoming->>'pattern'; end if;
    else
      v_out := v_out || jsonb_build_object('pattern', p_incoming->>'pattern');
    end if;
  elsif p_incoming ? 'pattern' and jsonb_typeof(p_incoming->'pattern') <> 'null' and p_strict then
    raise exception 'pattern is a curated pattern''s key';
  end if;
  -- 0378: the workspace symbol — one or two characters on a curated colour.
  -- Strict only: an import or a template never carries one (the pair is
  -- unique across workspaces, so a copy would collide), lenient drops it.
  if p_strict and (p_incoming ? 'symbol_text' or p_incoming ? 'symbol_color') then
    if jsonb_typeof(p_incoming->'symbol_text') = 'string'
       and jsonb_typeof(p_incoming->'symbol_color') = 'string' then
      if upper(p_incoming->>'symbol_text') !~ '^[[:alnum:]]{1,2}$' then
        raise exception 'symbol_text is one or two letters or digits';
      end if;
      if upper(p_incoming->>'symbol_color') not in (
        '#C2410C','#B45309','#4D7C0F','#15803D','#0F766E','#0369A1',
        '#1D4ED8','#6D28D9','#A21CAF','#BE185D','#B91C1C','#475569') then
        raise exception 'symbol_color is not one of the curated colours';
      end if;
      v_out := v_out || jsonb_build_object(
        'symbol_text', upper(p_incoming->>'symbol_text'),
        'symbol_color', upper(p_incoming->>'symbol_color'));
    elsif jsonb_typeof(p_incoming->'symbol_text') <> 'null'
       or jsonb_typeof(p_incoming->'symbol_color') <> 'null' then
      raise exception 'a symbol is its letters and its colour together';
    end if;
  end if;
  return v_out;
end $fn$;

revoke execute on function public.branding_clean(jsonb, boolean) from public, anon;
grant  execute on function public.branding_clean(jsonb, boolean) to authenticated;

select public.set_deskilo_schema_version(397);
