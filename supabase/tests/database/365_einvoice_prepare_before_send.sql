-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3335 / 0689: an e-invoice is prepared durably before it can leave. One
-- record per business transmission (workspace, invoice, provider, destination,
-- environment); changed bytes or recipient conflict whatever the request id;
-- the dispatch is claimed once with an owner and a generation; a stale writer
-- records nothing; an expired or unrecorded dispatch is `uncertain`, never
-- claimable again; manual resolution needs the send authority, a reason and
-- evidence, and cannot be repeated. The legacy `status` column stays a
-- three-value projection an older client can read.
begin;
select plan(48);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000033500c1';
  u_m uuid := '00000000-0000-4000-8000-0000033500c2';
  ws uuid; mo uuid; inv uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_o, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'einv-o-' || u_o || '@deskilo.test', '', now(), now(), now()),
         (u_m, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'einv-m-' || u_m || '@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('E-invoice prep', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true) returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_m, false, false);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, mo, mo, 'E-1', 'September', '[]'::jsonb, 5000, 'EUR', 'M', 'W', 'M', 'sig')
  returning id into inv;
  perform set_config('ei.ws', ws::text, false);
  perform set_config('ei.inv', inv::text, false);
  perform set_config('ei.uo', u_o::text, false);
  perform set_config('ei.um', u_m::text, false);
end
$seed$;
select pg_temp.seed();

create or replace function pg_temp.prep(p_dest text, p_env text, p_hash text, p_scheme text)
returns jsonb language sql as $$
  select public.prepare_einvoice_v1(current_setting('ei.ws')::uuid, current_setting('ei.inv')::uuid,
    'generic', p_dest, p_env, current_setting('ei.uo')::uuid, 'T', 'facturX', p_hash, 'f.pdf',
    'application/pdf', p_scheme, '', '\x01'::bytea) $$;

select set_config('ei.id1', (pg_temp.prep('government', 'prod', 'h1', '')->>'id'), false);

select is((pg_temp.prep('government', 'prod', 'h1', '')->>'outcome'), 'existing',
  'the same business transmission answers the original, whatever the request');
select is((pg_temp.prep('government', 'prod', 'h1', '')->>'id'), current_setting('ei.id1'),
  'and it is the same record');
select is((pg_temp.prep('government', 'prod', 'h2', '')->>'outcome'), 'conflict',
  'changed bytes conflict');
select is((pg_temp.prep('government', 'prod', 'h1', 'iso')->>'outcome'), 'conflict',
  'a changed recipient conflicts');
select is((select count(*)::int from public.invoice_transmissions
            where invoice_id = current_setting('ei.inv')::uuid), 1,
  'one record, one stored artifact');
select is((select count(*)::int from public.invoice_transmission_artifacts), 1, 'one artifact');
select is((select status || '|' || detail from public.invoice_transmissions
            where id = current_setting('ei.id1')::uuid),
  'failed|In progress or unresolved - do not resend',
  'an older client reads a prepared row as failed, with the words not to resend');
select isnt((pg_temp.prep('customer', 'prod', 'h1', '')->>'id'), current_setting('ei.id1'),
  'the customer leg is its own transmission');
select isnt((pg_temp.prep('government', 'uat', 'h1', '')->>'id'), current_setting('ei.id1'),
  'so is another environment');

select is((public.claim_einvoice_dispatch_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.uo')::uuid, 150)->>'generation'), '1', 'the first claim owns generation 1');
select is((public.claim_einvoice_dispatch_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.um')::uuid, 150)->>'claimed'), 'false', 'a second claim loses');
select is((public.record_einvoice_outcome_v1(current_setting('ei.id1')::uuid, 0,
  current_setting('ei.uo')::uuid, 'accepted', 'x', '', '{}')->>'recorded'), 'false',
  'a stale generation records nothing');
select is((public.record_einvoice_outcome_v1(current_setting('ei.id1')::uuid, 1,
  current_setting('ei.um')::uuid, 'accepted', 'x', '', '{}')->>'recorded'), 'false',
  'nor does a writer that is not the owner');
select is((public.record_einvoice_outcome_v1(current_setting('ei.id1')::uuid, 1,
  current_setting('ei.uo')::uuid, 'uncertain', '', '', '{}')->>'recorded'), 'true',
  'the owner records its outcome');
select is((public.claim_einvoice_dispatch_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.um')::uuid, 150)->>'claimed'), 'false', 'an uncertain record is never claimed again');
select is((public.record_einvoice_outcome_v1(current_setting('ei.id1')::uuid, 1,
  current_setting('ei.um')::uuid, 'accepted', 'x', '', '{}')->>'recorded'), 'false',
  'a late outcome from another owner does not replace the recorded uncertainty');
select is((public.record_einvoice_lookup_v1(current_setting('ei.id1')::uuid, null, null, null, null,
  'timeout')->>'phase'), 'uncertain', 'a failed lookup leaves it uncertain');

-- expiry with no outcome ever recorded
select set_config('ei.id2', (pg_temp.prep('customer', 'prod', 'h1', '')->>'id'), false);
select public.claim_einvoice_dispatch_v1(current_setting('ei.id2')::uuid,
  current_setting('ei.uo')::uuid, 150);
update public.invoice_transmissions set deadline = now() - interval '1 minute'
 where id = current_setting('ei.id2')::uuid;
select is((public.claim_einvoice_dispatch_v1(current_setting('ei.id2')::uuid,
  current_setting('ei.um')::uuid, 150)->>'phase'), 'uncertain',
  'an expired dispatch with no outcome is uncertain, not claimable');

-- a different owner cannot settle the expired dispatch; its own owner can
select is((public.record_einvoice_outcome_v1(current_setting('ei.id2')::uuid, 1,
  current_setting('ei.um')::uuid, 'accepted', 'x', '', '{}')->>'recorded'), 'false',
  'another owner cannot settle an expired dispatch');
select is((public.record_einvoice_outcome_v1(current_setting('ei.id2')::uuid, 1,
  current_setting('ei.uo')::uuid, 'accepted', 'G', '', '{"guid":"G"}')->>'recorded'), 'true',
  'the owner''s late outcome settles what expiry marked uncertain');
-- a later status answer lands beside the upload receipt, never over it
select public.record_einvoice_lookup_v1(current_setting('ei.id2')::uuid, null, null,
  '{"x":1}'::jsonb, '{"v":1}'::jsonb, null);
select is((select receipt->>'guid' || '|' || (verdict->>'v') from public.invoice_transmissions
            where id = current_setting('ei.id2')::uuid), 'G|1',
  'the upload receipt stays; the answer is the verdict');
-- a window is required
select throws_ok($$ select public.claim_einvoice_dispatch_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.uo')::uuid, 0) $$, '22023', null, 'a zero window is refused');
select throws_ok($$ select public.claim_einvoice_dispatch_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.uo')::uuid, null) $$, '22023', null, 'a null window is refused');
-- an older Edge Function writes status only
insert into public.invoice_transmissions (workspace_id, invoice_id, provider, status)
values (current_setting('ei.ws')::uuid, current_setting('ei.inv')::uuid, 'generic', 'failed');
select is((select phase from public.invoice_transmissions
            where business_key is null and status = 'failed' limit 1), 'failed',
  'a legacy failed insert is phase failed, not prepared');
-- an older status action rewrites `status` of a legacy row: the phase follows
update public.invoice_transmissions set status = 'rejected'
 where business_key is null and status = 'failed';
select is((select phase from public.invoice_transmissions where business_key is null limit 1),
  'rejected', 'a legacy status update moves the phase with it');
-- a failure that proved no acceptance is dispatchable again, same record
select set_config('ei.id4', (pg_temp.prep('customer', 'uat', 'h1', '')->>'id'), false);
select public.claim_einvoice_dispatch_v1(current_setting('ei.id4')::uuid, current_setting('ei.uo')::uuid, 150);
select public.record_einvoice_outcome_v1(current_setting('ei.id4')::uuid, 1,
  current_setting('ei.uo')::uuid, 'failed', '', 'refused credential', '{}');
select is((public.claim_einvoice_dispatch_v1(current_setting('ei.id4')::uuid,
  current_setting('ei.uo')::uuid, 150)->>'generation'), '2', 'a failed record is claimed again as generation 2');
select is((select count(*)::int from public.invoice_transmissions where id = current_setting('ei.id4')::uuid),
  1, 'on the same record');

-- a manual resolution can carry the document verdict
select set_config('ei.id3', (pg_temp.prep('government', 'uat', 'h1', '')->>'id'), false);
select public.claim_einvoice_dispatch_v1(current_setting('ei.id3')::uuid, current_setting('ei.uo')::uuid, 150);
select public.record_einvoice_outcome_v1(current_setting('ei.id3')::uuid, 1,
  current_setting('ei.uo')::uuid, 'uncertain', '', '', '{}');
select public.resolve_einvoice_manually_v1(current_setting('ei.id3')::uuid, current_setting('ei.uo')::uuid,
  'accepted', 'uploaded; authority refused it', 'portal ref 2', '{"document":"rejected"}'::jsonb);
select is((select verdict->>'document' || '|' || phase from public.invoice_transmissions
            where id = current_setting('ei.id3')::uuid), 'rejected|accepted',
  'accepted upload with a separate rejected document verdict');

select throws_ok($$ select public.resolve_einvoice_manually_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.um')::uuid, 'failed', 'r', 'e') $$, '42501', null,
  'a plain member may not resolve');
select throws_ok($$ select public.resolve_einvoice_manually_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.uo')::uuid, 'failed', 'r', ' ') $$, '22023', null,
  'evidence is required');
select is((public.resolve_einvoice_manually_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.uo')::uuid, 'accepted', 'portal shows it', 'ref 1')->>'phase'), 'accepted',
  'the owner resolves, attributably');
select is((public.resolve_einvoice_manually_v1(current_setting('ei.id1')::uuid,
  current_setting('ei.uo')::uuid, 'failed', 'again', 'again')->>'resolved'), 'false',
  'a second resolution changes nothing');
select is((select resolved_by::text || '|' || status from public.invoice_transmissions
            where id = current_setting('ei.id1')::uuid),
  current_setting('ei.uo') || '|accepted', 'actor recorded; status projects accepted');

select is(has_function_privilege('authenticated',
  'public.claim_einvoice_dispatch_v1(uuid,uuid,integer)', 'execute')
  or has_table_privilege('authenticated', 'public.invoice_transmission_artifacts', 'select'),
  false, 'client roles reach neither the RPCs nor the artifacts');
select ok(has_function_privilege('service_role',
  'public.claim_einvoice_dispatch_v1(uuid,uuid,integer)', 'execute'), 'the service role can claim');

-- #3576: recovering an uncertain transmission that kept its provider id.
-- Database-only identities (government/dev, customer/dev): no provider call.
select set_config('ei.r8', (pg_temp.prep('government', 'dev', 'h1', '')->>'id'), false);
select set_config('ei.r9', (pg_temp.prep('customer', 'dev', 'h1', '')->>'id'), false);
select public.claim_einvoice_dispatch_v1(current_setting('ei.r8')::uuid, current_setting('ei.uo')::uuid, 150);
select public.claim_einvoice_dispatch_v1(current_setting('ei.r9')::uuid, current_setting('ei.uo')::uuid, 150);
select public.record_einvoice_outcome_v1(current_setting('ei.r8')::uuid, 1,
  current_setting('ei.uo')::uuid, 'uncertain', 'G-R8', '', '{"partial":"before lookup"}');
select public.record_einvoice_outcome_v1(current_setting('ei.r9')::uuid, 1,
  current_setting('ei.uo')::uuid, 'uncertain', 'G-R9', '', '{"partial":"before lookup"}');
select set_config('ei.r8key', (select business_key from public.invoice_transmissions
  where id = current_setting('ei.r8')::uuid), false);
select set_config('ei.rows', (select count(*) from public.invoice_transmissions)::text, false);
select set_config('ei.arts', (select count(*) from public.invoice_transmission_artifacts)::text, false);

-- R8: a correlated lookup settles the uncertain row on the same record
select is((public.record_einvoice_lookup_v1(current_setting('ei.r8')::uuid, 'accepted', 'G-R8',
  '{"guid":"G-R8","evidence":{"ok":1}}'::jsonb, '{"status":"accepted"}'::jsonb, '')->>'recorded'),
  'true', 'R8 retained-ID recovery: a lookup on an uncertain row is recorded');
select is((select phase || '|' || status from public.invoice_transmissions
            where id = current_setting('ei.r8')::uuid), 'accepted|accepted',
  'R8 retained-ID recovery: the row is accepted and projects accepted');
select is((select receipt from public.invoice_transmissions where id = current_setting('ei.r8')::uuid),
  '{"guid":"G-R8","evidence":{"ok":1}}'::jsonb,
  'R8 retained-ID recovery: the correlated receipt replaces the partial prior receipt');
select is((select verdict->>'status' from public.invoice_transmissions
            where id = current_setting('ei.r8')::uuid), 'accepted',
  'R8 retained-ID recovery: the verdict is set on that row');
select is((select business_key || '|' || external_id || '|' || generation from public.invoice_transmissions
            where id = current_setting('ei.r8')::uuid),
  current_setting('ei.r8key') || '|G-R8|1',
  'R8 retained-ID recovery: business key, external id and generation are unchanged');
select is((select count(*) from public.invoice_transmissions)::text || '|'
          || (select count(*) from public.invoice_transmission_artifacts)::text,
  current_setting('ei.rows') || '|' || current_setting('ei.arts'),
  'R8 retained-ID recovery: no extra row and no extra artifact');

-- R9: a failed lookup (null phase) leaves the uncertain row as it was
select is((public.record_einvoice_lookup_v1(current_setting('ei.r9')::uuid, null, null, null, null,
  'timeout')->>'recorded'), 'true', 'R9 retained-ID recovery: a failed lookup is recorded');
select is((select phase from public.invoice_transmissions where id = current_setting('ei.r9')::uuid),
  'uncertain', 'R9 retained-ID recovery: the row is still uncertain');
select is((select receipt::text || '|' || external_id from public.invoice_transmissions
            where id = current_setting('ei.r9')::uuid),
  '{"partial": "before lookup"}|G-R9', 'R9 retained-ID recovery: receipt and external id are unchanged');
select is((select query_error from public.invoice_transmissions where id = current_setting('ei.r9')::uuid),
  'timeout', 'R9 retained-ID recovery: the query error records the failure');
select is((public.claim_einvoice_dispatch_v1(current_setting('ei.r9')::uuid,
  current_setting('ei.um')::uuid, 150)->>'claimed'), 'false',
  'R9 retained-ID recovery: the failed lookup does not make it claimable');

-- R10: once settled, a second nonnull-phase resolution changes nothing
select is((public.record_einvoice_lookup_v1(current_setting('ei.r8')::uuid, 'rejected', 'G-OTHER',
  '{"guid":"G-OTHER"}'::jsonb, '{"status":"rejected"}'::jsonb, 'late')->>'recorded'),
  'false', 'R10 retained-ID recovery: a second resolution of a settled row is not recorded');
select is((select phase || '|' || external_id || '|' || receipt::text || '|' || (verdict->>'status')
            || '|' || query_error from public.invoice_transmissions
            where id = current_setting('ei.r8')::uuid),
  'accepted|G-R8|{"guid": "G-R8", "evidence": {"ok": 1}}|accepted|',
  'R10 retained-ID recovery: phase, id, receipt, verdict and query error are unchanged');

select * from finish();
rollback;
