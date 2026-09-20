-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0220 (#1295) — invoice numbering travels as FORMAT, never as state.
--
-- Numbering is business configuration: a French template that carries
-- tariffs, hours and features while leaving the invoice series on a
-- product default has not configured the space. But numbering is not
-- ordinary configuration either — applying a source series to a target
-- that has already issued must never re-use a number.
--
-- So the row is split where it already splits:
--
--   format, and it travels : prefix suffix date_part digits reset gapless
--   state, and it NEVER does: period_key next_value
--
-- The state does not leave the source at all. `export_workspace_configuration`
-- simply never emits it, which is stronger than omitting it on the way
-- in: there is no payload anywhere that could carry somebody's counter.
--
-- Rows appear lazily — `next_document_number` creates a journal's row on
-- first use from `number_sequence_defaults` — so a target that has never
-- issued an invoice has NO invoice row, and the merge inserts the format
-- rather than updating it. A target that has issued keeps its counter
-- exactly and takes only the format.
--
-- Deleting is not a mode here. Even a mirror deployment leaves these rows
-- in place: the row carries the TARGET's counter, and removing it would
-- destroy the continuity of numbers that workspace has already issued.

-- 1. The exporter emits the format columns, and only those.
do $exporter$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'export_workspace_configuration'
   limit 1;
  if position($$      'workspace_documents', coalesce((select jsonb_agg($$ in v_def) = 0 then
    raise exception '0220: the exporter anchor did not match';
  end if;
  v_def := replace(v_def,
    $$      'workspace_documents', coalesce((select jsonb_agg($$,
    $$      'number_sequences', coalesce((select jsonb_agg(jsonb_build_object(
          'journal', q.journal, 'prefix', q.prefix, 'suffix', q.suffix,
          'date_part', q.date_part, 'digits', q.digits, 'reset', q.reset,
          'gapless', q.gapless)
          order by q.journal) from public.number_sequences q where q.workspace_id = p_workspace_id), '[]'::jsonb),
      'workspace_documents', coalesce((select jsonb_agg($$);
  execute v_def;
end
$exporter$;

-- 2. A nineteenth entity: keyed by journal, in the documents group.
do $entities$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deployable_entities' limit 1;
  if position($$    jsonb_build_object('key', 'features',$$ in v_def) = 0 then
    raise exception '0220: the entities anchor did not match';
  end if;
  v_def := replace(v_def,
    $$    jsonb_build_object('key', 'features',$$,
    $$    jsonb_build_object('key', 'number_sequences', 'kind', 'configuration', 'requires', '[]'::jsonb,
      'merge_policy', 'keyed_update', 'group', 'documents_operations',
      'workspace_keys', '[]'::jsonb, 'tables', '["number_sequences"]'::jsonb),
    jsonb_build_object('key', 'features',$$);
  execute v_def;
  if (select count(*) from jsonb_array_elements(public.deployable_entities()) e
       where e->>'key' = 'number_sequences') <> 1 then
    raise exception '0220: the entity did not land';
  end if;
end
$entities$;

-- 3. The writer. Format in, counter untouched, and the two refusals that
--    #1320 already owns rather than a second copy of its rules.
do $writer$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_workspace_configuration'
   limit 1;
  if position('declare v_ws jsonb; v_t jsonb; v_row jsonb; v_id uuid;' in v_def) = 0 then
    raise exception '0220: the declare anchor did not match';
  end if;
  v_def := replace(v_def,
    'declare v_ws jsonb; v_t jsonb; v_row jsonb; v_id uuid;',
    'declare v_ws jsonb; v_t jsonb; v_row jsonb; v_id uuid; v_seq public.number_sequences;');

  if position('  return public.export_workspace_configuration(p_workspace_id);' in v_def) = 0 then
    raise exception '0220: the return anchor did not match';
  end if;
  v_def := replace(v_def,
    '  return public.export_workspace_configuration(p_workspace_id);',
$$  if v_t ? 'number_sequences' then
    for v_row in select value from jsonb_array_elements(v_t->'number_sequences') loop
      -- A pair that restarts more often than it prints its date would
      -- re-issue numbers in the target (#1320). Refused, never applied.
      if not public.number_sequence_pair_valid(v_row->>'date_part', v_row->>'reset') then
        raise exception 'number series %: a series cannot restart more often than it prints its date', v_row->>'journal';
      end if;
      select * into v_seq from public.number_sequences
       where workspace_id = p_workspace_id and journal = v_row->>'journal';
      if v_seq.journal is null then
        -- Never issued here: the format lands whole, the counter starts.
        insert into public.number_sequences (workspace_id, journal, prefix, suffix, date_part, digits, reset, gapless)
        values (p_workspace_id, v_row->>'journal', coalesce(v_row->>'prefix', ''), coalesce(v_row->>'suffix', ''),
                coalesce(v_row->>'date_part', 'year'), coalesce((v_row->>'digits')::int, 4),
                coalesce(v_row->>'reset', 'yearly'), coalesce((v_row->>'gapless')::boolean, true));
      else
        -- Already issued: taking the date away could repeat a number.
        if v_seq.next_value > 1
           and public.number_sequence_date_rank(coalesce(v_row->>'date_part', v_seq.date_part)) < public.number_sequence_date_rank(v_seq.date_part)
           and coalesce(v_row->>'prefix', v_seq.prefix) = v_seq.prefix
           and coalesce(v_row->>'suffix', v_seq.suffix) = v_seq.suffix then
          raise exception 'number series %: removing the date from a series that already issued numbers could repeat one', v_row->>'journal';
        end if;
        -- Format only. period_key and next_value are the target's own.
        update public.number_sequences set
          prefix = coalesce(v_row->>'prefix', prefix), suffix = coalesce(v_row->>'suffix', suffix),
          date_part = coalesce(v_row->>'date_part', date_part), digits = coalesce((v_row->>'digits')::int, digits),
          reset = coalesce(v_row->>'reset', reset), gapless = coalesce((v_row->>'gapless')::boolean, gapless)
         where workspace_id = p_workspace_id and journal = v_row->>'journal';
      end if;
    end loop;
  end if;

  return public.export_workspace_configuration(p_workspace_id);$$);
  execute v_def;
end
$writer$;
