-- SPDX-License-Identifier: 0BSD
-- 0125 — CONVERSATIONS (#687): the messaging centre grows groups.
--
-- Until now a message was a `member_notes` row addressed to one member,
-- or to `null` meaning "every admin". That carries a 1:1 thread fine and
-- cannot carry a group at all: there is nowhere to hang a name, a photo,
-- or the list of who is in it.
--
-- So a conversation becomes a THING, and a message points at it.
--
-- WHY DIRECT THREADS GET A ROW TOO, rather than staying implicit in the
-- pair of member ids. A conversation list has to sort by last activity
-- and show an unread count per row; doing that over an implicit pairing
-- means re-deriving the pair on every query, in every place, forever.
-- One row per thread makes "order by last_message_at" a plain index
-- scan. Direct rows are created on demand and are invisible in the UI —
-- nobody names or leaves a direct thread.
--
-- WHAT IS DELIBERATELY NOT HERE: attachments. No image column, no
-- document path, no storage bucket for message media. The owner asked
-- for that explicitly, and it is also the honest default for a
-- workspace tool — a coworking app that accepts arbitrary uploads
-- becomes a file host with none of the retention, scanning or takedown
-- machinery that implies. Reservation and space references (#622) are
-- already carried inside the body text as `[res:…]` / `[space:…]`, and
-- that is the whole attachment story.

-- ---------------------------------------------------------------- 1
-- The conversation.

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id)
    on delete cascade,
  -- 'direct' = exactly two participants, unnamed, created on demand.
  -- 'group'  = named, any number of participants, has an owner.
  kind text not null check (kind in ('direct', 'group')),
  -- Groups only. A direct thread is titled by the other person's name,
  -- which is not ours to snapshot — it changes when they rename.
  title text check (
    (kind = 'group' and length(btrim(coalesce(title, ''))) between 1 and 80)
    or (kind = 'direct' and title is null)
  ),
  -- Object path in the `avatars` bucket, same convention as a profile
  -- photo (0038). Null renders initials, exactly like a member with no
  -- photo — no separate "no image" state to design.
  avatar_path text,
  created_by uuid not null references public.members(id) on delete cascade,
  created_at timestamptz not null default now(),
  -- DENORMALISED on purpose: the conversation list sorts by it on every
  -- open, and computing it from the messages table means a correlated
  -- subquery per row. Maintained by trigger below, never by clients.
  last_message_at timestamptz not null default now()
);

create index conversations_workspace
  on public.conversations (workspace_id, last_message_at desc);

-- ---------------------------------------------------------------- 2
-- Who is in it.

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations(id)
    on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  -- Group admins may rename, set the photo, add and remove. The creator
  -- starts as one. Direct threads ignore this entirely.
  is_admin boolean not null default false,
  joined_at timestamptz not null default now(),
  -- Leaving is a SOFT exit: the messages someone sent stay readable to
  -- the people they were sent to, and the group's history does not
  -- develop holes. A left participant reads nothing new.
  left_at timestamptz,
  -- When I last opened this conversation.
  --
  -- This is what makes a GROUP unread count possible at all. A direct
  -- message carries a per-message `read_at` (0105) because it has one
  -- recipient; a group message has many, and a receipt per reader per
  -- message would be a row explosion for a number nobody reads. A
  -- watermark answers "how many since I last looked", which is the only
  -- group question anyone actually asks.
  last_read_at timestamptz,
  primary key (conversation_id, member_id)
);

create index conversation_participants_member
  on public.conversation_participants (member_id)
  where left_at is null;

-- ---------------------------------------------------------------- 3
-- Messages point at a conversation.
--
-- Nullable, and it stays nullable: every pre-0125 note has no
-- conversation, and the admin BROADCAST (to_member_id null) is not a
-- conversation either — it is a fan-out to whoever is an admin at read
-- time, which is a different thing and keeps working unchanged.

alter table public.member_notes
  add column conversation_id uuid references public.conversations(id)
    on delete cascade;

create index member_notes_conversation
  on public.member_notes (conversation_id, created_at desc)
  where conversation_id is not null;

-- Full-text search over message bodies (#687).
--
-- 'simple' rather than a language configuration: the workspace's members
-- write in whatever they write in, and a French stemmer applied to
-- German text is worse than no stemmer at all. Prefix matching in the
-- client's query covers the "type three letters" case that a stemmer
-- would otherwise buy.
create index member_notes_body_fts
  on public.member_notes
  using gin (to_tsvector('simple', body));

-- ---------------------------------------------------------------- 4
-- RLS.

alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;

-- "Am I in this conversation?", as a SECURITY DEFINER function.
--
-- It has to be a function, and that is not a style choice. The roster
-- policy below needs to ask a question ABOUT conversation_participants
-- while guarding conversation_participants, and a policy that queries
-- its own table recurses — Postgres raises `infinite recursion detected
-- in policy`. SECURITY DEFINER runs the lookup outside RLS and breaks
-- the cycle.
--
-- STABLE, not VOLATILE: the planner may then call it once per query
-- rather than once per row, which for a roster of twenty is the
-- difference between one lookup and twenty.
create or replace function public.in_conversation(p_conversation_id uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1
      from public.conversation_participants p
      join public.members m on m.id = p.member_id
     where p.conversation_id = p_conversation_id
       and m.user_id = auth.uid()
       and m.status = 'active'
  );
$$;

-- A conversation is visible to its participants — including those who
-- left, so their own history stays readable.
create policy conversations_select on public.conversations
  for select using (public.in_conversation(id));

-- The roster is visible to anyone in the conversation: a group where you
-- cannot see who else is in it is a group you cannot use safely.
create policy conversation_participants_select
  on public.conversation_participants
  for select using (public.in_conversation(conversation_id));

-- No insert/update/delete policies on either table: every write goes
-- through the RPCs below, which is what lets "only a group admin may
-- add someone" be a single enforced rule rather than a client habit.

-- ---------------------------------------------------------------- 5
-- Keeping last_message_at true.

create or replace function public.touch_conversation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.conversation_id is not null then
    update public.conversations
       set last_message_at = new.created_at
     where id = new.conversation_id;
  end if;
  return new;
end;
$$;

create trigger member_notes_touch_conversation
  after insert on public.member_notes
  for each row execute function public.touch_conversation();
