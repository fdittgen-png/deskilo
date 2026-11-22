-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (three functions and one pg_cron job; no existing row is read or rewritten)
--
-- A personal home keeps asserting a status that is not `active`.
--
--   * `identity_status_reissue()` runs every minute and, for each person whose latest status is
--     `suspended` (and who is still suspended) or `erased` (and whose erasure no installation has
--     yet acknowledged), issues the status again to the installations the person is linked to, with a
--     new revision, once the latest issue is older than `identity.status_reconcile_seconds`. A run
--     with nothing due issues nothing.
--   * An issue that was not delivered is sent again by the delivery tick until its deadline; the
--     next re-issue follows the deadline, so a status outlives a delivery that failed.
--   * A person whose status is `active` again is not re-issued: lifting the suspension issued
--     `active` at that moment.

-- Issues one status of one subject to one installation, with a new revision.
create or replace function public.identity_status_issue_one(p_subject text, p_status text, p_target uuid)
returns int language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_issuer text;
  v_until timestamptz := now() + make_interval(secs =>
    (public.setting_value(null, 'identity.status_assertion_lifetime_seconds') #>> '{}')::int);
  v_event uuid := gen_random_uuid();
  v_revision bigint;
begin
  select issuer into v_issuer from public.identity_authority where kind = 'native';
  if v_issuer is null then
    return 0;
  end if;
  v_revision := nextval('public.identity_status_revision');
  insert into public.identity_status_outbox (event_id, target_installation_id, issuer,
    subject, revision, status, issued_at, valid_until, body)
  values (v_event, p_target, v_issuer, p_subject, v_revision, p_status, now(), v_until,
    jsonb_build_object('protocol', 1, 'kind', 'identity_status', 'event_id', v_event,
      'source_installation_id', public.installation_id(),
      'target_installation_id', p_target, 'issuer', v_issuer, 'subject', p_subject,
      'revision', v_revision, 'status', p_status, 'issued_at', now(), 'valid_until', v_until));
  return 1;
end;
$fn$;
revoke execute on function public.identity_status_issue_one(text, text, uuid) from public, anon, authenticated, service_role;

create index if not exists identity_status_outbox_subject_revision
  on public.identity_status_outbox (subject, revision desc);

create or replace function public.identity_status_reissue()
returns int language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_every interval := make_interval(secs =>
    (public.setting_value(null, 'identity.status_reconcile_seconds') #>> '{}')::int);
  v_row record;
  v_target uuid;
  v_count int := 0;
begin
  for v_row in
    select s.subject, s.status
      from (select distinct on (o.subject) o.subject, o.status, o.issued_at
              from public.identity_status_outbox o
             order by o.subject, o.revision desc) s
     where s.issued_at <= now() - v_every and s.status in ('suspended', 'erased')
  loop
    if v_row.status = 'suspended' then
      -- while the person is still suspended, to every installation they are linked to
      perform 1 from auth.users u
       where u.id = v_row.subject::uuid and u.deleted_at is null and u.banned_until > now() for share;
      if found then
        for v_target in select t from public.identity_status_linked_targets(v_row.subject::uuid) t
                         where not exists (select 1 from public.identity_status_outbox w
                                            where w.subject = v_row.subject and w.target_installation_id = t
                                              and w.state in ('pending', 'sent') and w.valid_until > now()) loop
          v_count := v_count + public.identity_status_issue_one(v_row.subject, 'suspended', v_target);
        end loop;
      end if;
    else
      -- an erasure goes on to each installation that is enrolled, has not acknowledged it or
      -- refused it for good, and has no issue still waiting
      for v_target in select distinct o.target_installation_id from public.identity_status_outbox o
                       where o.subject = v_row.subject and o.status = 'erased'
                         and exists (select 1 from public.enrolled_installations e
                                      where e.installation_id = o.target_installation_id and e.enabled)
                         and not exists (select 1 from public.identity_status_outbox d
                                          where d.subject = o.subject and d.status = 'erased'
                                            and d.target_installation_id = o.target_installation_id
                                            and (d.state in ('delivered', 'refused')
                                                 or (d.state in ('pending', 'sent') and d.valid_until > now()))) loop
        v_count := v_count + public.identity_status_issue_one(v_row.subject, 'erased', v_target);
      end loop;
    end if;
  end loop;
  return v_count;
end;
$fn$;
revoke execute on function public.identity_status_reissue() from public, anon, authenticated, service_role;

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-identity-status-reissue')
    where exists (select 1 from cron.job where jobname = 'deskilo-identity-status-reissue');
  perform cron.schedule('deskilo-identity-status-reissue', '* * * * *',
    $job$select public.identity_status_reissue()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs identity_status_reissue() instead', sqlerrm;
end
$cron$;

select public.set_deskilo_schema_version(880);
