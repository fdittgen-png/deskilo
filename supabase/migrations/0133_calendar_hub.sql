-- SPDX-License-Identifier: 0BSD
-- 0133 — the calendar hub (#718) and the access log behind it (#719).
--
-- ONE QUESTION, ONE ANSWER. "What happened, or is due, between these
-- dates — for me, or for a member I am allowed to look at?" used to be
-- answered by six screens with six rules. `calendar_items` answers it
-- once, in SQL, applying every rule the tables already enforce:
--
--   reservations   any active member of the workspace (occupancy is
--                  public inside a workspace — the plan shows it)
--   events         the feed's rule: actor, subject, or an admin
--   messages       PARTICIPANTS of the conversation and nobody else,
--                  whatever their role (0125's in_conversation)
--   invoices, payments, consumption
--                  self, or may_view_member_finances() (0131)
--   reminders      self only — a reminder is addressed to one person
--
-- The client never widens: a kind the caller may not see for the
-- member they asked about comes back as `locked: true` with no rows,
-- so the screen can SAY it is locked instead of showing an empty list
-- that reads like "nothing happened".
--
-- THE ACCESS LOG (GDPR art. 15 and 30). Whenever a member reads another
-- member's finances or messages through this function, one row says who
-- read what category about whom, when. The subject can see every row
-- about themselves; a member with manageMembers can see the workspace's.
-- Written from inside the SECURITY DEFINER function, so it cannot be
-- skipped by a client that forgets.

-- ---------------------------------------------------------------- 1
-- The log.

create table if not exists public.data_access_log (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  actor_member_id uuid not null references public.members(id) on delete cascade,
  subject_member_id uuid not null references public.members(id) on delete cascade,
  category text not null check (category in ('finances', 'messages', 'export')),
  at timestamptz not null default now()
);
create index if not exists data_access_log_subject_idx
  on public.data_access_log (subject_member_id, at desc);
create index if not exists data_access_log_workspace_idx
  on public.data_access_log (workspace_id, at desc);

alter table public.data_access_log enable row level security;

drop policy if exists data_access_log_select on public.data_access_log;
create policy data_access_log_select on public.data_access_log
  for select using (
    exists (select 1 from public.members m
             where m.id = subject_member_id and m.user_id = auth.uid())
    or public.has_permission(workspace_id, 'manageMembers')
  );
-- No insert/update/delete policies: only the definer functions write,
-- and nobody edits history.

-- ---------------------------------------------------------------- 2
-- The hub.

create or replace function public.calendar_items(
  p_workspace_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_kinds text[] default null,
  p_member_id uuid default null
) returns jsonb language plpgsql volatile security definer
-- VOLATILE, not stable: it WRITES the access log. A stable function
-- may not insert, and the rehearsal on the live database said so.
set search_path = public as $$
declare
  v_me public.members;
  v_subject uuid;
  v_self boolean;
  v_admin boolean;
  v_money boolean;
  v_want text[];
  v_items jsonb := '[]'::jsonb;
  v_locked text[] := '{}';
  v_rows jsonb;
begin
  v_me := public.my_active_member(p_workspace_id);
  v_subject := coalesce(p_member_id, v_me.id);
  v_self := v_subject = v_me.id;
  v_admin := public.is_admin_of(p_workspace_id);
  v_money := v_self or public.may_view_member_finances(v_subject);
  v_want := coalesce(p_kinds, array['reservation','checkin','checkout','event',
                                     'message','invoice','payment','consumption','reminder']);
  if p_to <= p_from or p_to - p_from > interval '400 days' then
    raise exception 'calendar range must be positive and at most 400 days';
  end if;
  if not exists (select 1 from public.members where id = v_subject
                   and workspace_id = p_workspace_id) then
    raise exception 'no such member';
  end if;

  -- reservations, check-ins, check-outs ────────────────────────────
  if v_want && array['reservation','checkin','checkout'] then
    select coalesce(jsonb_agg(x order by x->>'at'), '[]'::jsonb) into v_rows from (
      select jsonb_build_object(
        'kind', 'reservation', 'id', r.id, 'at', r.starts_at, 'until', r.ends_at,
        'member_id', r.member_id, 'title', coalesce(r.space_label, ''),
        'status', r.status, 'link', jsonb_build_object('type','reservation','id', r.id)) x
        from public.reservations r
       where r.workspace_id = p_workspace_id and r.member_id = v_subject
         and r.status <> 'cancelled'
         and r.starts_at < p_to and r.ends_at > p_from
         and 'reservation' = any(v_want)
      union all
      select jsonb_build_object(
        'kind', 'checkin', 'id', r.id || ':in', 'at', r.checked_in_at,
        'member_id', r.member_id, 'title', coalesce(r.space_label, ''),
        'link', jsonb_build_object('type','reservation','id', r.id))
        from public.reservations r
       where r.workspace_id = p_workspace_id and r.member_id = v_subject
         and r.checked_in_at >= p_from and r.checked_in_at < p_to
         and 'checkin' = any(v_want)
      union all
      select jsonb_build_object(
        'kind', 'checkout', 'id', r.id || ':out', 'at', r.checked_out_at,
        'member_id', r.member_id, 'title', coalesce(r.space_label, ''),
        'link', jsonb_build_object('type','reservation','id', r.id))
        from public.reservations r
       where r.workspace_id = p_workspace_id and r.member_id = v_subject
         and r.checked_out_at >= p_from and r.checked_out_at < p_to
         and 'checkout' = any(v_want)
    ) s;
    v_items := v_items || v_rows;
  end if;

  -- reminders: upcoming own reservations, as the device schedules them
  if 'reminder' = any(v_want) then
    if v_self then
      select coalesce(jsonb_agg(jsonb_build_object(
        'kind', 'reminder', 'id', r.id || ':rem', 'at', r.starts_at - interval '15 minutes',
        'member_id', r.member_id, 'title', coalesce(r.space_label, ''),
        'link', jsonb_build_object('type','reservation','id', r.id))
        order by r.starts_at), '[]'::jsonb) into v_rows
        from public.reservations r
       where r.workspace_id = p_workspace_id and r.member_id = v_subject
         and r.status = 'reserved' and r.starts_at > now()
         and r.starts_at - interval '15 minutes' >= p_from
         and r.starts_at - interval '15 minutes' < p_to;
      v_items := v_items || v_rows;
    else
      v_locked := array_append(v_locked, 'reminder');
    end if;
  end if;

  -- events: the feed's rule
  if 'event' = any(v_want) then
    select coalesce(jsonb_agg(jsonb_build_object(
      'kind', 'event', 'id', e.id, 'at', e.created_at,
      'member_id', coalesce(e.subject_member_id, e.actor_member_id),
      'title', e.type || '.' || e.action, 'status', e.status,
      'payload', e.payload,
      'link', jsonb_build_object('type','event','id', e.id)) order by e.created_at), '[]'::jsonb)
      into v_rows
      from public.events e
     where e.workspace_id = p_workspace_id
       and e.created_at >= p_from and e.created_at < p_to
       and (e.actor_member_id = v_subject or e.subject_member_id = v_subject)
       and (v_admin or e.actor_member_id = v_me.id or e.subject_member_id = v_me.id);
    v_items := v_items || v_rows;
  end if;

  -- messages: participants only, whatever the role
  if 'message' = any(v_want) then
    if v_self then
      select coalesce(jsonb_agg(jsonb_build_object(
        'kind', 'message', 'id', n.id, 'at', n.created_at,
        'member_id', n.from_member_id,
        'title', coalesce(c.title, ''), 'body', left(n.body, 120),
        'link', jsonb_build_object('type','conversation','id', n.conversation_id))
        order by n.created_at), '[]'::jsonb) into v_rows
        from public.member_notes n
        left join public.conversations c on c.id = n.conversation_id
       where n.workspace_id = p_workspace_id
         and n.created_at >= p_from and n.created_at < p_to
         and n.conversation_id is not null
         and public.in_conversation(n.conversation_id);
      v_items := v_items || v_rows;
    else
      -- Another member's messages: only those in conversations I am
      -- ALSO in — which is exactly what I could read in the thread.
      select coalesce(jsonb_agg(jsonb_build_object(
        'kind', 'message', 'id', n.id, 'at', n.created_at,
        'member_id', n.from_member_id,
        'title', coalesce(c.title, ''), 'body', left(n.body, 120),
        'link', jsonb_build_object('type','conversation','id', n.conversation_id))
        order by n.created_at), '[]'::jsonb) into v_rows
        from public.member_notes n
        left join public.conversations c on c.id = n.conversation_id
       where n.workspace_id = p_workspace_id
         and n.created_at >= p_from and n.created_at < p_to
         and n.from_member_id = v_subject
         and n.conversation_id is not null
         and public.in_conversation(n.conversation_id);
      v_items := v_items || v_rows;
      if jsonb_array_length(v_rows) = 0 then v_locked := array_append(v_locked, 'message'); end if;
    end if;
  end if;

  -- money: self or the finance permission; logged when it is not self
  if v_want && array['invoice','payment','consumption'] then
    if v_money then
      if not v_self then
        insert into public.data_access_log
          (workspace_id, actor_member_id, subject_member_id, category)
        values (p_workspace_id, v_me.id, v_subject, 'finances');
      end if;
      select coalesce(jsonb_agg(x order by x->>'at'), '[]'::jsonb) into v_rows from (
        select jsonb_build_object(
          'kind', 'invoice', 'id', i.id, 'at', i.issued_at, 'member_id', i.member_id,
          'title', i.number, 'amount_cents', i.total_cents, 'currency', i.currency,
          'status', case when i.voided_at is not null then 'voided' else 'issued' end,
          'link', jsonb_build_object('type','invoice','id', i.id)) x
          from public.invoices i
         where i.workspace_id = p_workspace_id and i.member_id = v_subject
           and i.issued_at >= p_from and i.issued_at < p_to
           and 'invoice' = any(v_want)
        union all
        select jsonb_build_object(
          'kind', case when le.category = 'payment' then 'payment' else 'consumption' end,
          'id', le.id, 'at', coalesce(le.occurred_on::timestamptz, le.created_at),
          'member_id', le.member_id, 'title', le.description,
          'amount_cents', case when le.kind = 'credit' then le.amount_cents else -le.amount_cents end,
          'category', le.category, 'period', le.period,
          'link', jsonb_build_object('type','ledger','period', le.period))
          from public.ledger_entries le
         where le.workspace_id = p_workspace_id and le.member_id = v_subject
           and coalesce(le.occurred_on::timestamptz, le.created_at) >= p_from
           and coalesce(le.occurred_on::timestamptz, le.created_at) < p_to
           and ((le.category = 'payment' and 'payment' = any(v_want))
             or (le.category <> 'payment' and 'consumption' = any(v_want)))
      ) s;
      v_items := v_items || v_rows;
    else
      v_locked := v_locked || array['invoice','payment','consumption'];
    end if;
  end if;

  return jsonb_build_object(
    'subject_member_id', v_subject,
    'locked', to_jsonb(v_locked),
    'items', v_items
  );
end;
$$;

-- ---------------------------------------------------------------- 3
-- "Who can see my data": the concrete people, not just the rule. The
-- matrix (role_permissions) says which ROLE holds a permission; this
-- names the members currently in such a role, so the answer is a list
-- of faces rather than a policy document.

create or replace function public.who_can_access_me(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer
set search_path = public as $$
declare
  v_me public.members;
begin
  v_me := public.my_active_member(p_workspace_id);
  return jsonb_build_object(
    'finances', (
      select coalesce(jsonb_agg(m.id), '[]'::jsonb) from public.members m
       where m.workspace_id = p_workspace_id and m.status = 'active' and m.id <> v_me.id
         and (m.is_owner or m.co_owner = 'active' or m.is_admin)
    ),
    'members_admin', (
      select coalesce(jsonb_agg(m.id), '[]'::jsonb) from public.members m
       where m.workspace_id = p_workspace_id and m.status = 'active' and m.id <> v_me.id
         and (m.is_owner or m.co_owner = 'active' or m.is_admin)
    ),
    'reservations', 'all_members',
    'messages', 'participants_only'
  );
end;
$$;

-- ---------------------------------------------------------------- 4
-- Art. 20 — take your data with you. Everything the member is the
-- subject of, as one JSON document. Logged as an export.

create or replace function public.export_my_data(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer
set search_path = public as $$
declare
  v_me public.members;
begin
  v_me := public.my_active_member(p_workspace_id);
  return jsonb_build_object(
    'exported_at', now(),
    'member', to_jsonb(v_me) - 'user_id',
    'profile', (select to_jsonb(p) - 'pin_hash' from public.profiles p where p.id = v_me.user_id),
    'reservations', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.reservations r
                      where r.member_id = v_me.id),
    'ledger', (select coalesce(jsonb_agg(to_jsonb(l)), '[]') from public.ledger_entries l
                where l.member_id = v_me.id),
    'invoices', (select coalesce(jsonb_agg(to_jsonb(i)), '[]') from public.invoices i
                  where i.member_id = v_me.id),
    'messages_sent', (select coalesce(jsonb_agg(to_jsonb(n)), '[]') from public.member_notes n
                       where n.from_member_id = v_me.id),
    'events', (select coalesce(jsonb_agg(to_jsonb(e)), '[]') from public.events e
                where e.actor_member_id = v_me.id or e.subject_member_id = v_me.id),
    'access_log', (select coalesce(jsonb_agg(to_jsonb(a)), '[]') from public.data_access_log a
                    where a.subject_member_id = v_me.id)
  );
end;
$$;

-- ---------------------------------------------------------------- 5
-- Art. 17 — erasure, within what the books may keep. The member row
-- leaves the workspace (status exited), open reservations are cancelled,
-- messages they sent are deleted, and the profile's personal fields are
-- cleared. Ledger and invoices stay: they are the workspace's accounting
-- records, kept under the legal retention the policy names, and they
-- reference the member id, which is a key, not a name.

create or replace function public.erase_my_membership(p_workspace_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  v_me public.members;
begin
  v_me := public.my_active_member(p_workspace_id);
  if v_me.is_owner then
    raise exception 'an owner must hand the workspace over before leaving';
  end if;
  update public.reservations set status = 'cancelled'
   where member_id = v_me.id and status in ('reserved', 'checked_in');
  -- DELETED, not blanked: member_notes.body has a non-empty check (0089),
  -- and a placeholder would be one more string to localise. Erasure is
  -- erasure; the conversation itself stays for the other participants.
  delete from public.member_notes where from_member_id = v_me.id;
  update public.members set status = 'exited', is_admin = false
   where id = v_me.id;
  -- The profile is shared across workspaces; only clear it when this
  -- was the last active membership.
  if not exists (select 1 from public.members
                  where user_id = v_me.user_id and status = 'active') then
    update public.profiles
       set display_name = '', whatsapp = '', status_text = '', address = '',
           vat_id = '', avatar_path = null
     where id = v_me.user_id;
  end if;
end;
$$;

notify pgrst, 'reload schema';
