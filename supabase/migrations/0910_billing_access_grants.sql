-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (one table, seven functions, one policy restated)
--
-- #4164 B1 -- a billing customer may read and pay their own documents from their own account, without becoming a
-- member. The seller issues an invitation for ONE financial subject (the seller-local `members.id` of a billing-only
-- customer, 0821); the account that accepts it holds a billing-access grant: the documents and the payments of that
-- subject in that business, and nothing else -- no booking, directory, community, management or subscription right
-- follows, and no `members` row is created or changed. One account may hold grants for several subjects (a person
-- buying personally and for a company keeps two debtors), and a subject's grant moves to another account only by a
-- new invitation: the debt never moves with a login.
--
--   * `billing_access_grants`: the seller workspace, the financial subject, the purpose (`billing_documents`), the
--     invitation code, who issued it and when, who accepted it and when, who revoked it, when and why. A revocation
--     ends future access; it erases no invoice, allocation or history.
--   * `billing_access_invite_v1` (the seller, under manageBillingCustomers; a request id replays),
--     `billing_access_preview_v1` (what a code names, before accepting), `billing_access_accept_v1` (the account
--     accepting; a replay by the same account answers the same grant), `billing_access_revoke_v1` (the seller, or
--     the account itself).
--   * `billing_subject_granted(workspace, subject)`: whether the caller holds a live grant for that subject -- the
--     one predicate every grant-aware reader uses; `invoices_select` is restated with it, so the customer reads the
--     rows of their own subject's invoices and no other.
--
-- An assistant never invites, accepts or revokes (`mcp_require_native` / the manage guard): a grant is a person's
-- decision in the app.

-- ── 1. the grant ─────────────────────────────────────────────────────────
create table if not exists public.billing_access_grants (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  financial_subject_id uuid not null,
  purpose text not null default 'billing_documents' check (purpose in ('billing_documents')),
  code text not null unique default public.gen_invite_code(),
  request_id uuid not null,
  invited_by uuid not null references public.members(id),
  invited_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  principal_user_id uuid references auth.users(id) on delete cascade,
  accepted_at timestamptz,
  revoked_at timestamptz,
  revoked_by_user_id uuid,
  revoke_reason text not null default '' check (char_length(revoke_reason) <= 500),
  foreign key (workspace_id, financial_subject_id) references public.members (workspace_id, id) on delete cascade,
  unique (workspace_id, request_id),
  check ((principal_user_id is null) = (accepted_at is null)),
  check (revoked_at is null or revoked_by_user_id is not null)
);
select public.ensure_system_columns('billing_access_grants');
create index if not exists billing_access_grants_subject_idx
  on public.billing_access_grants (workspace_id, financial_subject_id);
create index if not exists billing_access_grants_principal_idx
  on public.billing_access_grants (principal_user_id) where principal_user_id is not null and revoked_at is null;
-- One live grant of one subject to one account.
create unique index if not exists billing_access_grants_live_uniq
  on public.billing_access_grants (workspace_id, financial_subject_id, principal_user_id)
  where principal_user_id is not null and revoked_at is null;
comment on table public.billing_access_grants is
  '#4164 -- an account''s access to the documents and payments of ONE billing subject of a seller: invited by the seller, accepted by the account, revocable; never a membership';

alter table public.billing_access_grants enable row level security;
drop policy if exists billing_access_grants_select on public.billing_access_grants;
create policy billing_access_grants_select on public.billing_access_grants for select
  using (public.billing_customers_readable(workspace_id) or principal_user_id = (select auth.uid()));
drop policy if exists mcp_delegated_deny on public.billing_access_grants;
create policy mcp_delegated_deny on public.billing_access_grants as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
revoke all on public.billing_access_grants from anon, authenticated;
grant select on public.billing_access_grants to authenticated;

-- ── 2. the predicate ─────────────────────────────────────────────────────
create or replace function public.billing_subject_granted(p_workspace uuid, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select auth.uid() is not null and exists (
    select 1 from public.billing_access_grants g
     where g.workspace_id = p_workspace and g.financial_subject_id = p_subject
       and g.principal_user_id = auth.uid() and g.revoked_at is null);
$fn$;
revoke execute on function public.billing_subject_granted(uuid, uuid) from public, anon;
grant execute on function public.billing_subject_granted(uuid, uuid) to authenticated;

-- The customer reads the rows of their own subject's invoices; the rest of the policy is 0060's.
drop policy if exists invoices_select on public.invoices;
create policy invoices_select on public.invoices for select using (
  public.is_admin_of(workspace_id)
  or exists (select 1 from public.members m
              where m.id = invoices.member_id and m.user_id = auth.uid())
  -- one set per query, not a call per row: the caller's live grants (their own rows of the grants table)
  or member_id in (select g.financial_subject_id from public.billing_access_grants g
                    where g.principal_user_id = (select auth.uid()) and g.revoked_at is null)
);

-- ── 3. the seller invites ────────────────────────────────────────────────
create or replace function public.billing_access_invite_v1(p_workspace uuid, p_subject uuid, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_old public.billing_access_grants;
  v_new public.billing_access_grants;
begin
  perform public.billing_manage_guard(p_workspace);
  if p_request_id is null then
    raise exception 'an invitation names its request id' using errcode = '22023';
  end if;
  select g.* into v_old from public.billing_access_grants g
   where g.workspace_id = p_workspace and g.request_id = p_request_id;
  if v_old.id is not null then
    if v_old.financial_subject_id <> p_subject then
      raise exception 'this request id was used for another invitation' using errcode = 'DKH05';
    end if;
    return jsonb_build_object('grant_id', v_old.id, 'code', v_old.code, 'expires_at', v_old.expires_at,
                              'replayed', true);
  end if;
  -- Only a billing-only customer: a member already reads their documents through their membership.
  if not exists (select 1 from public.members m
                  where m.id = p_subject and m.workspace_id = p_workspace and m.status = 'customer') then
    raise exception 'an access invitation is for a billing customer of this business' using errcode = 'DKH02';
  end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace and m.user_id = auth.uid() and m.status = 'active';
  insert into public.billing_access_grants (workspace_id, financial_subject_id, request_id, invited_by)
  values (p_workspace, p_subject, p_request_id, v_me)
  returning * into v_new;
  return jsonb_build_object('grant_id', v_new.id, 'code', v_new.code, 'expires_at', v_new.expires_at,
                            'replayed', false);
end
$fn$;
revoke execute on function public.billing_access_invite_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.billing_access_invite_v1(uuid, uuid, uuid) to authenticated;

-- ── 4. the customer reads, then accepts, the invitation ─────────────────
-- What a code names, before accepting: the seller and the billed name, and whether it can still be accepted.
-- One answer for an unknown, expired, revoked or taken code: nothing about a grant reaches an account it is not for.
create or replace function public.billing_access_preview_v1(p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_g public.billing_access_grants;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  select g.* into v_g from public.billing_access_grants g where g.code = upper(btrim(coalesce(p_code, '')));
  if v_g.id is null or v_g.revoked_at is not null
     or (v_g.principal_user_id is null and v_g.expires_at <= now())
     or (v_g.principal_user_id is not null and v_g.principal_user_id <> auth.uid()) then
    raise exception 'this invitation cannot be used' using errcode = 'DKH01';
  end if;
  return jsonb_build_object(
    'workspace_name', (select w.name from public.workspaces w where w.id = v_g.workspace_id),
    'billed_as', (select nullif(btrim(concat_ws(' ', nullif(b.company, ''),
                                 nullif(btrim(concat_ws(' ', b.first_name, b.last_name)), ''))), '')
                    from public.billing_parties b where b.member_id = v_g.financial_subject_id),
    'purpose', v_g.purpose,
    'accepted', v_g.principal_user_id is not null,
    'expires_at', v_g.expires_at);
end
$fn$;
revoke execute on function public.billing_access_preview_v1(text) from public, anon;
grant execute on function public.billing_access_preview_v1(text) to authenticated;

create or replace function public.billing_access_accept_v1(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_g public.billing_access_grants;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  select g.* into v_g from public.billing_access_grants g
   where g.code = upper(btrim(coalesce(p_code, ''))) for update;
  -- A replay by the account that accepted it answers the same grant.
  if v_g.id is not null and v_g.revoked_at is null and v_g.principal_user_id = auth.uid() then
    return jsonb_build_object('grant_id', v_g.id, 'workspace_id', v_g.workspace_id,
                              'financial_subject_id', v_g.financial_subject_id, 'replayed', true);
  end if;
  if v_g.id is null or v_g.revoked_at is not null or v_g.principal_user_id is not null
     or v_g.expires_at <= now() then
    raise exception 'this invitation cannot be used' using errcode = 'DKH01';
  end if;
  -- An account holds one live grant per subject: a second invitation of the same subject to the same account is
  -- answered by the grant it already holds, and the newer code is spent.
  if exists (select 1 from public.billing_access_grants o
              where o.workspace_id = v_g.workspace_id and o.financial_subject_id = v_g.financial_subject_id
                and o.principal_user_id = auth.uid() and o.revoked_at is null) then
    update public.billing_access_grants set revoked_at = now(), revoked_by_user_id = auth.uid(),
           revoke_reason = 'already held by this account'
     where id = v_g.id;
    return (select jsonb_build_object('grant_id', o.id, 'workspace_id', o.workspace_id,
                                      'financial_subject_id', o.financial_subject_id, 'replayed', true)
              from public.billing_access_grants o
             where o.workspace_id = v_g.workspace_id and o.financial_subject_id = v_g.financial_subject_id
               and o.principal_user_id = auth.uid() and o.revoked_at is null);
  end if;
  update public.billing_access_grants set principal_user_id = auth.uid(), accepted_at = now()
   where id = v_g.id;
  return jsonb_build_object('grant_id', v_g.id, 'workspace_id', v_g.workspace_id,
                            'financial_subject_id', v_g.financial_subject_id, 'replayed', false);
end
$fn$;
revoke execute on function public.billing_access_accept_v1(text) from public, anon;
grant execute on function public.billing_access_accept_v1(text) to authenticated;

-- ── 5. revocation: the seller, or the account itself ────────────────────
create or replace function public.billing_access_revoke_v1(p_grant_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_g public.billing_access_grants;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  select g.* into v_g from public.billing_access_grants g where g.id = p_grant_id for update;
  if v_g.id is null then
    raise exception 'unknown access grant' using errcode = 'DKH03';
  end if;
  if v_g.principal_user_id is distinct from auth.uid() then
    perform public.billing_manage_guard(v_g.workspace_id);
  end if;
  if v_g.revoked_at is not null then
    return jsonb_build_object('grant_id', v_g.id, 'revoked_at', v_g.revoked_at, 'replayed', true);
  end if;
  update public.billing_access_grants
     set revoked_at = now(), revoked_by_user_id = auth.uid(), revoke_reason = left(btrim(coalesce(p_reason, '')), 500)
   where id = v_g.id
  returning * into v_g;
  return jsonb_build_object('grant_id', v_g.id, 'revoked_at', v_g.revoked_at, 'replayed', false);
end
$fn$;
revoke execute on function public.billing_access_revoke_v1(uuid, text) from public, anon;
grant execute on function public.billing_access_revoke_v1(uuid, text) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(910);
