-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0768 (#3852) -- the paper a business's documents are printed on.
--  * A country's `document_paper` row of the reference store names the usual
--    paper of its documents (`paper`, absent: A4) and the papers they may use
--    (`papers`, absent: A4 and Letter); a country with no row prints on A4
--    and may choose Letter. The United States and Canada use Letter;
--    Switzerland's invoices end on a payment part printed on A4, so it allows
--    A4 only.
--  * `workspaces.paper` is the business's choice; null follows its
--    country. A paper outside the country's set is refused in words, by
--    every door that writes the row.
--  * `invoices.paper` is the paper of an invoice, set at issue and never
--    changed after. An invoice issued before 0768 has none, and is printed
--    on A4.
-- Wire words: 'A4' and 'Letter'.

-- ── 1. the shape of a document_paper row ──────────────────────────────
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
  select pg_get_functiondef('public.tax_reference_valid(text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    when 'country' then$a$,
    $a$    when 'document_paper' then
      -- #3852: the usual paper of a country's documents, and the papers they
      -- may use: known papers, each once, holding the usual one.
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['paper', 'papers'])) then return false; end if;
      if p_value ? 'paper'
         and (jsonb_typeof(p_value -> 'paper') is distinct from 'string'
              or (p_value ->> 'paper') <> all (array['A4', 'Letter'])) then
        return false;
      end if;
      return not p_value ? 'papers'
        or (jsonb_typeof(p_value -> 'papers') = 'array'
            and jsonb_array_length(p_value -> 'papers') > 0
            and not exists (select 1 from jsonb_array_elements(p_value -> 'papers') e
                             where jsonb_typeof(e) is distinct from 'string'
                                or (e #>> '{}') <> all (array['A4', 'Letter']))
            and (select count(distinct e) = count(*) from jsonb_array_elements_text(p_value -> 'papers') e)
            and (p_value -> 'papers') ? coalesce(p_value ->> 'paper', 'A4'));
    when 'country' then$a$);
  if v_def is null or position($a$when 'document_paper' then$a$ in v_def) = 0 then
    raise exception '0768: tax_reference_valid anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the rows ───────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('document_paper', 'CA', 'document', '1900-01-01', '{"paper":"Letter"}'::jsonb, 'the papers of a country''s documents (#3852): the usual paper (absent: A4) and the papers they may use (absent: A4 and Letter). Letter is the usual office paper in Canada.', false),
('document_paper', 'CH', 'document', '1900-01-01', '{"papers":["A4"]}'::jsonb, 'the papers of a country''s documents (#3852): the usual paper (absent: A4) and the papers they may use (absent: A4 and Letter). A Swiss invoice ends on its QR-bill payment part, printed on A4 (Swiss Implementation Guidelines for the QR-bill).', false),
('document_paper', 'US', 'document', '1900-01-01', '{"paper":"Letter"}'::jsonb, 'the papers of a country''s documents (#3852): the usual paper (absent: A4) and the papers they may use (absent: A4 and Letter). Letter is the usual office paper in the United States.', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

-- ── 3. the papers of a country ────────────────────────────────────────
-- The usual paper of [p_country] on [p_on], and the papers it allows:
-- {"paper": "A4", "papers": ["A4", "Letter"]} when its row says nothing.
create or replace function public.country_papers(p_country text, p_on date)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
           'paper', coalesce(v.value ->> 'paper', 'A4'),
           'papers', coalesce(v.value -> 'papers', '["A4", "Letter"]'::jsonb))
    from (select (select t.value
                    from public.tax_reference t
                   where t.domain = 'document_paper' and t.key = 'document'
                     and t.country = upper(btrim(coalesce(p_country, '')))
                     and t.valid_from <= p_on and (t.valid_to is null or t.valid_to > p_on)
                   order by t.valid_from desc
                   limit 1) as value) v;
$fn$;

revoke execute on function public.country_papers(text, date) from public, anon;
grant execute on function public.country_papers(text, date) to authenticated;

-- ── 4. the business's paper ───────────────────────────────────────────
alter table public.workspaces
  add column if not exists paper text;

alter table public.workspaces
  drop constraint if exists workspaces_paper_check,
  add constraint workspaces_paper_check check (paper is null or paper in ('A4', 'Letter'));

comment on column public.workspaces.paper is
  '#3852 -- the paper the business''s documents are printed on: ''A4'' or ''Letter''; null follows its country.';

-- A paper the business's country does not use is refused, whichever door
-- writes it, and so is a country that does not use the paper chosen.
create or replace function public.workspaces_paper_in_country()
returns trigger
language plpgsql set search_path = public as $fn$
declare
  v_papers jsonb;
begin
  if new.paper is null then
    return new;
  end if;
  v_papers := public.country_papers(new.country_code,
    (now() at time zone coalesce(nullif(new.timezone, ''), 'UTC'))::date) -> 'papers';
  if not v_papers ? new.paper then
    raise exception 'documents of this country are not printed on %', new.paper
      using errcode = '22023',
            detail = (select string_agg(p, ', ') from jsonb_array_elements_text(v_papers) p);
  end if;
  return new;
end;
$fn$;

revoke execute on function public.workspaces_paper_in_country() from public, anon, authenticated;

drop trigger if exists workspaces_paper_in_country on public.workspaces;
create trigger workspaces_paper_in_country
  before insert or update of paper, country_code on public.workspaces
  for each row execute function public.workspaces_paper_in_country();

-- A delegated administrator who changes the settings changes the paper with
-- them (the guard of the owner's columns, 0361).
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.workspaces_delegated_columns()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'address', 'whatsapp_group', 'desk_opacity', 'document_language_confirmed'];$a$,
    $a$'address', 'whatsapp_group', 'desk_opacity', 'document_language_confirmed', 'paper'];$a$);
  if v_def is null or position($a$'document_language_confirmed', 'paper'];$a$ in v_def) = 0 then
    raise exception '0768: workspaces_delegated_columns anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

-- The configuration transfer (the setup page's file, a template) carries the
-- paper. One the target's country does not allow leaves the target's own:
-- the country is the target's, not the file's.
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'desk_opacity', coalesce(w.desk_opacity, 100),$a$,
    $a$'desk_opacity', coalesce(w.desk_opacity, 100),
      'paper', w.paper,$a$);
  if v_def is null or position($a$'paper', w.paper,$a$ in v_def) = 0 then
    raise exception '0768: export_workspace_configuration anchor missing';
  end if;
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_workspace_configuration'
     and pg_get_function_identity_arguments(p.oid) = 'p_workspace_id uuid, p_configuration jsonb, p_mode text';
  v_def := pg_temp.anchor_replace(v_def,
    $a$desk_opacity = case when v_ws ? 'desk_opacity' then (v_ws->>'desk_opacity')::smallint else w.desk_opacity end,$a$,
    $a$desk_opacity = case when v_ws ? 'desk_opacity' then (v_ws->>'desk_opacity')::smallint else w.desk_opacity end,
    -- #3852 -- '' follows the country; a paper the country does not allow
    -- leaves the target's own.
    paper = case
      when not v_ws ? 'paper' then w.paper
      when nullif(btrim(v_ws->>'paper'), '') is null then null
      when (public.country_papers(w.country_code, current_date) -> 'papers') ? btrim(v_ws->>'paper')
        then btrim(v_ws->>'paper')
      else w.paper
    end,$a$);
  if v_def is null or position($a$#3852 -- '' follows the country$a$ in v_def) = 0 then
    raise exception '0768: import_workspace_configuration anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- The settings' one Save (0241) carries the paper: '' follows the country.
create or replace function public.save_workspace_settings(
  p_workspace_id uuid,
  p_expected_modified timestamptz,
  p_settings jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row public.workspaces;
  v_templates jsonb;
  v_same boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if jsonb_typeof(p_settings) is distinct from 'object' then
    raise exception 'workspace settings are an object';
  end if;
  if p_settings ? 'invitation_templates' then
    select coalesce(jsonb_object_agg(e.key, btrim(e.value)), '{}'::jsonb)
      into v_templates
      from jsonb_each_text(coalesce(p_settings->'invitation_templates', '{}'::jsonb)) e
     where btrim(e.value) <> '';
  end if;

  select * into v_row from public.workspaces where id = p_workspace_id for update;
  if v_row.id is null then
    raise exception 'only the owner and co-owners change the workspace settings';
  end if;

  if p_expected_modified is not null
     and v_row.modified_datetime is distinct from p_expected_modified then
    v_same :=
          v_row.country_code = coalesce(upper(p_settings->>'country_code'), v_row.country_code)
      and v_row.currency_code = coalesce(upper(p_settings->>'currency_code'), v_row.currency_code)
      and v_row.timezone = coalesce(p_settings->>'timezone', v_row.timezone)
      and coalesce(v_row.whatsapp_group, '') = coalesce(btrim(p_settings->>'whatsapp_group'), v_row.whatsapp_group, '')
      and coalesce(v_row.address, '') = coalesce(btrim(p_settings->>'address'), v_row.address, '')
      and coalesce(v_row.default_locale, '') = coalesce(btrim(p_settings->>'default_locale'), v_row.default_locale, '')
      and v_row.desk_opacity = coalesce((p_settings->>'desk_opacity')::int, v_row.desk_opacity)
      and (not p_settings ? 'paper'
           or coalesce(v_row.paper, '') = coalesce(btrim(p_settings->>'paper'), ''))
      and (v_templates is null or coalesce(v_row.invitation_templates, '{}'::jsonb) = v_templates)
      and (not p_settings ? 'invitation_templates' or coalesce(v_row.invitation_template, '') = '')
      and (not p_settings ? 'new_member_defaults'
           or coalesce(v_row.billing_rules, '{}'::jsonb)->'new_member_defaults' = p_settings->'new_member_defaults');
    if v_same then
      return jsonb_build_object('status', 'unchanged', 'workspace', to_jsonb(v_row));
    end if;
    raise exception using
      errcode = 'DK409',
      message = 'the workspace settings changed since they were opened';
  end if;

  update public.workspaces set
    country_code = coalesce(upper(p_settings->>'country_code'), country_code),
    currency_code = coalesce(upper(p_settings->>'currency_code'), currency_code),
    timezone = coalesce(p_settings->>'timezone', timezone),
    whatsapp_group = coalesce(btrim(p_settings->>'whatsapp_group'), whatsapp_group),
    address = coalesce(btrim(p_settings->>'address'), address),
    default_locale = coalesce(btrim(p_settings->>'default_locale'), default_locale),
    desk_opacity = coalesce((p_settings->>'desk_opacity')::int, desk_opacity),
    -- #3852 -- absent keeps the paper; '' follows the country.
    paper = case when p_settings ? 'paper' then nullif(btrim(p_settings->>'paper'), '') else paper end,
    invitation_templates = coalesce(v_templates, invitation_templates),
    -- #486 — the per-language templates replace the legacy single one.
    invitation_template = case when v_templates is null then invitation_template else '' end
   where id = p_workspace_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'only the owner and co-owners change the workspace settings';
  end if;

  if p_settings ? 'new_member_defaults' then
    perform public.set_billing_rule(p_workspace_id, 'new_member_defaults',
      p_settings->'new_member_defaults');
    select * into v_row from public.workspaces where id = p_workspace_id;
  end if;

  return jsonb_build_object('status', 'saved', 'workspace', to_jsonb(v_row));
end $$;

revoke execute on function public.save_workspace_settings(uuid, timestamptz, jsonb) from public, anon;
grant execute on function public.save_workspace_settings(uuid, timestamptz, jsonb) to authenticated;

-- ── 5. the paper of an invoice ────────────────────────────────────────
alter table public.invoices
  add column if not exists paper text;

alter table public.invoices
  drop constraint if exists invoices_paper_check,
  add constraint invoices_paper_check check (paper is null or paper in ('A4', 'Letter'));

comment on column public.invoices.paper is
  '#3852 -- the paper the invoice is printed on, set at issue (null: issued before 0768, printed on A4).';

-- The country an invoice of [p_workspace_id] is issued from, whose papers it
-- is printed on: its seller's, as the legal snapshot names it, else the
-- business's. One place, so an issuer of its own replaces it here.
create or replace function public.invoice_issuer_country(p_workspace_id uuid, p_legal_snapshot jsonb)
returns text
language sql stable security definer set search_path = public as $fn$
  select upper(coalesce(nullif(p_legal_snapshot ->> 'seller_country', ''), w.country_code))
    from public.workspaces w where w.id = p_workspace_id;
$fn$;

revoke execute on function public.invoice_issuer_country(uuid, jsonb) from public, anon, authenticated;

-- Named after `invoice_legal_language_freeze` so it runs once the seller's
-- country is in the snapshot: BEFORE triggers fire in name order. The
-- business's paper when its country allows it, else the country's usual one,
-- as on the invoice's own day of issue. It overwrites whatever the insert
-- carried.
create or replace function public.invoice_legal_paper_freeze()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_chosen text;
  v_facts jsonb;
begin
  select w.paper,
         public.country_papers(
           public.invoice_issuer_country(new.workspace_id, new.legal_snapshot),
           (coalesce(new.issued_at, now()) at time zone w.timezone)::date)
    into v_chosen, v_facts
    from public.workspaces w where w.id = new.workspace_id;
  new.paper := case
    when v_chosen is not null and (v_facts -> 'papers') ? v_chosen then v_chosen
    when (v_facts -> 'papers') ? (v_facts ->> 'paper') then v_facts ->> 'paper'
    else v_facts -> 'papers' ->> 0
  end;
  return new;
end;
$fn$;

revoke execute on function public.invoice_legal_paper_freeze() from public, anon, authenticated;

drop trigger if exists invoice_legal_paper_freeze on public.invoices;
create trigger invoice_legal_paper_freeze
  before insert on public.invoices
  for each row execute function public.invoice_legal_paper_freeze();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(768);
