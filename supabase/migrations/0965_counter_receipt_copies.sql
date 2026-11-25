-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4476 -- a copy of a counter receipt: printed again, marked as a copy and counted, never numbered again.
--
--   counter_receipt_copies       one row per copy of a finalized receipt: its number among the copies (1, 2, ...), who
--                                printed it and under which request. Never edited or deleted. Who printed it is a member
--                                reference: an erasure leaves the member row (exited, its personal data cleared), so the
--                                count of copies stays and the reference no longer names anyone.
--   counter_receipt_copy_v1      who works the counter (issueInvoices, where counter receipts are on) prints a copy of a
--                                finalized receipt of the business; anything else is refused (DKL04 {"reason": "receipt"});
--                                the same request answers the same copy again.

create table public.counter_receipt_copies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  receipt_id uuid not null,
  copy_no int not null check (copy_no >= 1),
  actor_member_id uuid not null,
  request_id uuid not null,
  unique (workspace_id, id),
  unique (workspace_id, receipt_id, copy_no),
  unique (workspace_id, request_id),
  foreign key (workspace_id, receipt_id) references public.counter_receipts (workspace_id, id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_receipt_copies');

create or replace function public.counter_receipt_copies_frozen() returns trigger
language plpgsql set search_path = public as $fn$
begin
  raise exception 'a copy of a receipt is never edited or deleted' using errcode = 'DKL03';
end;
$fn$;
revoke execute on function public.counter_receipt_copies_frozen() from public, anon, authenticated;
create trigger counter_receipt_copies_frozen before update or delete on public.counter_receipt_copies
  for each row execute function public.counter_receipt_copies_frozen();

alter table public.counter_receipt_copies enable row level security;
revoke all on public.counter_receipt_copies from public, anon, authenticated;
grant select on public.counter_receipt_copies to authenticated;
create policy counter_receipt_copies_select on public.counter_receipt_copies for select to authenticated
  using (public.feature_effective(workspace_id, 'counterReceipts')
         and workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances'])));
create policy mcp_delegated_deny on public.counter_receipt_copies as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.counter_receipt_copy_v1(
  p_workspace_id uuid,
  p_request_id uuid,
  p_receipt_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text := md5(coalesce(p_receipt_id::text, ''));
  v_done jsonb;
  v_no int;
begin
  v_me := public.command_actor(p_workspace_id, 'issueInvoices', 'counterReceipts', 'not allowed to work the counter',
    'counter receipts are off in this business', 'DKG01');
  if p_request_id is null then
    raise exception 'a copy is printed under a request id' using errcode = '22023';
  end if;
  v_done := public.request_begin(p_workspace_id, p_request_id, 'counter_receipt_copy', v_digest);
  if v_done is not null then
    return v_done || '{"replayed": true}'::jsonb;
  end if;
  if not exists (select 1 from public.counter_receipts r
                  where r.id = p_receipt_id and r.workspace_id = p_workspace_id and r.state = 'finalized') then
    raise exception 'only a finalized receipt of this business has copies' using errcode = 'DKL04', detail = '{"reason": "receipt"}';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('counter_receipt_copy:' || p_receipt_id::text, 0));
  select coalesce(max(c.copy_no), 0) + 1 into v_no from public.counter_receipt_copies c
   where c.workspace_id = p_workspace_id and c.receipt_id = p_receipt_id;
  insert into public.counter_receipt_copies (workspace_id, receipt_id, copy_no, actor_member_id, request_id)
  values (p_workspace_id, p_receipt_id, v_no, v_me, p_request_id);
  return public.request_finish(p_workspace_id, p_request_id, 'counter_receipt_copy', v_digest,
    jsonb_build_object('receipt_id', p_receipt_id, 'copy_no', v_no)) || '{"replayed": false}'::jsonb;
end
$fn$;
revoke execute on function public.counter_receipt_copy_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.counter_receipt_copy_v1(uuid, uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(965);
