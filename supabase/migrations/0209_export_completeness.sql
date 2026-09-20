-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1238 — the subject-access export covers the subject's data.
--
-- `export_my_data` returned eight tables. Twenty carry a `member_id` or
-- a `user_id`, and nothing recorded which of the other twelve were a
-- deliberate omission and which were simply forgotten. A subject-access
-- right is not "most of your data".
--
-- Six are added here, each because it is the MEMBER'S own record:
--
--   price_negotiations  the terms agreed between them and the workspace
--   quota_extensions    extra half-days granted to them
--   usage_records       what they consumed, and the basis of their bill
--   payment_intents     their own payments, including ones still pending
--                       (a settled one reaches the ledger; a pending one
--                       does not, so it was invisible to the export)
--   event_decisions     the decisions THEY made on other people's events
--   badges              that credentials exist, when issued and whether
--                       revoked — the HASH is deliberately withheld, so
--                       an export is never a way to obtain a credential
--
-- Six stay out, and `test/lint/gdpr_export_coverage_test.dart` carries
-- the reason for each: platform_admins and platform_access_log name
-- other people, push_endpoints is a rotating device credential,
-- conversation_participants names the other participants,
-- managed_identities belongs to the workspace until claimed, and the
-- expense schedule tables are workspace costs that merely record who
-- entered them.
--
-- A note on event_decisions: a member's decisions are theirs, and the
-- events those decisions were ABOUT may concern somebody else. Only the
-- decision rows are returned — the decision, its moment, and the event
-- id — never the other person's event body, which is already covered by
-- the `events` key for events that concern the subject.

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
                    where a.subject_member_id = v_me.id),
    -- #1238 — the six added.
    'price_negotiations', (select coalesce(jsonb_agg(to_jsonb(n)), '[]')
                            from public.price_negotiations n
                            where n.member_id = v_me.id),
    'quota_extensions', (select coalesce(jsonb_agg(to_jsonb(q)), '[]')
                          from public.quota_extensions q
                          where q.member_id = v_me.id),
    'usage_records', (select coalesce(jsonb_agg(to_jsonb(u)), '[]')
                       from public.usage_records u
                       where u.member_id = v_me.id),
    'payments', (select coalesce(jsonb_agg(to_jsonb(p)), '[]')
                  from public.payment_intents p
                  where p.member_id = v_me.id),
    'decisions_i_made', (select coalesce(jsonb_agg(to_jsonb(d)), '[]')
                          from public.event_decisions d
                          where d.member_id = v_me.id),
    -- The FACT of a credential, never the credential. A hash in an
    -- export is a hash on somebody's laptop.
    'badges', (select coalesce(jsonb_agg(jsonb_build_object(
                        'id', b.id,
                        'kind', b.kind,
                        'label', b.label,
                        'created_at', b.created_at,
                        'revoked_at', b.revoked_at)), '[]')
                from public.member_badges b
                where b.member_id = v_me.id)
  );
end;
$$;

revoke execute on function public.export_my_data(uuid) from public, anon;
grant execute on function public.export_my_data(uuid) to authenticated;
