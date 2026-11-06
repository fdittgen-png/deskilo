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
select plan(32);

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
  current_setting('ei.uo')::uuid, 'accepted', 'x', '', '{}')->>'recorded'), 'false',
  'a late outcome does not replace the recorded uncertainty');
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

select * from finish();
rollback;
