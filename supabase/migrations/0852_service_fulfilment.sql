-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4178 (F4) -- service fulfilment: an ordered service followed as an engagement
-- of its own, ordered -> started -> done, or cancelled with a reason, with every
-- step kept. It sits BESIDE the quote, the invoice and the payments and changes
-- none of them: nothing here writes a receivable, a payment, a ledger entry, a
-- stock movement or an invoice. Access code: every function is guarded.
--
--   * `service_fulfilments`: the engagement. Its own identity (never the
--     catalogue item, a list position, an invoice or a movement), the financial
--     subject it is owed to (`members.id`, the billing customer of #4164), the
--     commercial source line it came from -- {kind, id, revision, line_id} -- the
--     frozen scope (what was ordered), its state and the revision of its history.
--     ONE aggregate engagement per canonical source line, ever
--     (`unique (workspace_id, source_kind, source_id, source_line_id)`).
--   * `service_fulfilment_transitions`: append-only. One row per step, a
--     monotonically increasing revision, the previous and new state, the
--     authenticated actor, the reason and the request identity (with the digest of
--     what was asked: the same request replays, a changed payload under it is
--     refused). The state and the appended row are one transaction.
--   * `service_fulfilment_invoice_links`: the explicit correspondence between a
--     direct engagement's preserved commitment and the invoice line that later
--     billed it. A quote's own conversion already is that correspondence (its
--     line identities travel unchanged, 0828); an invoice with no earlier source
--     is its own source.
--
-- The source producers: an accepted quote revision's line, an issued standalone
-- invoice line, or a direct engagement whose frozen scope is its own commitment.
-- A mutable draft is never a source. Opening an engagement from the invoice that
-- billed a quote line returns the quote's engagement: the canonical source is
-- resolved first, then the engagement is found or made, once.
--
-- Not here: timesheets, scheduling, session entitlements, partial or progress
-- invoicing, deposits, stock; and no customer-facing read (a customer reads
-- nothing of this: the engagement is the issuer's record).

-- ── 1. the tables ───────────────────────────────────────────────────────
create table public.service_fulfilments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  subject_member_id uuid not null,
  source_kind text not null check (source_kind in ('quote', 'invoice', 'direct')),
  source_id uuid not null,
  source_revision integer check (source_revision is null or source_revision >= 1),
  source_line_id uuid not null,
  -- the catalogue references are not foreign keys: renaming, repricing, deleting or
  -- deactivating an item or a variant never rewrites a frozen engagement
  item_id uuid,
  variant_id uuid,
  scope jsonb not null check (jsonb_typeof(scope) = 'object'),
  state text not null default 'ordered'
    check (state in ('ordered', 'started', 'done', 'cancelled')),
  revision integer not null default 1 check (revision >= 1),
  foreign key (workspace_id, subject_member_id)
    references public.members (workspace_id, id) on delete cascade,
  unique (workspace_id, id),
  unique (workspace_id, source_kind, source_id, source_line_id),
  -- a direct engagement is its own commitment
  check (source_kind <> 'direct' or source_id = id),
  check (variant_id is null or item_id is not null)
);
select public.ensure_system_columns('service_fulfilments');
create index service_fulfilments_workspace_idx
  on public.service_fulfilments (workspace_id, state);
create index service_fulfilments_subject_idx
  on public.service_fulfilments (workspace_id, subject_member_id);

create table public.service_fulfilment_transitions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  fulfilment_id uuid not null,
  revision integer not null check (revision >= 1),
  from_state text check (from_state in ('ordered', 'started', 'done', 'cancelled')),
  to_state text not null check (to_state in ('ordered', 'started', 'done', 'cancelled')),
  actor_member_id uuid not null,
  reason text not null default '' check (char_length(reason) <= 500),
  request_id uuid not null,
  request_digest text not null,
  occurred_at timestamptz not null default now(),
  foreign key (workspace_id, fulfilment_id)
    references public.service_fulfilments (workspace_id, id) on delete cascade,
  foreign key (workspace_id, actor_member_id)
    references public.members (workspace_id, id) on delete cascade,
  -- two steps never share a revision, and one request is one step
  unique (fulfilment_id, revision),
  unique (workspace_id, request_id),
  check ((revision = 1) = (from_state is null)),
  check (to_state <> 'cancelled' or btrim(reason) <> '')
);
select public.ensure_system_columns('service_fulfilment_transitions');

create table public.service_fulfilment_invoice_links (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  fulfilment_id uuid not null,
  invoice_id uuid not null references public.invoices (id) on delete restrict,
  line_id uuid not null,
  linked_by_member_id uuid not null,
  foreign key (workspace_id, fulfilment_id)
    references public.service_fulfilments (workspace_id, id) on delete cascade,
  foreign key (workspace_id, linked_by_member_id)
    references public.members (workspace_id, id) on delete cascade,
  -- an invoice line answers for at most one engagement
  unique (workspace_id, invoice_id, line_id)
);
select public.ensure_system_columns('service_fulfilment_invoice_links');

-- ── 2. access: issuers and finance readers read; nobody writes directly ──
create or replace function public.service_fulfilments_readable(p_workspace uuid) returns boolean
language sql stable security definer set search_path = public as $fn$
  select auth.uid() is not null and not public.mcp_is_delegated()
     and public.feature_effective(p_workspace, 'serviceFulfilment') is true
     and (public.has_permission(p_workspace, 'issueInvoices')
          or public.has_permission(p_workspace, 'viewFinances'));
$fn$;
revoke execute on function public.service_fulfilments_readable(uuid) from public, anon;
grant execute on function public.service_fulfilments_readable(uuid) to authenticated;

alter table public.service_fulfilments enable row level security;
revoke all on public.service_fulfilments from public, anon, authenticated;
grant select on public.service_fulfilments to authenticated;
create policy service_fulfilments_read on public.service_fulfilments for select to authenticated
  using (public.service_fulfilments_readable(workspace_id));
create policy mcp_delegated_deny on public.service_fulfilments as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.service_fulfilment_transitions enable row level security;
revoke all on public.service_fulfilment_transitions from public, anon, authenticated;
grant select on public.service_fulfilment_transitions to authenticated;
create policy service_fulfilment_transitions_read on public.service_fulfilment_transitions
  for select to authenticated using (public.service_fulfilments_readable(workspace_id));
create policy mcp_delegated_deny on public.service_fulfilment_transitions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.service_fulfilment_invoice_links enable row level security;
revoke all on public.service_fulfilment_invoice_links from public, anon, authenticated;
grant select on public.service_fulfilment_invoice_links to authenticated;
create policy service_fulfilment_invoice_links_read on public.service_fulfilment_invoice_links
  for select to authenticated using (public.service_fulfilments_readable(workspace_id));
create policy mcp_delegated_deny on public.service_fulfilment_invoice_links as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── 3. what never changes ────────────────────────────────────────────────
-- A member's rows cascade here only to meet the guards below: a member who still has an
-- engagement, a step or a link cannot be deleted (the guard refuses the cascaded delete
-- while the business exists), and the business's own deletion works in whatever order the
-- rows are reached.
-- A step and a link are never changed or deleted; an engagement is never deleted
-- and only its state and revision move (the commands below). Every delete is
-- allowed once the business itself is gone, so the business can be erased.
create or replace function public.service_fulfilment_frozen() returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  if tg_table_name = 'service_fulfilments' and tg_op = 'UPDATE' then
    if (to_jsonb(new) - 'state' - 'revision' - public.system_column_names())
       is distinct from (to_jsonb(old) - 'state' - 'revision' - public.system_column_names()) then
      raise exception 'an engagement''s source and scope never change' using errcode = 'DKF05';
    end if;
    return new;
  end if;
  raise exception 'the history of an engagement is never changed or deleted' using errcode = 'DKF05';
end
$fn$;
revoke execute on function public.service_fulfilment_frozen() from public, anon, authenticated;

create trigger service_fulfilments_frozen before update or delete on public.service_fulfilments
  for each row execute function public.service_fulfilment_frozen();
create trigger service_fulfilment_transitions_frozen before update or delete on public.service_fulfilment_transitions
  for each row execute function public.service_fulfilment_frozen();
create trigger service_fulfilment_invoice_links_frozen before update or delete on public.service_fulfilment_invoice_links
  for each row execute function public.service_fulfilment_frozen();

-- ── 4. helpers ───────────────────────────────────────────────────────────
-- The issuer of the business (the right to issue), never an assistant.
create or replace function public.service_fulfilment_actor(p_workspace uuid) returns public.members
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if public.mcp_is_delegated() then
    raise exception 'service fulfilment is kept in the app, not by an assistant' using errcode = 'DKF07';
  end if;
  if public.feature_effective(p_workspace, 'serviceFulfilment') is not true then
    raise exception 'service fulfilment is not switched on in this business' using errcode = 'DKF10';
  end if;
  return public.issuing_member(p_workspace);
end
$fn$;
revoke execute on function public.service_fulfilment_actor(uuid) from public, anon, authenticated;

create or replace function public.service_fulfilment_digest(p_text text) returns text
language sql immutable set search_path = public as $fn$
  select encode(sha256(convert_to(coalesce(p_text, ''), 'UTF8')), 'hex');
$fn$;
revoke execute on function public.service_fulfilment_digest(text) from public, anon, authenticated;

-- One frozen quote or invoice line as the scope of an engagement.
create or replace function public.service_fulfilment_line_scope(p_line jsonb) returns jsonb
language sql immutable set search_path = public as $fn$
  select jsonb_build_object(
    'description', coalesce(p_line ->> 'label', ''),
    'quantity', coalesce(p_line #>> '{commercial,quantity}', ''),
    'unit', coalesce(nullif(p_line #>> '{commercial,unit,label}', ''), p_line #>> '{commercial,unit,code}', ''));
$fn$;
revoke execute on function public.service_fulfilment_line_scope(jsonb) from public, anon, authenticated;

-- The canonical commercial source of ONE line: for an invoice line, the quote it
-- was converted from, or the direct commitment it was linked to, else itself.
-- Returns {kind, id, revision, line_id, subject_id, scope}; raises when the
-- source is not accepted commercial evidence.
create or replace function public.service_fulfilment_source(
  p_workspace uuid, p_kind text, p_id uuid, p_line uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_inv public.invoices;
  v_conv public.customer_quote_conversions;
  v_link public.service_fulfilment_invoice_links;
  v_f public.service_fulfilments;
  v_line jsonb;
begin
  if p_kind = 'quote' then
    select * into v_q from public.customer_quotes q
     where q.id = p_id and q.workspace_id = p_workspace;
    if v_q.id is null then
      raise exception 'unknown source' using errcode = 'DKF01', detail = 'quote';
    end if;
    if v_q.status not in ('accepted', 'converted') then
      raise exception 'only an accepted quote is a source' using errcode = 'DKF03', detail = 'not_accepted';
    end if;
    select r.* into v_rev from public.customer_quote_decisions d
      join public.customer_quote_revisions r on r.id = d.revision_id
     where d.quote_id = v_q.id and d.decision = 'accepted';
    select l into v_line from jsonb_array_elements(v_rev.frozen -> 'lines') l
     where l #>> '{commercial,line_id}' = p_line::text limit 1;
    if v_line is null then
      raise exception 'unknown line of the accepted revision' using errcode = 'DKF01', detail = 'line';
    end if;
    return jsonb_build_object('kind', 'quote', 'id', v_q.id, 'revision', v_rev.revision,
      'line_id', p_line, 'subject_id', v_q.subject_member_id,
      'scope', public.service_fulfilment_line_scope(v_line));
  elsif p_kind = 'invoice' then
    select * into v_inv from public.invoices i where i.id = p_id and i.workspace_id = p_workspace;
    if v_inv.id is null then
      raise exception 'unknown source' using errcode = 'DKF01', detail = 'invoice';
    end if;
    if v_inv.total_cents <= 0 then
      raise exception 'a credit note is not a source' using errcode = 'DKF03', detail = 'not_a_service_invoice';
    end if;
    select l into v_line from jsonb_array_elements(v_inv.lines) l
     where l #>> '{commercial,line_id}' = p_line::text limit 1;
    if v_line is null then
      raise exception 'unknown line of the invoice' using errcode = 'DKF01', detail = 'line';
    end if;
    -- A correction invoice cannot fork the engagement: a standalone invoice (the only kind
    -- whose lines carry a commercial line id, and the only kind a quote converts to) is
    -- refused by create_invoice as a replacement (0820), and a monthly replacement's lines
    -- have no commercial line id, so opening from one answers DKF01 above.
    -- billed from a quote: that quote's line is the source
    select * into v_conv from public.customer_quote_conversions c
     where c.invoice_id = v_inv.id and c.workspace_id = p_workspace;
    if v_conv.quote_id is not null then
      return public.service_fulfilment_source(p_workspace, 'quote', v_conv.quote_id, p_line);
    end if;
    -- billed from a direct commitment: that commitment is the source
    select * into v_link from public.service_fulfilment_invoice_links k
     where k.invoice_id = v_inv.id and k.line_id = p_line and k.workspace_id = p_workspace;
    if v_link.id is not null then
      select * into v_f from public.service_fulfilments f where f.id = v_link.fulfilment_id;
      return jsonb_build_object('kind', v_f.source_kind, 'id', v_f.source_id, 'revision', v_f.source_revision,
        'line_id', v_f.source_line_id, 'subject_id', v_f.subject_member_id, 'scope', v_f.scope);
    end if;
    return jsonb_build_object('kind', 'invoice', 'id', v_inv.id, 'revision', null,
      'line_id', p_line, 'subject_id', v_inv.member_id,
      'scope', public.service_fulfilment_line_scope(v_line));
  end if;
  raise exception 'unknown kind of source' using errcode = 'DKF06', detail = 'kind';
end
$fn$;
revoke execute on function public.service_fulfilment_source(uuid, text, uuid, uuid) from public, anon, authenticated;

-- The invoices an engagement is billed on, whichever way: the quote's conversion,
-- the invoice it came from, or the lines linked to a direct commitment.
create or replace function public.service_fulfilment_invoice_ids(f public.service_fulfilments)
returns setof uuid language sql stable security definer set search_path = public as $fn$
  select c.invoice_id from public.customer_quote_conversions c
   where f.source_kind = 'quote' and c.quote_id = f.source_id
  union
  select f.source_id where f.source_kind = 'invoice'
  union
  select k.invoice_id from public.service_fulfilment_invoice_links k where k.fulfilment_id = f.id;
$fn$;
revoke execute on function public.service_fulfilment_invoice_ids(public.service_fulfilments)
  from public, anon, authenticated;

-- One engagement as the app reads it: its state and history, the quote it came
-- from and the invoices it is billed on with what was paid and any correction
-- (facts that are READ here, never changed).
create or replace function public.service_fulfilment_json(f public.service_fulfilments) returns jsonb
language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'fulfilment_id', f.id, 'subject_id', f.subject_member_id,
    'state', f.state, 'revision', f.revision,
    'source', jsonb_build_object('kind', f.source_kind, 'id', f.source_id,
                                 'revision', f.source_revision, 'line_id', f.source_line_id),
    'item_id', f.item_id, 'variant_id', f.variant_id, 'scope', f.scope,
    'history', coalesce((select jsonb_agg(jsonb_build_object(
        'revision', t.revision, 'from', t.from_state, 'to', t.to_state, 'reason', t.reason,
        'actor_id', t.actor_member_id, 'at', t.occurred_at) order by t.revision)
      from public.service_fulfilment_transitions t where t.fulfilment_id = f.id), '[]'::jsonb),
    'quote', (select jsonb_build_object('quote_id', q.id, 'reference', q.reference, 'status', q.status)
      from public.customer_quotes q where f.source_kind = 'quote' and q.id = f.source_id),
    'invoices', coalesce((select jsonb_agg(jsonb_build_object(
        'invoice_id', i.id, 'number', i.number, 'total_cents', i.total_cents, 'currency', i.currency,
        'paid_cents', coalesce((select m.paid_cents from public.invoice_matches m
                                 where m.invoice_id = i.id order by m.matched_at desc limit 1), 0),
        'corrections', coalesce((select jsonb_agg(jsonb_build_object(
            'invoice_id', c.id, 'number', c.number, 'total_cents', c.total_cents) order by c.issued_at)
          from public.invoices c where c.replaces_invoice_id = i.id), '[]'::jsonb))
        order by i.issued_at)
      from public.invoices i
      where i.id in (select public.service_fulfilment_invoice_ids(f))), '[]'::jsonb));
$fn$;
revoke execute on function public.service_fulfilment_json(public.service_fulfilments)
  from public, anon, authenticated;

-- The scope of a direct engagement as it is stored: checked, never trusted.
-- Returns {subject_id, item_id, variant_id, scope}.
create or replace function public.service_fulfilment_direct_scope(p_workspace uuid, p_scope jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_subject uuid; v_item uuid; v_variant uuid;
  v_desc text; v_qty numeric; v_unit text;
begin
  if p_scope is null or jsonb_typeof(p_scope) <> 'object' then
    raise exception 'the scope of the engagement is missing' using errcode = 'DKF06', detail = 'scope';
  end if;
  begin v_subject := (p_scope ->> 'subject_id')::uuid; exception when others then v_subject := null; end;
  if v_subject is null or not public.billing_customer_ok(p_workspace, v_subject) then
    raise exception 'the customer is unknown' using errcode = 'DKF01', detail = 'subject';
  end if;
  v_desc := btrim(coalesce(p_scope ->> 'description', ''));
  if v_desc = '' or char_length(v_desc) > 200 then
    raise exception 'the description is needed' using errcode = 'DKF06', detail = 'description';
  end if;
  begin v_qty := (p_scope ->> 'quantity')::numeric; exception when others then v_qty := null; end;
  if v_qty is null or v_qty <= 0 or v_qty > 1000000 then
    raise exception 'the quantity is out of range' using errcode = 'DKF06', detail = 'quantity';
  end if;
  v_unit := btrim(coalesce(p_scope ->> 'unit', ''));
  if char_length(v_unit) > 40 then
    raise exception 'the unit is too long' using errcode = 'DKF06', detail = 'unit';
  end if;
  begin v_item := nullif(p_scope ->> 'item_id', '')::uuid; exception when others then
    raise exception 'unknown item' using errcode = 'DKF01', detail = 'item'; end;
  begin v_variant := nullif(p_scope ->> 'variant_id', '')::uuid; exception when others then
    raise exception 'unknown variant' using errcode = 'DKF01', detail = 'variant'; end;
  if v_item is not null and not exists (
       select 1 from public.services s where s.id = v_item and s.workspace_id = p_workspace) then
    raise exception 'unknown item' using errcode = 'DKF01', detail = 'item';
  end if;
  if v_variant is not null and (v_item is null or not exists (
       select 1 from public.item_variants v
        where v.id = v_variant and v.item_id = v_item and v.workspace_id = p_workspace)) then
    raise exception 'unknown variant' using errcode = 'DKF01', detail = 'variant';
  end if;
  return jsonb_build_object('subject_id', v_subject, 'item_id', v_item, 'variant_id', v_variant,
    'scope', jsonb_build_object('description', v_desc, 'quantity', trim_scale(v_qty)::text, 'unit', v_unit,
      'item', (select s.name from public.services s where s.id = v_item),
      'variant', (select v.canonical from public.item_variants v where v.id = v_variant)));
end
$fn$;
revoke execute on function public.service_fulfilment_direct_scope(uuid, jsonb) from public, anon, authenticated;

-- ── 5. the commands ──────────────────────────────────────────────────────
-- Open the engagement of a source line, or find it: ONE aggregate per canonical
-- source line. `p_source` is {kind: quote|invoice, id, line_id} or {kind: direct}
-- with `p_scope` {subject_id, description, quantity, unit, item_id, variant_id}.
-- The same request replays its answer; a changed payload under it is refused.
-- Returns {fulfilment, created, replayed}.
create or replace function public.open_service_fulfilment_v1(
  p_workspace_id uuid, p_request_id uuid, p_source jsonb, p_scope jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_kind text;
  v_id uuid;
  v_line uuid;
  v_digest text;
  v_prior public.service_fulfilment_transitions;
  v_src jsonb;
  v_direct jsonb;
  v_new uuid := gen_random_uuid();
  v_f public.service_fulfilments;
begin
  v_actor := public.service_fulfilment_actor(p_workspace_id);
  if p_request_id is null then
    raise exception 'a request identity is needed' using errcode = 'DKF06', detail = 'request_id';
  end if;
  if p_source is null or jsonb_typeof(p_source) <> 'object' then
    raise exception 'the source is missing' using errcode = 'DKF06', detail = 'source';
  end if;
  v_kind := p_source ->> 'kind';
  v_digest := public.service_fulfilment_digest(
    jsonb_build_object('source', p_source, 'scope', coalesce(p_scope, 'null'::jsonb))::text);
  -- the same request, answered before: its engagement, never a second one
  select * into v_prior from public.service_fulfilment_transitions t
   where t.workspace_id = p_workspace_id and t.request_id = p_request_id;
  if v_prior.id is not null then
    if v_prior.revision <> 1 or v_prior.request_digest <> v_digest then
      raise exception 'this request was used for something else' using errcode = 'DKF05', detail = 'request';
    end if;
    select * into v_f from public.service_fulfilments where id = v_prior.fulfilment_id;
    return jsonb_build_object('fulfilment', public.service_fulfilment_json(v_f),
                              'created', false, 'replayed', true);
  end if;
  if v_kind = 'direct' then
    v_direct := public.service_fulfilment_direct_scope(p_workspace_id, p_scope);
    v_src := jsonb_build_object('kind', 'direct', 'id', v_new, 'revision', null, 'line_id', gen_random_uuid(),
      'subject_id', v_direct -> 'subject_id', 'scope', v_direct -> 'scope');
  elsif v_kind in ('quote', 'invoice') then
    begin
      v_id := (p_source ->> 'id')::uuid;
      v_line := (p_source ->> 'line_id')::uuid;
    exception when others then
      raise exception 'the source is not understood' using errcode = 'DKF06', detail = 'source';
    end;
    -- An invoice line is resolved and its engagement inserted under the invoice's row
    -- lock, the same lock `link_service_fulfilment_invoice_v1` takes: a link and an open
    -- of one line cannot both commit, each answers the other's engagement. (A key-share
    -- reference to the invoice, a payment match, still goes through.)
    if v_kind = 'invoice' then
      perform 1 from public.invoices i where i.id = v_id and i.workspace_id = p_workspace_id for no key update;
    end if;
    v_src := public.service_fulfilment_source(p_workspace_id, v_kind, v_id, v_line);
  else
    raise exception 'unknown kind of source' using errcode = 'DKF06', detail = 'kind';
  end if;
  -- the subject's engagement of this canonical line, if it already exists
  select * into v_f from public.service_fulfilments f
   where f.workspace_id = p_workspace_id and f.source_kind = v_src ->> 'kind'
     and f.source_id = (v_src ->> 'id')::uuid and f.source_line_id = (v_src ->> 'line_id')::uuid;
  if v_f.id is null then
    begin
      insert into public.service_fulfilments
        (id, workspace_id, subject_member_id, source_kind, source_id, source_revision, source_line_id,
         item_id, variant_id, scope)
      values (case when v_src ->> 'kind' = 'direct' then (v_src ->> 'id')::uuid else gen_random_uuid() end,
              p_workspace_id, (v_src ->> 'subject_id')::uuid, v_src ->> 'kind', (v_src ->> 'id')::uuid,
              nullif(v_src ->> 'revision', '')::integer, (v_src ->> 'line_id')::uuid,
              (v_direct ->> 'item_id')::uuid, (v_direct ->> 'variant_id')::uuid, v_src -> 'scope')
      on conflict (workspace_id, source_kind, source_id, source_line_id) do nothing
      returning * into v_f;
      if v_f.id is not null then
        insert into public.service_fulfilment_transitions
          (workspace_id, fulfilment_id, revision, from_state, to_state, actor_member_id, reason,
           request_id, request_digest)
        values (p_workspace_id, v_f.id, 1, null, 'ordered', v_actor.id, '', p_request_id, v_digest);
        return jsonb_build_object('fulfilment', public.service_fulfilment_json(v_f),
                                  'created', true, 'replayed', false);
      end if;
    exception when unique_violation then
      -- the same request committed first, in another session: its answer, never an error
      select * into v_prior from public.service_fulfilment_transitions t
       where t.workspace_id = p_workspace_id and t.request_id = p_request_id;
      if v_prior.id is null then raise; end if;
      if v_prior.revision <> 1 or v_prior.request_digest <> v_digest then
        raise exception 'this request was used for something else' using errcode = 'DKF05', detail = 'request';
      end if;
      select * into v_f from public.service_fulfilments where id = v_prior.fulfilment_id;
      return jsonb_build_object('fulfilment', public.service_fulfilment_json(v_f),
                                'created', false, 'replayed', true);
    end;
    -- a concurrent open of the same line won: it is that engagement
    select * into v_f from public.service_fulfilments f
     where f.workspace_id = p_workspace_id and f.source_kind = v_src ->> 'kind'
       and f.source_id = (v_src ->> 'id')::uuid and f.source_line_id = (v_src ->> 'line_id')::uuid;
  end if;
  return jsonb_build_object('fulfilment', public.service_fulfilment_json(v_f),
                            'created', false, 'replayed', false);
end
$fn$;
revoke execute on function public.open_service_fulfilment_v1(uuid, uuid, jsonb, jsonb) from public, anon;
grant execute on function public.open_service_fulfilment_v1(uuid, uuid, jsonb, jsonb) to authenticated;

-- One step of an engagement at its expected revision: ordered -> started -> done,
-- or ordered | started -> cancelled with a reason. Returns {fulfilment, replayed}.
create or replace function public.transition_service_fulfilment_v1(
  p_workspace_id uuid, p_fulfilment_id uuid, p_expected_revision integer,
  p_to text, p_reason text, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_f public.service_fulfilments;
  v_prior public.service_fulfilment_transitions;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_digest text;
  v_from text;
begin
  v_actor := public.service_fulfilment_actor(p_workspace_id);
  if p_request_id is null then
    raise exception 'a request identity is needed' using errcode = 'DKF06', detail = 'request_id';
  end if;
  if p_to not in ('started', 'done', 'cancelled') then
    raise exception 'unknown step' using errcode = 'DKF06', detail = 'state';
  end if;
  select * into v_f from public.service_fulfilments f
   where f.id = p_fulfilment_id and f.workspace_id = p_workspace_id for update;
  if v_f.id is null then raise exception 'unknown engagement' using errcode = 'DKF01', detail = 'fulfilment'; end if;
  v_digest := public.service_fulfilment_digest(
    concat_ws('|', p_fulfilment_id::text, p_expected_revision::text, p_to, v_reason));
  -- a step answered before is its own answer again, however late the retry
  select * into v_prior from public.service_fulfilment_transitions t
   where t.workspace_id = p_workspace_id and t.request_id = p_request_id;
  if v_prior.id is not null then
    if v_prior.fulfilment_id <> v_f.id or v_prior.request_digest <> v_digest then
      raise exception 'this request was used for something else' using errcode = 'DKF05', detail = 'request';
    end if;
    return jsonb_build_object('fulfilment', public.service_fulfilment_json(v_f), 'replayed', true);
  end if;
  if v_f.revision is distinct from p_expected_revision then
    raise exception 'the engagement moved on: read it again' using errcode = 'DKF02', detail = v_f.revision::text;
  end if;
  if not ((v_f.state = 'ordered' and p_to in ('started', 'cancelled'))
          or (v_f.state = 'started' and p_to in ('done', 'cancelled'))) then
    raise exception 'that step is not allowed from this state' using errcode = 'DKF04', detail = v_f.state;
  end if;
  if p_to = 'cancelled' and v_reason = '' then
    raise exception 'a cancellation needs a reason' using errcode = 'DKF06', detail = 'reason';
  end if;
  v_from := v_f.state;
  update public.service_fulfilments set state = p_to, revision = revision + 1 where id = v_f.id
    returning * into v_f;
  insert into public.service_fulfilment_transitions
    (workspace_id, fulfilment_id, revision, from_state, to_state, actor_member_id, reason,
     request_id, request_digest)
  values (p_workspace_id, v_f.id, v_f.revision, v_from, p_to, v_actor.id, v_reason, p_request_id, v_digest);
  return jsonb_build_object('fulfilment', public.service_fulfilment_json(v_f), 'replayed', false);
end
$fn$;
revoke execute on function public.transition_service_fulfilment_v1(uuid, uuid, integer, text, text, uuid)
  from public, anon;
grant execute on function public.transition_service_fulfilment_v1(uuid, uuid, integer, text, text, uuid)
  to authenticated;

-- Record that a line of an issued invoice bills a DIRECT engagement's preserved
-- commitment: the explicit correspondence. The same link again is the same answer;
-- a line that answers for another engagement is refused.
create or replace function public.link_service_fulfilment_invoice_v1(
  p_workspace_id uuid, p_fulfilment_id uuid, p_invoice_id uuid, p_line_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_f public.service_fulfilments;
  v_inv public.invoices;
  v_link public.service_fulfilment_invoice_links;
begin
  v_actor := public.service_fulfilment_actor(p_workspace_id);
  -- the invoice first, then the engagement: the order `open_service_fulfilment_v1` takes
  perform 1 from public.invoices i where i.id = p_invoice_id and i.workspace_id = p_workspace_id for no key update;
  select * into v_f from public.service_fulfilments f
   where f.id = p_fulfilment_id and f.workspace_id = p_workspace_id for update;
  if v_f.id is null then raise exception 'unknown engagement' using errcode = 'DKF01', detail = 'fulfilment'; end if;
  if v_f.source_kind <> 'direct' then
    raise exception 'only a direct engagement is linked to an invoice line' using errcode = 'DKF03', detail = 'not_direct';
  end if;
  select * into v_inv from public.invoices i where i.id = p_invoice_id and i.workspace_id = p_workspace_id;
  if v_inv.id is null then raise exception 'unknown invoice' using errcode = 'DKF01', detail = 'invoice'; end if;
  if v_inv.member_id <> v_f.subject_member_id or v_inv.total_cents <= 0 then
    raise exception 'the invoice is not made out to this engagement''s customer' using errcode = 'DKF03', detail = 'subject';
  end if;
  if not exists (select 1 from jsonb_array_elements(v_inv.lines) l
                  where l #>> '{commercial,line_id}' = p_line_id::text) then
    raise exception 'unknown line of the invoice' using errcode = 'DKF01', detail = 'line';
  end if;
  select * into v_link from public.service_fulfilment_invoice_links k
   where k.workspace_id = p_workspace_id and k.invoice_id = p_invoice_id and k.line_id = p_line_id;
  if v_link.id is not null then
    if v_link.fulfilment_id <> v_f.id then
      raise exception 'that line answers for another engagement' using errcode = 'DKF03', detail = 'taken';
    end if;
  else
    -- a line that came from a quote already has its engagement through the quote
    if exists (select 1 from public.customer_quote_conversions c where c.invoice_id = p_invoice_id) then
      raise exception 'that line answers for its quote''s engagement' using errcode = 'DKF03', detail = 'taken';
    end if;
    -- nor one that already has its own engagement as an invoice line
    if exists (select 1 from public.service_fulfilments o
                where o.workspace_id = p_workspace_id and o.source_kind = 'invoice'
                  and o.source_id = p_invoice_id and o.source_line_id = p_line_id) then
      raise exception 'that line already has its own engagement' using errcode = 'DKF03', detail = 'taken';
    end if;
    insert into public.service_fulfilment_invoice_links
      (workspace_id, fulfilment_id, invoice_id, line_id, linked_by_member_id)
    values (p_workspace_id, v_f.id, p_invoice_id, p_line_id, v_actor.id);
  end if;
  return jsonb_build_object('fulfilment', public.service_fulfilment_json(v_f));
end
$fn$;
revoke execute on function public.link_service_fulfilment_invoice_v1(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.link_service_fulfilment_invoice_v1(uuid, uuid, uuid, uuid) to authenticated;

-- ── 6. reading ───────────────────────────────────────────────────────────
create or replace function public.service_fulfilments_v1(p_workspace_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
begin
  if not public.service_fulfilments_readable(p_workspace_id) then
    raise exception 'service fulfilment is not available' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(public.service_fulfilment_json(f) order by f.created_datetime, f.id)
                     from public.service_fulfilments f where f.workspace_id = p_workspace_id), '[]'::jsonb);
end
$fn$;
revoke execute on function public.service_fulfilments_v1(uuid) from public, anon;
grant execute on function public.service_fulfilments_v1(uuid) to authenticated;

create or replace function public.service_fulfilment_v1(p_workspace_id uuid, p_fulfilment_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare v_f public.service_fulfilments;
begin
  if not public.service_fulfilments_readable(p_workspace_id) then
    raise exception 'service fulfilment is not available' using errcode = '42501';
  end if;
  select * into v_f from public.service_fulfilments f
   where f.id = p_fulfilment_id and f.workspace_id = p_workspace_id;
  if v_f.id is null then raise exception 'unknown engagement' using errcode = 'DKF01', detail = 'fulfilment'; end if;
  return public.service_fulfilment_json(v_f);
end
$fn$;
revoke execute on function public.service_fulfilment_v1(uuid, uuid) from public, anon;
grant execute on function public.service_fulfilment_v1(uuid, uuid) to authenticated;

-- The engagement a quote or invoice line already has, resolved through its
-- canonical source, or null. Reading only: nothing is opened.
create or replace function public.service_fulfilment_of_line_v1(
  p_workspace_id uuid, p_kind text, p_id uuid, p_line_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_src jsonb;
  v_f public.service_fulfilments;
begin
  if not public.service_fulfilments_readable(p_workspace_id) then
    raise exception 'service fulfilment is not available' using errcode = '42501';
  end if;
  if p_kind not in ('quote', 'invoice') then
    raise exception 'unknown kind of source' using errcode = 'DKF06', detail = 'kind';
  end if;
  v_src := public.service_fulfilment_source(p_workspace_id, p_kind, p_id, p_line_id);
  select * into v_f from public.service_fulfilments f
   where f.workspace_id = p_workspace_id and f.source_kind = v_src ->> 'kind'
     and f.source_id = (v_src ->> 'id')::uuid and f.source_line_id = (v_src ->> 'line_id')::uuid;
  return case when v_f.id is null then null else public.service_fulfilment_json(v_f) end;
end
$fn$;
revoke execute on function public.service_fulfilment_of_line_v1(uuid, text, uuid, uuid) from public, anon;
grant execute on function public.service_fulfilment_of_line_v1(uuid, text, uuid, uuid) to authenticated;

-- ── 7. the workspace records export carries the engagements ──────────────
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

-- ── 8. the freelancer proposes it ───────────────────────────────────────
-- A freelancer follows each ordered service from the order to the work done, so
-- the reviewed kind profile (0834, 0846) proposes `serviceFulfilment` too: a new
-- version of the profile (the trigger of 0834 raises `profile_version` and
-- recomputes the digest), so a proposal reviewed on the earlier one is reviewed
-- again. The generic `service` kind is untouched.
update public.business_kinds
   set feature_profile = feature_profile || '{"serviceFulfilment": true}'::jsonb
 where code = 'freelancer';

select public.set_deskilo_schema_version(852);
