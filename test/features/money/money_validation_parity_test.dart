// SPDX-License-Identifier: 0BSD
//
// #816 (migration 0144) — the validation framework and the role gates on
// the money flows keep what the guide promises. The SQL half is pinned
// on the migration text (the live harness verifies behaviour); the
// client half asks the fakes.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/providers/billing_invoice_sweep.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

WorkspaceEvent _event(EventType type, {String actor = 'admin-2'}) =>
    WorkspaceEvent(
      id: 'e',
      workspaceId: 'ws-1',
      type: type,
      action: EventAction.submitted,
      actorMemberId: actor,
      subjectMemberId: 'member-1',
      payload: const {},
      status: EventStatus.pending,
      createdAt: kTestNow,
    );

void main() {
  group('migration 0144 — the server contract', () {
    final sql = File('supabase/migrations/0144_money_validation_parity.sql')
        .readAsStringSync();

    /// The CODE of [name] — from its create statement to the next
    /// statement block, comment lines dropped so a comment that merely
    /// names a guard can never satisfy (or break) a pin.
    String body(String name) {
      final start = sql.indexOf('create or replace function public.$name(');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final ends = [
        sql.indexOf('create or replace function', start + 1),
        sql.indexOf('do \$patch\$', start + 1),
      ].where((i) => i >= 0);
      final end = ends.isEmpty ? sql.length : ends.reduce((a, b) => a < b ? a : b);
      return sql
          .substring(start, end)
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('--'))
          .join('\n');
    }

    test('ONE issuer gate, asked by every invoicing RPC — no admin '
        'pre-filter, no legacy flag', () {
      expect(body('issuing_member'),
          contains("public.has_permission(p_workspace_id, 'issueInvoices')"));
      expect(body('issuing_member'), isNot(contains('is_admin or is_owner')));
      for (final rpc in [
        'void_invoice',
        'record_invoice_reminder',
        'settle_credit_invoice',
        'request_invoice_writeoff',
        'settle_invoices',
      ]) {
        final text = body(rpc);
        expect(text, contains('public.issuing_member('), reason: rpc);
        expect(text, isNot(contains('adminInvoicing')), reason: rpc);
        expect(text, isNot(contains('is_admin or is_owner')), reason: rpc);
      }
      // The two long bodies are patched in place: their gates swapped.
      for (final rpc in ['create_invoice', 'match_invoice']) {
        expect(sql, contains("p.proname = '$rpc'"), reason: rpc);
      }
      expect(sql, contains('v_actor := public.issuing_member(p_workspace_id);'));
      expect(sql,
          contains('v_actor := public.issuing_member(v_invoice.workspace_id);'));
    });

    test('an expired invoice_payment releases what it held, through the '
        'same helper the reject branch uses', () {
      expect(body('release_invoice_payment'),
          contains('delete from public.invoice_matches where event_id'));
      expect(body('release_invoice_payment'),
          contains('delete from public.invoice_match_payments'));
      expect(body('release_invoice_payment'),
          contains("coalesce(v_event.payload->>'kind', '') = 'settlement'"));
      expect(body('sweep_pending_events'),
          contains('perform public.release_invoice_payment(v_id);'));
      expect(sql, contains("p.proname = 'respond_to_event'"));
      expect(sql, contains('perform public.release_invoice_payment(v_event.id);'));
    });

    test('a settlement obeys the invoice_payment policy — never applied '
        'by its own author', () {
      final settle = body('settle_invoices');
      expect(settle, isNot(contains("'applied'")));
      expect(settle, contains("vp.event_type = 'invoice_payment'"));
      expect(settle,
          contains("case when v_has_policy then 'pending' else 'confirmed' end"));
      expect(settle, contains("status = 'active' and not is_kiosk"));
      expect(settle, contains("'invoiceSettlement'"));
    });

    test('a settled source is neither voided, replaced nor matched; voiding '
        'a settlement releases its sources', () {
      expect(body('void_invoice'), contains("raise exception 'invoice is settled'"));
      expect(body('void_invoice'), contains("if v_invoice.kind = 'settlement' then"));
      expect(sql, contains('if v_replaced.settled_by_invoice_id is not null then'));
      expect(sql, contains('if v_invoice.settled_by_invoice_id is not null then'));
      expect(body('invoices_immutable'),
          contains('old.settled_by_invoice_id is not null\n     and new.settled_by_invoice_id is null'));
    });

    test('a manual reminder files the feed entry the sweep files, at its '
        'real level', () {
      final remind = body('record_invoice_reminder');
      expect(remind, contains("'invoice_reminder', 'created'"));
      expect(remind, contains("'automatic', false"));
      expect(remind, contains('v_level := least(v_count + 1, v_levels);'));
    });

    test('the four finance tables read through may_view_member_finances; '
        'scoped validators read their events', () {
      for (final table in [
        'invoice_matches',
        'invoice_match_payments',
        'invoice_reminders',
        'invoice_transmissions',
      ]) {
        expect(
          sql,
          contains('alter policy ${table}_select on public.$table\n'
              '  using (public.may_view_invoice(invoice_id));'),
          reason: table,
        );
      }
      expect(sql, contains('alter policy events_select on public.events'));
      expect(sql, contains('public.may_validate_event_type(workspace_id, events.type)'));
    });

    test('manageValidation and workspaceSettings mean something', () {
      expect(sql, contains("public.has_permission(workspace_id, 'manageValidation')"));
      expect(body('set_dunning_rules'),
          contains("public.has_permission(p_workspace_id, 'workspaceSettings')"));
      expect(body('set_billing_rules'),
          contains("public.has_permission(p_workspace_id, 'workspaceSettings')"));
    });

    test('the catalog carries every permission the client can grant', () {
      // #881 — the catalog moved to 0155 with paymentTermsEdit.
      final latestCatalog =
          File('supabase/migrations/0155_payment_terms_permission_catalog.sql')
              .readAsStringSync();
      final catalog = RegExp(r"v_catalog text\[\] := array\[([^\]]+)\]")
          .firstMatch(latestCatalog)!
          .group(1)!;
      for (final permission in WorkspacePermission.values) {
        expect(catalog, contains("'${permission.wireName}'"),
            reason: permission.wireName);
      }
    });
  });

  group('the client half', () {
    test('the billed member is never offered the decision on a match, a '
        'refund or a settlement', () {
      expect(_event(EventType.invoicePayment).needsAdminDecider, isTrue);
      // The historical members of the list stay.
      expect(_event(EventType.invoiceWriteoff).needsAdminDecider, isTrue);
      expect(_event(EventType.payment).needsAdminDecider, isFalse);
      expect(
        _event(EventType.payment, actor: 'member-1').needsAdminDecider,
        isTrue,
      );
    });

    testWidgets('the validation editor offers no Adjustment card',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).push('/validation');
      await tester.pumpAndSettle();
      expect(find.text('Invoice payment'), findsOneWidget);
      expect(find.text('Adjustment'), findsNothing);
    });

    testWidgets('opening Finances runs the billing sweep once, like the '
        'reminder sweep (#802 gets a client clock)', (tester) async {
      final money = FakeMoneyRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(money: money),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Money'));
      await tester.pumpAndSettle();
      expect(money.billingSweeps, ['ws-1']);
    });

    test('the sweep is idle for a workspace that bills the whole month',
        () async {
      final money = FakeMoneyRepository();
      final container = ProviderContainer(
        overrides: standardTestOverrides(
          money: money,
          workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: const {
            'subscriptionInvoices': false,
            'usageInvoices': false,
          }),
        ),
      );
      addTearDown(container.dispose);
      await container.read(billingInvoiceSweepProvider('ws-1').future);
      expect(money.billingSweeps, isEmpty);
      // The rules object is still the writer's contract.
      expect(BillingRules.fromJson(const {}).toJson(), isA<Map>());
    });
  });
}
