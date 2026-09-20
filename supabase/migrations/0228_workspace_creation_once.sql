-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0228 (#1303 S0, absorbs #1318) — creating a workspace is one act, and
-- asking twice makes one workspace.
--
-- Onboarding called `create_workspace`, then `apply_workspace_template`:
-- two requests under one failure boundary that kept no id. So:
--
--   * a lost response followed by a retry made a SECOND workspace — and,
--     with the dev/prod twin created by default (0202), a second PAIR;
--   * a template that failed after the workspace existed reported the
--     whole creation as failed, and the retry made another one.
--
-- ## The 0214 shape
--
-- `create_workspace` is a long function whose hosted body has diverged
-- from its file before (#1226), so it is not re-created with a new
-- parameter. `create_workspace_once` wraps it, the way
-- `create_reservation_once` wraps `create_reservation`:
--
--   1. claim `(created_by, client_request_id)` — exactly one caller wins;
--   2. create the workspace (and its twin);
--   3. apply the chosen template, in the SAME transaction.
--
-- Either the workspace exists with its template, or nothing exists and
-- the claim rolled back with it, so a retry starts clean. A repeat of a
-- request id that already finished returns the same workspace and does
-- nothing else: no second workspace, no second pair, no second apply.

create table if not exists public.workspace_creation_requests (
  created_by uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  -- Not `workspace_id`: the claim exists before the workspace does, and
  -- a workspace-scoped row must name its workspace from the start.
  created_workspace_id uuid references public.workspaces(id) on delete set null,
  claimed_at timestamptz not null default now(),
  primary key (created_by, client_request_id)
);
select public.ensure_system_columns('workspace_creation_requests');

alter table public.workspace_creation_requests enable row level security;
-- No policy and no grant: the claim ledger is the server's bookkeeping.
-- The caller reads the answer — the workspace id — through the function.
revoke all on table public.workspace_creation_requests from anon, authenticated;

comment on table public.workspace_creation_requests is
  '#1303 — one row per workspace a client asked to create, keyed by the '
  'id the CLIENT generated. A retried creation returns the workspace the '
  'first attempt made instead of making another.';

create or replace function public.create_workspace_once(
  p_client_request_id uuid,
  p_name text,
  p_country_code text,
  p_currency_code text,
  p_timezone text,
  p_environment text default 'dev',
  p_with_twin boolean default true,
  p_feature_flags jsonb default null,
  p_template_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_caller uuid := auth.uid();
  v_claimed int := 0;
  v_existing uuid;
  v_id uuid;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;
  if p_client_request_id is null then
    raise exception 'a replayable creation needs a request id';
  end if;

  -- Claim the key. Exactly one caller wins; the rest read the answer. The
  -- key is the caller's own by construction: it is half of the primary key.
  insert into public.workspace_creation_requests (created_by, client_request_id)
  values (v_caller, p_client_request_id)
  on conflict do nothing;
  get diagnostics v_claimed = row_count;

  if v_claimed = 0 then
    select created_workspace_id into v_existing
      from public.workspace_creation_requests
     where created_by = v_caller and client_request_id = p_client_request_id;
    if v_existing is null then
      -- Claimed and not finished: still running in another transaction.
      -- A failed attempt rolled its claim back, so it is never this.
      raise exception 'that workspace is already being created';
    end if;
    return v_existing;
  end if;

  v_id := public.create_workspace(
    p_name, p_country_code, p_currency_code, p_timezone,
    p_environment, p_with_twin, p_feature_flags);

  -- The first template belongs to the creation: if it cannot be applied,
  -- nothing was created. `apply_workspace_template` checks the caller owns
  -- the target — they own the row just inserted — and that the template
  -- is readable.
  if p_template_id is not null then
    perform public.apply_workspace_template(v_id, p_template_id);
  end if;

  update public.workspace_creation_requests
     set created_workspace_id = v_id
   where created_by = v_caller and client_request_id = p_client_request_id;
  return v_id;
end;
$fn$;

revoke execute on function public.create_workspace_once(
  uuid, text, text, text, text, text, boolean, jsonb, uuid)
from public, anon;
grant execute on function public.create_workspace_once(
  uuid, text, text, text, text, text, boolean, jsonb, uuid)
to authenticated;

select public.set_deskilo_schema_version(228);
