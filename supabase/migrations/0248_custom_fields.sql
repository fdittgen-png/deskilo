-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0248 (#1288 S1) — questions a workspace asks, and the answers.
--
-- An owner, or a template, defines additional questions — committee
-- role, joining date, emergency contact. This slice is the schema, the
-- row-level rules and the server-side validation; the form section
-- (S2), the privacy wiring (S3), the editor (S4) and the template entity
-- (S5) follow.
--
-- **Values are keyed to `members.id`, never to `profiles.id`.** A profile
-- is global: it has no `workspace_id`, so a custom value stored there
-- would leak one workspace's question into every other workspace the
-- person belongs to. Keying on the membership makes the isolation a
-- property of the schema rather than of a policy somebody has to write
-- correctly every time.
--
-- **Neither values nor definitions take a client write.** Rows arrive
-- through definers that validate: `set_workspace_field` is the owner's
-- and checks the definition itself, `set_member_field_values` checks the
-- answers against it. A grant row never proves access (#1120), and an
-- answer row never proves it was allowed to be written.
--
-- **Validation is declarative and curated.** Length, range, date bounds
-- and a named validator from a fixed list — no free-form regex and no
-- expressions, because a definition travels with a template and a
-- template must not be able to run something.

create table if not exists public.workspace_field_definitions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  key text not null check (key ~ '^[a-z][a-z0-9_]{1,40}$'),
  type text not null check (type in ('text', 'long_text', 'integer', 'decimal',
                                    'date', 'boolean', 'single_choice',
                                    'multi_choice')),
  required boolean not null default false,
  personal_data boolean not null default true,
  visibility text not null default 'self'
    check (visibility in ('self', 'managers', 'members')),
  contexts text[] not null default array['profile']::text[],
  group_key text not null default 'general',
  sort_order int not null default 0,
  validation jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('workspace_field_definitions');
create unique index if not exists workspace_field_definitions_key
  on public.workspace_field_definitions (workspace_id, key);

create table if not exists public.workspace_field_labels (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  definition_id uuid not null
    references public.workspace_field_definitions(id) on delete cascade,
  locale text not null check (locale in ('en', 'fr', 'de', 'es', 'it')),
  label text not null check (btrim(label) <> ''),
  help_text text not null default ''
);
select public.ensure_system_columns('workspace_field_labels');
create unique index if not exists workspace_field_labels_locale
  on public.workspace_field_labels (definition_id, locale);

create table if not exists public.workspace_field_options (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  definition_id uuid not null
    references public.workspace_field_definitions(id) on delete cascade,
  key text not null check (key ~ '^[a-z0-9][a-z0-9_]{0,40}$'),
  sort_order int not null default 0,
  active boolean not null default true
);
select public.ensure_system_columns('workspace_field_options');
create unique index if not exists workspace_field_options_key
  on public.workspace_field_options (definition_id, key);

create table if not exists public.workspace_field_option_labels (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  option_id uuid not null
    references public.workspace_field_options(id) on delete cascade,
  locale text not null check (locale in ('en', 'fr', 'de', 'es', 'it')),
  label text not null check (btrim(label) <> '')
);
select public.ensure_system_columns('workspace_field_option_labels');
create unique index if not exists workspace_field_option_labels_locale
  on public.workspace_field_option_labels (option_id, locale);

create table if not exists public.workspace_field_values (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  definition_id uuid not null
    references public.workspace_field_definitions(id) on delete cascade,
  text_value text,
  integer_value bigint,
  decimal_value numeric,
  date_value date,
  boolean_value boolean,
  created_at timestamptz not null default now(),
  -- At most one typed column carries the answer; which one is the
  -- definition's business and is checked in the writer, where the
  -- definition is in hand.
  constraint workspace_field_values_one_column check (
    (case when text_value is not null then 1 else 0 end)
    + (case when integer_value is not null then 1 else 0 end)
    + (case when decimal_value is not null then 1 else 0 end)
    + (case when date_value is not null then 1 else 0 end)
    + (case when boolean_value is not null then 1 else 0 end) <= 1)
);
select public.ensure_system_columns('workspace_field_values');
create unique index if not exists workspace_field_values_once
  on public.workspace_field_values (member_id, definition_id);
create index if not exists workspace_field_values_by_member
  on public.workspace_field_values (workspace_id, member_id);

create table if not exists public.workspace_field_value_options (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  value_id uuid not null
    references public.workspace_field_values(id) on delete cascade,
  option_id uuid not null
    references public.workspace_field_options(id) on delete cascade
);
select public.ensure_system_columns('workspace_field_value_options');
create unique index if not exists workspace_field_value_options_once
  on public.workspace_field_value_options (value_id, option_id);

-- ── who may read ─────────────────────────────────────────────────────
-- Definitions, labels and options are the workspace's configuration and
-- every member reads them; a form cannot render a question it cannot
-- see. Values are personal, so the policy asks the definition's own
-- visibility — self, whoever holds `viewPersonalData`, or every member.

alter table public.workspace_field_definitions enable row level security;
alter table public.workspace_field_labels enable row level security;
alter table public.workspace_field_options enable row level security;
alter table public.workspace_field_option_labels enable row level security;
alter table public.workspace_field_values enable row level security;
alter table public.workspace_field_value_options enable row level security;

drop policy if exists workspace_field_definitions_select
  on public.workspace_field_definitions;
create policy workspace_field_definitions_select
  on public.workspace_field_definitions
  for select to authenticated using (public.is_member_of(workspace_id));

drop policy if exists workspace_field_labels_select
  on public.workspace_field_labels;
create policy workspace_field_labels_select on public.workspace_field_labels
  for select to authenticated using (public.is_member_of(workspace_id));

drop policy if exists workspace_field_options_select
  on public.workspace_field_options;
create policy workspace_field_options_select on public.workspace_field_options
  for select to authenticated using (public.is_member_of(workspace_id));

drop policy if exists workspace_field_option_labels_select
  on public.workspace_field_option_labels;
create policy workspace_field_option_labels_select
  on public.workspace_field_option_labels
  for select to authenticated using (public.is_member_of(workspace_id));

-- `public.member_field_readable(member, definition)` is the one place
-- the visibility rule lives; both value tables ask it.
create or replace function public.member_field_readable(
  p_member_id uuid, p_definition_id uuid
) returns boolean
language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1
      from public.workspace_field_definitions d
      join public.members subject on subject.id = p_member_id
     where d.id = p_definition_id
       and d.workspace_id = subject.workspace_id
       and public.is_member_of(d.workspace_id)
       and (
         -- your own answer, always
         subject.user_id = auth.uid()
         -- or the definition says who else
         or (d.visibility = 'members')
         or (d.visibility = 'managers'
             and public.has_permission(d.workspace_id, 'viewPersonalData'))
       ));
$fn$;

revoke execute on function public.member_field_readable(uuid, uuid)
  from public, anon;
grant execute on function public.member_field_readable(uuid, uuid)
  to authenticated;

drop policy if exists workspace_field_values_select
  on public.workspace_field_values;
create policy workspace_field_values_select on public.workspace_field_values
  for select to authenticated
  using (public.member_field_readable(member_id, definition_id));

drop policy if exists workspace_field_value_options_select
  on public.workspace_field_value_options;
create policy workspace_field_value_options_select
  on public.workspace_field_value_options
  for select to authenticated using (exists (
    select 1 from public.workspace_field_values v
     where v.id = value_id
       and public.member_field_readable(v.member_id, v.definition_id)));

revoke all on table public.workspace_field_definitions from anon, authenticated;
revoke all on table public.workspace_field_labels from anon, authenticated;
revoke all on table public.workspace_field_options from anon, authenticated;
revoke all on table public.workspace_field_option_labels from anon, authenticated;
revoke all on table public.workspace_field_values from anon, authenticated;
revoke all on table public.workspace_field_value_options from anon, authenticated;
grant select on table public.workspace_field_definitions to authenticated;
grant select on table public.workspace_field_labels to authenticated;
grant select on table public.workspace_field_options to authenticated;
grant select on table public.workspace_field_option_labels to authenticated;
grant select on table public.workspace_field_values to authenticated;
grant select on table public.workspace_field_value_options to authenticated;

-- ── the curated vocabulary ───────────────────────────────────────────
-- A definition travels with a template, so nothing in it may be
-- executable. These are the only rules that exist, and the only named
-- validators; anything else is refused at definition time rather than
-- ignored at save time.

create or replace function public.field_validation_keys()
returns text[] language sql immutable set search_path = public as $fn$
  select array['min_length', 'max_length', 'min', 'max',
               'min_date', 'max_date', 'named']::text[];
$fn$;

create or replace function public.field_named_validators()
returns text[] language sql immutable set search_path = public as $fn$
  select array['email', 'phone', 'url']::text[];
$fn$;

create or replace function public.field_contexts()
returns text[] language sql immutable set search_path = public as $fn$
  select array['profile', 'managed_member', 'join_request']::text[];
$fn$;

revoke execute on function public.field_validation_keys() from public, anon;
revoke execute on function public.field_named_validators() from public, anon;
revoke execute on function public.field_contexts() from public, anon;
grant execute on function public.field_validation_keys() to authenticated;
grant execute on function public.field_named_validators() to authenticated;
grant execute on function public.field_contexts() to authenticated;

-- ── defining a question ──────────────────────────────────────────────
create or replace function public.set_workspace_field(
  p_workspace_id uuid,
  p_key text,
  p_type text,
  p_labels jsonb,
  p_required boolean default false,
  p_personal_data boolean default true,
  p_visibility text default 'self',
  p_contexts text[] default array['profile']::text[],
  p_group_key text default 'general',
  p_sort_order int default 0,
  p_validation jsonb default '{}'::jsonb,
  p_active boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_default_locale text;
  v_locale text;
  v_context text;
  v_rule text;
  v_existing text;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner defines the questions of a workspace';
  end if;
  if not public.feature_effective(p_workspace_id, 'customFields') then
    raise exception 'custom fields are off in this workspace';
  end if;
  if p_key !~ '^[a-z][a-z0-9_]{1,40}$' then
    raise exception 'a field key is lower-case letters, digits and underscores';
  end if;
  if p_type not in ('text', 'long_text', 'integer', 'decimal', 'date',
                    'boolean', 'single_choice', 'multi_choice') then
    raise exception 'unknown field type %', p_type;
  end if;
  if p_visibility not in ('self', 'managers', 'members') then
    raise exception 'unknown visibility %', p_visibility;
  end if;

  -- A key is a promise: values already point at it, so the answer type
  -- may not change underneath them (#1288 — a type change with values is
  -- a conflict, never a silent reinterpretation).
  select d.type into v_existing from public.workspace_field_definitions d
   where d.workspace_id = p_workspace_id and d.key = p_key;
  if v_existing is not null and v_existing <> p_type
     and exists (select 1 from public.workspace_field_values v
                   join public.workspace_field_definitions d on d.id = v.definition_id
                  where d.workspace_id = p_workspace_id and d.key = p_key) then
    raise exception 'the type of % cannot change while it has answers', p_key;
  end if;

  foreach v_context in array coalesce(p_contexts, '{}'::text[]) loop
    if not (v_context = any(public.field_contexts())) then
      raise exception 'unknown context %', v_context;
    end if;
  end loop;
  if coalesce(array_length(p_contexts, 1), 0) = 0 then
    raise exception 'a question with no context is asked nowhere';
  end if;

  for v_rule in select jsonb_object_keys(coalesce(p_validation, '{}'::jsonb)) loop
    if not (v_rule = any(public.field_validation_keys())) then
      raise exception 'unknown validation rule %', v_rule;
    end if;
  end loop;
  if p_validation ? 'named'
     and not (p_validation->>'named' = any(public.field_named_validators())) then
    raise exception 'unknown validator %', p_validation->>'named';
  end if;

  select w.default_locale into v_default_locale
    from public.workspaces w where w.id = p_workspace_id;
  -- A workspace that never chose one stores the empty string, not null.
  v_default_locale := coalesce(nullif(btrim(v_default_locale), ''), 'en');
  if not (coalesce(p_labels, '{}'::jsonb) ? v_default_locale) then
    raise exception 'the workspace reads % and the question has no label in it',
      v_default_locale;
  end if;
  for v_locale in select jsonb_object_keys(p_labels) loop
    if v_locale not in ('en', 'fr', 'de', 'es', 'it') then
      raise exception 'unsupported locale %', v_locale;
    end if;
    if jsonb_typeof(p_labels->v_locale) <> 'string'
       or btrim(p_labels->>v_locale) = '' then
      raise exception 'the label for % is empty', v_locale;
    end if;
  end loop;

  insert into public.workspace_field_definitions
    (workspace_id, key, type, required, personal_data, visibility, contexts,
     group_key, sort_order, validation, active)
  values (p_workspace_id, p_key, p_type, coalesce(p_required, false),
          coalesce(p_personal_data, true), p_visibility,
          p_contexts, coalesce(p_group_key, 'general'),
          coalesce(p_sort_order, 0), coalesce(p_validation, '{}'::jsonb),
          coalesce(p_active, true))
  on conflict (workspace_id, key) do update
    set type = excluded.type,
        required = excluded.required,
        personal_data = excluded.personal_data,
        visibility = excluded.visibility,
        contexts = excluded.contexts,
        group_key = excluded.group_key,
        sort_order = excluded.sort_order,
        validation = excluded.validation,
        active = excluded.active
  returning id into v_id;

  delete from public.workspace_field_labels where definition_id = v_id;
  insert into public.workspace_field_labels
    (workspace_id, definition_id, locale, label)
  select p_workspace_id, v_id, k, p_labels->>k
    from jsonb_object_keys(p_labels) k;

  return v_id;
end $fn$;

revoke execute on function public.set_workspace_field(
  uuid, text, text, jsonb, boolean, boolean, text, text[], text, int,
  jsonb, boolean) from public, anon;
grant execute on function public.set_workspace_field(
  uuid, text, text, jsonb, boolean, boolean, text, text[], text, int,
  jsonb, boolean) to authenticated;

-- ── answering ────────────────────────────────────────────────────────
-- `field_answer_problem` is the whole rule set in one place, so the
-- writer, a future preview and the template conflict check give the same
-- verdict. Null means the answer is acceptable.
create or replace function public.field_answer_problem(
  p_definition_id uuid, p_answer jsonb
) returns text
language plpgsql stable security definer set search_path = public as $fn$
declare
  d public.workspace_field_definitions;
  v jsonb := coalesce(p_answer, 'null'::jsonb);
  v_text text;
  v_num numeric;
  v_date date;
  v_rule jsonb;
  v_option text;
begin
  select * into d from public.workspace_field_definitions
   where id = p_definition_id;
  if not found then return 'no such question'; end if;
  v_rule := d.validation;

  if jsonb_typeof(v) = 'null' then
    return case when d.required then 'this question must be answered' end;
  end if;

  case d.type
    when 'text', 'long_text' then
      if jsonb_typeof(v) <> 'string' then return 'expected text'; end if;
      v_text := btrim(v #>> '{}');
      if d.required and v_text = '' then
        return 'this question must be answered';
      end if;
      if v_rule ? 'min_length'
         and length(v_text) < (v_rule->>'min_length')::int then
        return format('at least %s characters', v_rule->>'min_length');
      end if;
      if v_rule ? 'max_length'
         and length(v_text) > (v_rule->>'max_length')::int then
        return format('at most %s characters', v_rule->>'max_length');
      end if;
      if v_rule ? 'named' and v_text <> '' then
        if v_rule->>'named' = 'email'
           and v_text !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
          return 'not an e-mail address';
        end if;
        if v_rule->>'named' = 'phone' and v_text !~ '^[+0-9][0-9 ()./-]{4,}$' then
          return 'not a telephone number';
        end if;
        if v_rule->>'named' = 'url' and v_text !~ '^https?://[^[:space:]]+$' then
          return 'not a web address';
        end if;
      end if;
    when 'integer', 'decimal' then
      if jsonb_typeof(v) <> 'number' then return 'expected a number'; end if;
      v_num := (v #>> '{}')::numeric;
      if d.type = 'integer' and v_num <> trunc(v_num) then
        return 'expected a whole number';
      end if;
      if v_rule ? 'min' and v_num < (v_rule->>'min')::numeric then
        return format('at least %s', v_rule->>'min');
      end if;
      if v_rule ? 'max' and v_num > (v_rule->>'max')::numeric then
        return format('at most %s', v_rule->>'max');
      end if;
    when 'date' then
      if jsonb_typeof(v) <> 'string' then return 'expected a date'; end if;
      begin
        v_date := (v #>> '{}')::date;
      exception when others then return 'expected a date'; end;
      if v_rule ? 'min_date' and v_date < (v_rule->>'min_date')::date then
        return format('not before %s', v_rule->>'min_date');
      end if;
      if v_rule ? 'max_date' and v_date > (v_rule->>'max_date')::date then
        return format('not after %s', v_rule->>'max_date');
      end if;
    when 'boolean' then
      if jsonb_typeof(v) <> 'boolean' then return 'expected yes or no'; end if;
    when 'single_choice' then
      if jsonb_typeof(v) <> 'string' then return 'expected one choice'; end if;
      if not exists (select 1 from public.workspace_field_options o
                      where o.definition_id = d.id and o.active
                        and o.key = v #>> '{}') then
        return 'not one of the choices';
      end if;
    when 'multi_choice' then
      if jsonb_typeof(v) <> 'array' then return 'expected a list of choices'; end if;
      if d.required and jsonb_array_length(v) = 0 then
        return 'this question must be answered';
      end if;
      for v_option in select jsonb_array_elements_text(v) loop
        if not exists (select 1 from public.workspace_field_options o
                        where o.definition_id = d.id and o.active
                          and o.key = v_option) then
          return format('%s is not one of the choices', v_option);
        end if;
      end loop;
  end case;
  return null;
end $fn$;

revoke execute on function public.field_answer_problem(uuid, jsonb)
  from public, anon;
grant execute on function public.field_answer_problem(uuid, jsonb)
  to authenticated;

-- `set_member_field_values(member, context, answers)` — answers is
-- `{"<key>": <json>}`. Every key must be a definition ACTIVE in that
-- context, every answer must pass, and every required question of the
-- context must be present, so a partial save cannot leave a required
-- answer missing without saying so.
create or replace function public.set_member_field_values(
  p_member_id uuid, p_context text, p_answers jsonb
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_is_me boolean;
  v_key text;
  d public.workspace_field_definitions;
  v_answer jsonb;
  v_problem text;
  v_value_id uuid;
begin
  select m.workspace_id, (m.user_id = auth.uid()) into v_ws, v_is_me
    from public.members m where m.id = p_member_id;
  if v_ws is null then raise exception 'unknown member'; end if;
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.feature_effective(v_ws, 'customFields') then
    raise exception 'custom fields are off in this workspace';
  end if;
  if not (p_context = any(public.field_contexts())) then
    raise exception 'unknown context %', p_context;
  end if;
  -- Your own answers are yours; somebody else's need the permission that
  -- already governs reading and editing personal data.
  if not coalesce(v_is_me, false)
     and not public.has_permission(v_ws, 'viewPersonalData') then
    raise exception 'only the member, or whoever may see personal data';
  end if;

  for v_key in select jsonb_object_keys(coalesce(p_answers, '{}'::jsonb)) loop
    select * into d from public.workspace_field_definitions
     where workspace_id = v_ws and key = v_key and active
       and p_context = any(contexts);
    if not found then
      raise exception '% is not a question asked here', v_key;
    end if;
    v_answer := p_answers->v_key;
    v_problem := public.field_answer_problem(d.id, v_answer);
    if v_problem is not null then
      raise exception '%: %', v_key, v_problem;
    end if;

    insert into public.workspace_field_values
      (workspace_id, member_id, definition_id)
    values (v_ws, p_member_id, d.id)
    on conflict (member_id, definition_id) do update
      set text_value = null, integer_value = null, decimal_value = null,
          date_value = null, boolean_value = null
    returning id into v_value_id;

    update public.workspace_field_values set
      text_value = case when d.type in ('text', 'long_text', 'single_choice')
                        and jsonb_typeof(v_answer) = 'string'
                        then v_answer #>> '{}' end,
      integer_value = case when d.type = 'integer'
                           and jsonb_typeof(v_answer) = 'number'
                           then (v_answer #>> '{}')::bigint end,
      decimal_value = case when d.type = 'decimal'
                           and jsonb_typeof(v_answer) = 'number'
                           then (v_answer #>> '{}')::numeric end,
      date_value = case when d.type = 'date'
                        and jsonb_typeof(v_answer) = 'string'
                        then (v_answer #>> '{}')::date end,
      boolean_value = case when d.type = 'boolean'
                           and jsonb_typeof(v_answer) = 'boolean'
                           then (v_answer #>> '{}')::boolean end
     where id = v_value_id;

    delete from public.workspace_field_value_options where value_id = v_value_id;
    if d.type = 'multi_choice' and jsonb_typeof(v_answer) = 'array' then
      insert into public.workspace_field_value_options
        (workspace_id, value_id, option_id)
      select v_ws, v_value_id, o.id
        from public.workspace_field_options o
       where o.definition_id = d.id
         and o.key in (select jsonb_array_elements_text(v_answer));
    end if;
  end loop;

  -- Nothing required may be left unanswered once this member has been
  -- through the form: a save that silently skips a required question is
  -- how a form ends up with a rule nobody enforces.
  for d in select * from public.workspace_field_definitions
            where workspace_id = v_ws and active and required
              and p_context = any(contexts) loop
    if not exists (select 1 from public.workspace_field_values v
                    where v.member_id = p_member_id and v.definition_id = d.id
                      and (v.text_value is not null
                           or v.integer_value is not null
                           or v.decimal_value is not null
                           or v.date_value is not null
                           or v.boolean_value is not null
                           or exists (select 1
                                        from public.workspace_field_value_options o
                                       where o.value_id = v.id))) then
      raise exception '%: this question must be answered', d.key;
    end if;
  end loop;
end $fn$;

revoke execute on function public.set_member_field_values(uuid, text, jsonb)
  from public, anon;
grant execute on function public.set_member_field_values(uuid, text, jsonb)
  to authenticated;

-- ── the choices of a choice question ─────────────────────────────────
-- Options are replaced wholesale, which is the only shape that can
-- express "this one is gone". Removing one that answers point at is a
-- refusal, not a cascade: #1288 calls that a conflict, and a conflict is
-- something a person decides.
create or replace function public.set_workspace_field_options(
  p_definition_id uuid, p_options jsonb
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  d public.workspace_field_definitions;
  v_option jsonb;
  v_key text;
  v_locale text;
  v_id uuid;
  v_keys text[] := '{}';
begin
  select * into d from public.workspace_field_definitions
   where id = p_definition_id;
  if not found then raise exception 'no such question'; end if;
  if auth.uid() is null or not public.is_owner_of(d.workspace_id) then
    raise exception 'only an owner defines the questions of a workspace';
  end if;
  if d.type not in ('single_choice', 'multi_choice') then
    raise exception '% is not a question with choices', d.key;
  end if;

  for v_option in select jsonb_array_elements(coalesce(p_options, '[]'::jsonb)) loop
    v_key := v_option->>'key';
    if v_key is null or v_key !~ '^[a-z0-9][a-z0-9_]{0,40}$' then
      raise exception 'a choice key is lower-case letters, digits and underscores';
    end if;
    v_keys := v_keys || v_key;
  end loop;

  -- An option somebody has already chosen may not simply vanish.
  if exists (
    select 1 from public.workspace_field_options o
      join public.workspace_field_value_options vo on vo.option_id = o.id
     where o.definition_id = d.id and not (o.key = any(v_keys))) then
    raise exception 'a choice that has been made cannot be removed; '
      'deactivate it instead';
  end if;

  delete from public.workspace_field_options o
   where o.definition_id = d.id and not (o.key = any(v_keys));

  for v_option in select jsonb_array_elements(coalesce(p_options, '[]'::jsonb)) loop
    insert into public.workspace_field_options
      (workspace_id, definition_id, key, sort_order, active)
    values (d.workspace_id, d.id, v_option->>'key',
            coalesce((v_option->>'sort_order')::int, 0),
            coalesce((v_option->>'active')::boolean, true))
    on conflict (definition_id, key) do update
      set sort_order = excluded.sort_order, active = excluded.active
    returning id into v_id;

    delete from public.workspace_field_option_labels where option_id = v_id;
    for v_locale in
      select jsonb_object_keys(coalesce(v_option->'labels', '{}'::jsonb)) loop
      if v_locale not in ('en', 'fr', 'de', 'es', 'it') then
        raise exception 'unsupported locale %', v_locale;
      end if;
      insert into public.workspace_field_option_labels
        (workspace_id, option_id, locale, label)
      values (d.workspace_id, v_id, v_locale,
              v_option->'labels'->>v_locale);
    end loop;
  end loop;
end $fn$;

revoke execute on function public.set_workspace_field_options(uuid, jsonb)
  from public, anon;
grant execute on function public.set_workspace_field_options(uuid, jsonb)
  to authenticated;

-- ── the answers are the member's own data ────────────────────────────
-- `export_my_data` gains `custom_fields`: the question, in the languages
-- it was asked, and this member's answer. S3 adds erasure and the
-- retention matrix; the subject-access right does not wait for them.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    'exported_at', now(),$a$,
    $a$    'exported_at', now(),
    'custom_fields', (select coalesce(jsonb_agg(jsonb_build_object(
                          'key', d.key, 'type', d.type,
                          'labels', (select coalesce(jsonb_object_agg(l.locale, l.label), '{}'::jsonb)
                                       from public.workspace_field_labels l
                                      where l.definition_id = d.id),
                          'answer', coalesce(to_jsonb(v.text_value), to_jsonb(v.integer_value),
                                             to_jsonb(v.decimal_value), to_jsonb(v.date_value),
                                             to_jsonb(v.boolean_value), 'null'::jsonb),
                          'choices', (select coalesce(jsonb_agg(o.key), '[]'::jsonb)
                                        from public.workspace_field_value_options vo
                                        join public.workspace_field_options o on o.id = vo.option_id
                                       where vo.value_id = v.id))), '[]')
                        from public.workspace_field_values v
                        join public.workspace_field_definitions d on d.id = v.definition_id
                       where v.member_id = v_me.id),$a$);
  if v_patched is null then
    raise exception '0248: the export_my_data anchor did not match';
  end if;
  execute v_patched;
end
$migration$;

-- ── the flag: customFields, platform, off ────────────────────────────
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": null, "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false}
  }'::jsonb
$registry$;

revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ── the association builtin names the new flag explicitly ──────────
-- (`template_contract_test`: a builtin's feature_flags name every feature;
-- supabase/templates/association_fr.json was regenerated by
-- `dart run tool/build_builtin_templates.dart` and this is that file.)
insert into public.workspace_templates
  (key, name, description, sort_order, visibility, schema_version, template_version,
   tags, entities, configuration, floor_plan)
values (
  'association_fr',
  'Association de coworking (France)',
  'Pour une association de coworking en France : demi-journées de 7 h à 13 h et de 13 h à 19 h du lundi au vendredi, jours fériés de l''année et de la suivante, cotisations à 50 % et 100 %, un calendrier où se prennent les validations, les mots de l''association, et deux étages prêts à réserver.',
  1,
  'builtin',
  1,
  1,
  array['association', 'coworking', 'france'],
  array['identity', 'tariffs', 'floor_plan', 'booking_rules', 'closure_days', 'lexicon', 'features'],
  $cfg$
{
  "workspace": {
    "default_locale": "fr",
    "vat_regime": "not_subject",
    "booking_rules": {
      "granularity": "half_day",
      "open_weekdays": [
        1,
        2,
        3,
        4,
        5
      ],
      "work_start_minutes": 420,
      "half_boundary_minutes": 780,
      "work_end_minutes": 1140,
      "max_series_days": 180,
      "advance_horizon_days": 90,
      "max_duration_minutes": 1440,
      "min_duration_minutes": 30
    },
    "subscription_levels": {
      "allow_custom": false,
      "extra_levels": [],
      "enabled_presets": [
        50,
        100
      ]
    },
    "feature_flags": {
      "accessorySupplements": false,
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
      "bookForOthers": true,
      "bookingGate": true,
      "bookingPolicies": true,
      "calendarHub": true,
      "calendarTab": true,
      "calendarValidations": true,
      "calendarViews": true,
      "carnets": false,
      "coOwner": false,
      "configurationTransfer": false,
      "customFields": false,
      "customRoles": false,
      "dataAccessLog": false,
      "dataExport": true,
      "deletionRequests": true,
      "demoMode": false,
      "deployments": false,
      "documents": true,
      "dunning": false,
      "einvoiceCustomerDelivery": false,
      "environmentPairs": false,
      "eventsTab": false,
      "expenseRepartition": false,
      "expenseRepartitionWizard": false,
      "financeFaces": true,
      "formHelpHints": true,
      "instanceWizard": false,
      "invoiceAddressWindow": false,
      "invoiceJourney": false,
      "invoicePdfTemplate": false,
      "invoiceSettlement": false,
      "invoicing": true,
      "invoicingWizard": false,
      "kioskMemberPhotos": false,
      "kioskMode": false,
      "letterStandard": false,
      "levelBooking": false,
      "managedProfileAccess": false,
      "managedProfiles": false,
      "memberDataExport": true,
      "memberEnvironments": false,
      "memberNotifications": true,
      "memberOrigin": false,
      "memberPage": false,
      "memberPaymentTerms": false,
      "memberReports": false,
      "membersDirectory": false,
      "messageGestures": true,
      "messagesHub": true,
      "moneyTab": true,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "priceNegotiations": false,
      "publicHolidays": false,
      "pushNotifications": true,
      "qrBadges": false,
      "regionalFormats": true,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleManagement": true,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "services": true,
      "settlementFold": false,
      "singleRoomLevelNames": true,
      "siteDocuments": false,
      "spaceQrCodes": true,
      "subscriptionInvoices": false,
      "supplyExpenses": false,
      "uiAnimations": true,
      "uniqueMonograms": true,
      "usageInvoices": false,
      "usageRecords": false,
      "usageReport": false,
      "validationChain": false,
      "validationScopes": false,
      "vatCounterparty": false,
      "vatDeclarations": false,
      "vatGroups": false,
      "vatManagement": false,
      "vatRateHistory": false,
      "vatReport": false,
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
      "workspaceStatus": false,
      "workspaceVocabulary": false
    },
    "lexicon": {
      "fr": {
        "spaceKindSeat": "Place",
        "spaceKindLevel": "Étage",
        "shellReserveButton": "Réservations"
      }
    }
  },
  "tables": {
    "fee_bands": [
      {
        "from_pct": 0,
        "to_pct": 50,
        "fee_cents": 5000,
        "overage_fee_cents": 0
      },
      {
        "from_pct": 50,
        "to_pct": 100,
        "fee_cents": 10000,
        "overage_fee_cents": 0
      }
    ]
  },
  "holidays": {
    "years": 2
  }
}
$cfg$::jsonb,
  $tpl$
[
  {
    "name": "Rez-de-chaussée",
    "sort_order": 0,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle principale",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 1",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "A1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "A2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 2",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "B1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "B2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "name": "Étage",
    "sort_order": 1,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle du haut",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 3",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "C1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "C2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 4",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "D1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "D2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  }
]
$tpl$::jsonb
)
on conflict (key) where owner_workspace_id is null do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order,
      schema_version = excluded.schema_version,
      template_version = public.workspace_templates.template_version + 1,
      tags = excluded.tags,
      entities = excluded.entities,
      configuration = excluded.configuration,
      floor_plan = excluded.floor_plan;

select public.set_deskilo_schema_version(248);
