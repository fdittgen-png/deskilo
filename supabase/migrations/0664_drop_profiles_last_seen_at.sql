-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: destructive
-- backup: the heartbeat lives in public.presence since 0616; this file first
-- copies any value profiles.last_seen_at still holds into it (keeping the
-- later of the two), so the drop loses no heartbeat. The column held nothing
-- else (no policy, view, index, constraint or function body reads it: a drop
-- without CASCADE would refuse otherwise).
--
-- #3141 (the contract step of #3123): no supported app reads
-- profiles.last_seen_at any more, so the column goes. The projections answer
-- last_seen_at from presence; the heartbeat (touch_last_seen) writes presence.

insert into public.presence (user_id, last_seen_at)
select p.id, p.last_seen_at
  from public.profiles p
 where p.last_seen_at is not null
   and exists (select 1 from auth.users u where u.id = p.id)
on conflict (user_id) do update
   set last_seen_at = greatest(public.presence.last_seen_at, excluded.last_seen_at);

alter table public.profiles drop column last_seen_at;

select public.set_deskilo_schema_version(664);
