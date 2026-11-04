-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0676 (#3307, PR B) -- a purchase order e-mailed to its supplier through
-- the space's own Resend sender.
--
--   * `purchase_order_mail_settings`: per space, the sender address and name
--     the orders leave from (an address of a domain the space verified at
--     Resend; Resend refuses any other, and that refusal is recorded) and
--     whether an API key is stored. The key itself lives in Vault under
--     `purchase-order-mail:<space>`, written by
--     `save_purchase_order_mail_settings_v1` (manageBilling) and read back
--     only by the service role (`purchase_order_mail_key_resolved`); it never
--     reaches a client, nor any answer.
--   * `purchase_order_sends`: one row per attempt, its id the provider's
--     idempotency key. `begin_purchase_order_send_v1` (the buyer's session,
--     through the send function) opens one for a draft that names its
--     recipient, while the mail is configured; a pending or unconfirmed
--     attempt blocks another, so an order is never sent twice blindly. The
--     same attempt id replays. `finish_purchase_order_send` (service role)
--     records the outcome: accepted (the provider's id; the order is sent,
--     by e-mail), refused (the reason; the order stays a draft) or
--     unconfirmed (a timeout or a 5xx: nobody knows whether it left).
--   * `resolve_purchase_order_send_v1` (managePurchases): a person who
--     checked the supplier or the provider decides an unconfirmed attempt:
--     delivered (the order is sent) or not delivered (a new send may go).

create table public.purchase_order_mail_settings (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  sender_email text not null check (char_length(sender_email) <= 254),
  sender_name text not null default '' check (char_length(sender_name) <= 120),
  has_api_key boolean not null default false,
  revision int not null default 1 check (revision >= 1)
);
select public.ensure_system_columns('purchase_order_mail_settings');

create table public.purchase_order_sends (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  order_id uuid not null references public.purchase_orders(id) on delete cascade,
  state text not null default 'pending'
    check (state in ('pending', 'accepted', 'refused', 'unconfirmed', 'delivered', 'not_delivered')),
  recipient text not null check (char_length(recipient) <= 254),
  provider_id text not null default '' check (char_length(provider_id) <= 200),
  reason text not null default '' check (char_length(reason) <= 300),
  actor_member_id uuid not null,
  finished_at timestamptz,
  resolved_by_member_id uuid,
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('purchase_order_sends');
-- An order has at most one attempt that may have left.
create unique index purchase_order_sends_one_open
  on public.purchase_order_sends (order_id)
  where state in ('pending', 'unconfirmed', 'accepted', 'delivered');
create index purchase_order_sends_order on public.purchase_order_sends (order_id);

alter table public.purchase_order_mail_settings enable row level security;
alter table public.purchase_order_sends enable row level security;
revoke all on public.purchase_order_mail_settings, public.purchase_order_sends
  from public, anon, authenticated;
grant select on public.purchase_order_mail_settings, public.purchase_order_sends to authenticated;
create policy purchase_order_mail_settings_select on public.purchase_order_mail_settings
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageBilling', 'managePurchases'])));
create policy purchase_order_sends_select on public.purchase_order_sends for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['managePurchases', 'viewFinances'])));
create policy mcp_delegated_deny on public.purchase_order_mail_settings as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.purchase_order_sends as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.purchase_order_mail_secret_name(p_workspace_id uuid)
returns text language sql immutable as $fn$
  select 'purchase-order-mail:' || p_workspace_id::text;
$fn$;
revoke execute on function public.purchase_order_mail_secret_name(uuid) from public, anon, authenticated;

create or replace function public.save_purchase_order_mail_settings_v1(
  p_workspace_id uuid, p_sender_email text, p_sender_name text, p_api_key text, p_revision int
) returns jsonb language plpgsql security definer set search_path = public, vault as $fn$
declare
  v_email text := btrim(coalesce(p_sender_email, ''));
  v_name text := btrim(coalesce(p_sender_name, ''));
  v_key text := nullif(btrim(coalesce(p_api_key, '')), '');
  v_row public.purchase_order_mail_settings;
  v_secret uuid;
  v_secret_name text := public.purchase_order_mail_secret_name(p_workspace_id);
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'not allowed to configure how this space sends its orders' using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'purchaseOrders') then
    raise exception 'purchase orders are switched off in this space' using errcode = '42501';
  end if;
  if v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or v_email ~ '[\r\n]' or char_length(v_email) > 254 then
    raise exception 'the sender is not an e-mail address' using errcode = '22023';
  end if;
  if v_name ~ '[\r\n<>"]' or char_length(v_name) > 120 then
    raise exception 'the sender''s name holds characters a mail header cannot carry' using errcode = '22023';
  end if;
  if v_key is not null and (v_key !~ '^[A-Za-z0-9_\-]{8,200}$') then
    raise exception 'this is not an API key' using errcode = '22023';
  end if;
  select * into v_row from public.purchase_order_mail_settings
   where workspace_id = p_workspace_id for update;
  if v_row.workspace_id is not null and v_row.revision <> coalesce(p_revision, -1) then
    raise exception 'stale revision' using errcode = '40001';
  end if;
  if v_row.workspace_id is null and v_key is null then
    raise exception 'the first configuration brings its API key' using errcode = '22023';
  end if;
  if v_key is not null then
    select id into v_secret from vault.secrets where name = v_secret_name;
    if v_secret is null then
      perform vault.create_secret(v_key, v_secret_name, 'DesKilo purchase order mail API key');
    else
      perform vault.update_secret(v_secret, v_key);
    end if;
  end if;
  insert into public.purchase_order_mail_settings (workspace_id, sender_email, sender_name, has_api_key)
  values (p_workspace_id, v_email, v_name, true)
  on conflict (workspace_id) do update
    set sender_email = excluded.sender_email, sender_name = excluded.sender_name,
        has_api_key = true, revision = public.purchase_order_mail_settings.revision + 1
  returning * into v_row;
  return jsonb_build_object('sender_email', v_row.sender_email, 'sender_name', v_row.sender_name,
                            'has_api_key', v_row.has_api_key, 'revision', v_row.revision);
end;
$fn$;
revoke execute on function public.save_purchase_order_mail_settings_v1(uuid, text, text, text, int) from public, anon;
grant execute on function public.save_purchase_order_mail_settings_v1(uuid, text, text, text, int) to authenticated;

-- The key and the sender, for the send function only.
create or replace function public.purchase_order_mail_key_resolved(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, vault as $fn$
declare
  v_row public.purchase_order_mail_settings;
  v_key text;
begin
  select * into v_row from public.purchase_order_mail_settings where workspace_id = p_workspace_id;
  if v_row.workspace_id is null or not v_row.has_api_key then return null; end if;
  select decrypted_secret into v_key from vault.decrypted_secrets
   where name = public.purchase_order_mail_secret_name(p_workspace_id);
  if v_key is null then return null; end if;
  return jsonb_build_object('api_key', v_key, 'sender_email', v_row.sender_email,
                            'sender_name', v_row.sender_name);
end;
$fn$;
revoke execute on function public.purchase_order_mail_key_resolved(uuid) from public, anon, authenticated;
grant execute on function public.purchase_order_mail_key_resolved(uuid) to service_role;

create or replace function public.purchase_order_send_json(p_send uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('id', s.id, 'order_id', s.order_id, 'state', s.state,
    'recipient', s.recipient, 'provider_id', s.provider_id, 'reason', s.reason,
    'created_at', s.created_datetime, 'finished_at', s.finished_at)
    from public.purchase_order_sends s where s.id = p_send;
$fn$;
revoke execute on function public.purchase_order_send_json(uuid) from public, anon, authenticated;

create or replace function public.begin_purchase_order_send_v1(
  p_workspace_id uuid, p_order_id uuid, p_revision int, p_attempt_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_order public.purchase_orders;
  v_send public.purchase_order_sends;
begin
  v_me := public.purchase_order_actor(p_workspace_id);
  if p_attempt_id is null then raise exception 'an attempt id is required' using errcode = '22023'; end if;
  select * into v_send from public.purchase_order_sends where id = p_attempt_id;
  if v_send.id is not null then
    if v_send.workspace_id <> p_workspace_id or v_send.order_id <> p_order_id then
      raise exception 'this attempt id was already used for another order' using errcode = '22023';
    end if;
    return public.purchase_order_send_json(v_send.id);
  end if;
  select * into v_order from public.purchase_orders
   where id = p_order_id and workspace_id = p_workspace_id for update;
  if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
  if v_order.state <> 'draft' then
    raise exception 'only a draft purchase order is sent' using errcode = '22023';
  end if;
  if v_order.revision <> coalesce(p_revision, -1) then
    raise exception 'stale revision' using errcode = '40001';
  end if;
  if v_order.recipient_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or v_order.recipient_email ~ '[\r\n]' then
    raise exception 'the order names no address to e-mail it to' using errcode = '22023';
  end if;
  if not exists (select 1 from public.purchase_order_mail_settings m
                  where m.workspace_id = p_workspace_id and m.has_api_key) then
    raise exception 'this space has not configured how it e-mails its orders' using errcode = '22023';
  end if;
  if exists (select 1 from public.purchase_order_sends s
              where s.order_id = p_order_id and s.state in ('pending', 'unconfirmed')) then
    raise exception 'an earlier send of this order has no confirmed outcome: check before sending again'
      using errcode = '55000';
  end if;
  insert into public.purchase_order_sends (id, workspace_id, order_id, recipient, actor_member_id)
  values (p_attempt_id, p_workspace_id, p_order_id, btrim(v_order.recipient_email), v_me)
  returning * into v_send;
  return public.purchase_order_send_json(v_send.id);
end;
$fn$;
revoke execute on function public.begin_purchase_order_send_v1(uuid, uuid, int, uuid) from public, anon;
grant execute on function public.begin_purchase_order_send_v1(uuid, uuid, int, uuid) to authenticated;

-- The provider's answer, recorded by the send function (service role).
create or replace function public.finish_purchase_order_send(
  p_attempt_id uuid, p_outcome text, p_provider_id text, p_reason text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_send public.purchase_order_sends;
begin
  if p_outcome not in ('accepted', 'refused', 'unconfirmed') then
    raise exception 'unknown outcome %', p_outcome using errcode = '22023';
  end if;
  select * into v_send from public.purchase_order_sends where id = p_attempt_id for update;
  if v_send.id is null then raise exception 'unknown send attempt' using errcode = '22023'; end if;
  -- An outcome is recorded once; a repeat of the same answer is a replay.
  if v_send.state <> 'pending' then
    if v_send.state = p_outcome then return public.purchase_order_send_json(v_send.id); end if;
    raise exception 'this attempt already has its outcome' using errcode = '55000';
  end if;
  update public.purchase_order_sends
     set state = p_outcome, provider_id = left(coalesce(p_provider_id, ''), 200),
         reason = left(coalesce(p_reason, ''), 300), finished_at = now()
   where id = v_send.id;
  if p_outcome = 'accepted' then
    update public.purchase_orders
       set state = 'sent', sent_at = now(), sent_via = 'email', revision = revision + 1
     where id = v_send.order_id and state = 'draft';
  end if;
  return public.purchase_order_send_json(v_send.id);
end;
$fn$;
revoke execute on function public.finish_purchase_order_send(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finish_purchase_order_send(uuid, text, text, text) to service_role;

-- A person decides an attempt nobody could confirm.
create or replace function public.resolve_purchase_order_send_v1(
  p_workspace_id uuid, p_attempt_id uuid, p_delivered boolean
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_send public.purchase_order_sends;
begin
  v_me := public.purchase_order_actor(p_workspace_id);
  select * into v_send from public.purchase_order_sends
   where id = p_attempt_id and workspace_id = p_workspace_id for update;
  if v_send.id is null then raise exception 'unknown send attempt' using errcode = '22023'; end if;
  if v_send.state <> 'unconfirmed' then
    raise exception 'only an unconfirmed send is decided by hand' using errcode = '22023';
  end if;
  update public.purchase_order_sends
     set state = case when p_delivered then 'delivered' else 'not_delivered' end,
         resolved_by_member_id = v_me
   where id = v_send.id;
  if p_delivered then
    update public.purchase_orders
       set state = 'sent', sent_at = coalesce(v_send.finished_at, now()), sent_via = 'email',
           revision = revision + 1
     where id = v_send.order_id and state = 'draft';
  end if;
  return public.purchase_order_send_json(v_send.id);
end;
$fn$;
revoke execute on function public.resolve_purchase_order_send_v1(uuid, uuid, boolean) from public, anon;
grant execute on function public.resolve_purchase_order_send_v1(uuid, uuid, boolean) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(676);
