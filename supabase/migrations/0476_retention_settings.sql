-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0476 (#2487, S4 of #2483, last checkpoint) -- the two retention windows
-- that were left as owner decisions are registry settings, decided as the
-- 2026-10-14 amendment says:
--
--   mcp.notice_read_retention_days  90 days, 7..3650 (platform)
--       the read-state purge of the operator notices (0357). It purges READ
--       notices only: an unread notice, a grant, a consent and the audit
--       trail are never touched by this value; legal retention is #2571's.
--   vat.vies_evidence_days          90 days, 1..90 (platform, workspace)
--       how long a valid VAT-number check stays recent enough to stand as
--       evidence on a new invoice (0404). The value can only get shorter: a
--       longer window would make an old check stand for a transaction it
--       never saw. A freshness window, not a claim that a transaction is
--       valid.
--
-- Defaults are today's values exactly. Anchored patches of the live bodies of
-- instance_notify_operators, mark_instance_notice_read and
-- member_vies_verified (each anchor asserted to occur exactly once).

-- ── the registry rows ────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('mcp.notice_read_retention_days', 'int', '90'::jsonb, 7, 3650, 'days', 'security', array['platform'], 'workspaceSettings', null, true, null, 'instance_notify_operators, mark_instance_notice_read (0357)', 'Days an operator notice that has been read is kept before it is purged. Only read notices are purged: an unread notice, a grant, a consent and the audit trail are never touched by this value.'),
('vat.vies_evidence_days', 'duration', '90'::jsonb, 1, 90, 'days', 'vat', array['platform', 'workspace'], 'manageBilling', null, true, null, 'member_vies_verified (0404)', 'Days a valid VAT-number check stays recent enough to stand as evidence on a new invoice. A shorter value asks for a fresh check sooner; it is not proof that a transaction is valid.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0476: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

select pg_temp.patch_function(
  'public.instance_notify_operators(text, text, jsonb, uuid)'::regprocedure,
  array[$a$where read_at is not null and read_at < now() - interval '90 days';$a$],
  array[$a$where read_at is not null and read_at < now()
          - make_interval(days => (public.setting_value(null, 'mcp.notice_read_retention_days') #>> '{}')::int);$a$]);

select pg_temp.patch_function(
  'public.mark_instance_notice_read(uuid)'::regprocedure,
  array[$a$where user_id = auth.uid() and read_at is not null and read_at < now() - interval '90 days';$a$],
  array[$a$where user_id = auth.uid() and read_at is not null and read_at < now()
          - make_interval(days => (public.setting_value(null, 'mcp.notice_read_retention_days') #>> '{}')::int);$a$]);

select pg_temp.patch_function(
  'public.member_vies_verified(uuid, text)'::regprocedure,
  array[$a$and m.vies_checked_at > now() - interval '90 days'$a$],
  array[$a$and m.vies_checked_at > now()
               - make_interval(days => (public.setting_value(m.workspace_id, 'vat.vies_evidence_days') #>> '{}')::int)$a$]);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(476);
