-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Expired HMRC attempts stay uncertain until their own checked marker is used.
-- Old confirmations, old holders and active leases cannot start another POST.
begin;
select plan(18);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000000652', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hmrc-0652@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, vat_id, feature_flags)
values ('00000000-0000-4000-8000-000000000653', 'HMRC recovery test', 'GB', 'GBP', 'Europe/London', '00000000-0000-4000-8000-000000000652', 'vat_registered', 'GB 123 456 789', '{"moneyTab": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "mtdSubmission": true, "accountingBook": true, "accountingConnectors": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('00000000-0000-4000-8000-000000000653', '00000000-0000-4000-8000-000000000652', true, true, 'active', '2026-01-01');
insert into public.vat_declarations (id, workspace_id, period_start, period_end, lines, total_net_cents, total_vat_cents)
values ('00000000-0000-4000-8000-000000000654', '00000000-0000-4000-8000-000000000653', '2031-01-01', '2031-03-31', '[]', 0, 0);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000000655', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hmrc-0652-other@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, vat_id, feature_flags)
values ('00000000-0000-4000-8000-000000000656', 'Other HMRC recovery test', 'GB', 'GBP', 'Europe/London', '00000000-0000-4000-8000-000000000655', 'vat_registered', 'GB 123 456 789', '{"moneyTab": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "mtdSubmission": true, "accountingBook": true, "accountingConnectors": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('00000000-0000-4000-8000-000000000656', '00000000-0000-4000-8000-000000000655', true, true, 'active', '2026-01-01');
insert into public.vat_declarations (id, workspace_id, period_start, period_end, lines, total_net_cents, total_vat_cents)
values ('00000000-0000-4000-8000-000000000657', '00000000-0000-4000-8000-000000000656', '2031-01-01', '2031-03-31', '[]', 0, 0);
insert into public.hmrc_submissions (declaration_id, workspace_id, boxes_sha256, state, holder, claim_until)
values ('00000000-0000-4000-8000-000000000657', '00000000-0000-4000-8000-000000000656', repeat('a',64), 'unconfirmed', 'holder-other', now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000652","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000652', true);
set local role authenticated;
select throws_ok($$select public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-001', 60, repeat('a',64), null)$$, '42501', null, 'authenticated callers cannot invoke the service claim');
reset role;
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-001', 60, repeat('a',64), null)->>'claimed', 'true', 'first claim succeeds');
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-001', 60, repeat('a',64), null)->>'state', 'in_flight', 'same holder cannot reacquire active lease');
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-002', 60, repeat('a',64), 'bad')->>'state', 'in_flight', 'other holder cannot bypass active lease');
select is(public.hmrc_connection_v1('00000000-0000-4000-8000-000000000653')->'unconfirmed_declaration_ids', '[]'::jsonb, 'active lease is not uncertain');
select ok(not (public.hmrc_connection_v1('00000000-0000-4000-8000-000000000653')->'recovery_markers' ? '00000000-0000-4000-8000-000000000657'), 'other workspace marker is absent');
set local role authenticated;
select throws_ok($$select public.hmrc_connection_v1('00000000-0000-4000-8000-000000000656')$$, '42501', 'only the owner files VAT declarations', 'another workspace read is refused');
reset role;
update public.hmrc_submissions set claim_until = now() where declaration_id = '00000000-0000-4000-8000-000000000654';
select ok(public.hmrc_connection_v1('00000000-0000-4000-8000-000000000653')->'unconfirmed_declaration_ids' ? '00000000-0000-4000-8000-000000000654', 'expiry boundary is uncertain');
select is(public.claim_hmrc_submission('00000000-0000-4000-8000-000000000654', 'holder-002', 60, repeat('a',64))->>'state', 'unconfirmed', 'old RPC fails closed');
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-002', 60, repeat('a',64), null)->>'state', 'unconfirmed', 'missing check refuses retry');
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-002', 60, repeat('a',64), 'bad')->>'state', 'unconfirmed', 'bad check refuses retry');
select set_config('hmrc.test_marker', public.hmrc_connection_v1('00000000-0000-4000-8000-000000000653')->'recovery_markers'->>'00000000-0000-4000-8000-000000000654', true);
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-002', 60, repeat('a',64), current_setting('hmrc.test_marker'))->>'claimed', 'true', 'checked marker starts one new attempt');
select public.release_hmrc_submission('00000000-0000-4000-8000-000000000654', 'holder-001', false);
select is((select holder from public.hmrc_submissions where declaration_id = '00000000-0000-4000-8000-000000000654'), 'holder-002', 'old release cannot erase successor');
select throws_ok($$select public.record_hmrc_acceptance('00000000-0000-4000-8000-000000000654', 'holder-001', 'real', '', '')$$, '55P03', 'this submission is no longer yours', 'old holder cannot record acceptance');
update public.hmrc_submissions set claim_until = now() where declaration_id = '00000000-0000-4000-8000-000000000654';
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-003', 60, repeat('a',64), current_setting('hmrc.test_marker'))->>'state', 'unconfirmed', 'old marker cannot authorize later uncertainty');
select is(public.hmrc_connection_v1('00000000-0000-4000-8000-000000000653')->'recovery_markers'->>'00000000-0000-4000-8000-000000000654' = current_setting('hmrc.test_marker'), false, 'new attempt has a different marker');
select public.record_hmrc_acceptance('00000000-0000-4000-8000-000000000654', 'holder-002', 'real', '', '');
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-003', 60, repeat('a',64), null)->>'form_bundle_number', 'real', 'accepted receipt replay needs no marker');
select is(public.claim_hmrc_submission_v2('00000000-0000-4000-8000-000000000654', 'holder-003', 60, repeat('b',64), null)->>'state', 'accepted_for_other_figures', 'accepted other figures refused');
select * from finish();
rollback;
