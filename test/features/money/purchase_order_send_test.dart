// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 PR B — e-mailing a purchase order: an attempt read exactly; the
// mail settings checked before they are sent (a first save brings its key,
// a sender name carrying a header is refused); the Demo's simulation keeps
// the server's fences (the mail configured, a recipient, one attempt that
// may have left, the same attempt id replayed); and the screen sends a
// draft and asks a person about an unconfirmed attempt.
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/data/supabase_purchase_order_repository.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_orders_screen.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, PostgrestException;

const PurchaseOrderMail _mail = (
  subject: 'Purchase order 2026-0001',
  text: 'Hello',
  pdfBase64: 'JVBERi0xLjQ=',
  fileName: 'purchase-order-2026-0001.pdf',
);

Future<(FakePurchaseOrderRepository, FakeSupplierRepository, PurchaseOrder)>
_withOrder({String email = 'orders@alpha.test'}) async {
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws', const SupplierDraft(name: 'Alpha'));
  final repo = FakePurchaseOrderRepository(
    suppliers: () => suppliers.suppliers,
    services: () => const <ServiceItem>[],
    now: () => DateTime(2026, 11, 4),
  );
  final order = await repo.save(
    'ws',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      recipientEmail: email,
      lines: const [
        PurchaseOrderLineDraft(
          description: 'Paper towels',
          quantity: 12,
          unitPriceCents: 150,
        ),
      ],
    ),
  );
  return (repo, suppliers, order);
}

void main() {
  _undecided();
  test(
    'an attempt and the settings read exactly; the key never travels back',
    () {
      final send = PurchaseOrderSend.fromJson({
        'id': 'a1',
        'order_id': 'po-1',
        'state': 'unconfirmed',
        'recipient': 'orders@alpha.test',
        'reason': 'no confirmed answer',
      });
      expect(
        (send.state, send.awaitsDecision),
        (PurchaseOrderSendState.unconfirmed, true),
      );
      final settings = PurchaseOrderMailSettings.fromJson({
        'sender_email': 'orders@space.test',
        'sender_name': 'The Space',
        'has_api_key': true,
        'revision': 2,
      });
      expect(
        (settings.senderEmail, settings.hasApiKey),
        ('orders@space.test', true),
      );
    },
  );

  test('the settings are checked before they are sent', () {
    const first = PurchaseOrderMailDraft(senderEmail: 'orders@space.test');
    expect(
      first.validFor(null),
      isFalse,
      reason: 'the first save brings its key',
    );
    expect(
      const PurchaseOrderMailDraft(
        senderEmail: 'orders@space.test',
        apiKey: 're_test_123456',
      ).validFor(null),
      isTrue,
    );
    const stored = PurchaseOrderMailSettings(
      senderEmail: 'a@b.co',
      hasApiKey: true,
      revision: 1,
    );
    expect(
      first.validFor(stored),
      isTrue,
      reason: 'an empty key keeps the stored one',
    );
    expect(
      const PurchaseOrderMailDraft(
        senderEmail: 'orders@space.test',
        senderName: 'x\r\nBcc: y',
      ).validFor(stored),
      isFalse,
    );
    expect(
      const PurchaseOrderMailDraft(
        senderEmail: 'a@b.co',
        apiKey: 'short',
      ).validFor(stored),
      isFalse,
    );
    for (final bad in ['Orders <a@b.co>', 'a@b.co, c@d.co', 'a"b@c.co']) {
      expect(
        PurchaseOrderMailDraft(senderEmail: bad).validFor(stored),
        isFalse,
        reason: bad,
      );
    }
  });

  group('the Demo simulates and keeps the fences', () {
    test(
      'nothing is sent before the mail is configured, nor without a recipient',
      () async {
        final (repo, _, order) = await _withOrder();
        await expectLater(
          repo.sendByEmail('ws', order, 'a1', _mail),
          throwsA(isA<PostgrestException>()),
        );
        final (noRecipient, _, bare) = await _withOrder(email: '');
        noRecipient.mail = const PurchaseOrderMailSettings(
          senderEmail: 'a@b.co',
          hasApiKey: true,
          revision: 1,
        );
        await expectLater(
          noRecipient.sendByEmail('ws', bare, 'a1', _mail),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('a send is accepted, recorded, the order sent by e-mail; the same id replays', () async {
      final (repo, _, order) = await _withOrder();
      await repo.saveMailSettings(
        'ws',
        const PurchaseOrderMailDraft(
          senderEmail: 'orders@space.test',
          apiKey: 're_test_123456',
        ),
      );
      final sent = await repo.sendByEmail('ws', order, 'a1', _mail);
      expect(
        (sent.state, sent.recipient),
        (PurchaseOrderSendState.accepted, 'orders@alpha.test'),
      );
      final now = repo.orders.single;
      expect((now.state, now.sentVia), (PurchaseOrderState.sent, 'email'));
      expect((await repo.sendByEmail('ws', order, 'a1', _mail)).id, 'a1');
      expect(repo.sends, hasLength(1));
      await expectLater(
        repo.sendByEmail('ws', now, 'a2', _mail),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'an unconfirmed attempt blocks another until a person decides',
      () async {
        final (repo, _, order) = await _withOrder();
        repo.mail = const PurchaseOrderMailSettings(
          senderEmail: 'a@b.co',
          hasApiKey: true,
          revision: 1,
        );
        repo.sends.add(
          const PurchaseOrderSend(
            id: 'lost',
            orderId: 'demo-order-1',
            state: PurchaseOrderSendState.unconfirmed,
            recipient: 'orders@alpha.test',
          ),
        );
        await expectLater(
          repo.sendByEmail('ws', order, 'a2', _mail),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '55000'),
          ),
        );
        // While it may be on its way, the order is neither marked sent by
        // print nor cancelled.
        for (final write in [
          () => repo.markSent('ws', order.id, order.revision, 'm1'),
          () => repo.cancel('ws', order.id, order.revision, 'late', 'c1'),
        ]) {
          await expectLater(
            write(),
            throwsA(
              isA<PostgrestException>().having((e) => e.code, 'code', '55000'),
            ),
          );
        }
        final decided = await repo.resolveSend('ws', 'lost', delivered: false);
        expect(decided.state, PurchaseOrderSendState.notDelivered);
        expect(repo.orders.single.state, PurchaseOrderState.draft);
        expect(
          (await repo.sendByEmail('ws', order, 'a2', _mail)).state,
          PurchaseOrderSendState.accepted,
        );
      },
    );
  });

  testWidgets(
    'the screen asks a person whether an unconfirmed e-mail arrived',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (repo, suppliers, order) = await _withOrder();
      repo.mail = const PurchaseOrderMailSettings(
        senderEmail: 'a@b.co',
        hasApiKey: true,
        revision: 1,
      );
      repo.sends.add(
        PurchaseOrderSend(
          id: 'lost',
          orderId: order.id,
          state: PurchaseOrderSendState.unconfirmed,
          recipient: 'orders@alpha.test',
        ),
      );
      await tester.pumpWidget(
        _scope([
          currentWorkspaceProvider.overrideWith(
            (ref) async => const Workspace(
              id: 'ws',
              name: 'Space',
              countryCode: 'FR',
              currencyCode: 'EUR',
              timezone: 'Europe/Paris',
              inviteCode: 'x',
            ),
          ),
          myMemberProvider.overrideWith((ref) async => null),
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.managePurchases,
            WorkspacePermission.manageBilling,
          }),
          enabledFeaturesSyncProvider.overrideWithValue({
            WorkspaceFeature.purchases,
            WorkspaceFeature.purchaseOrders,
          }),
          supplierRepositoryProvider.overrideWithValue(suppliers),
          purchaseOrderRepositoryProvider.overrideWithValue(repo),
          servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
        ]),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.byKey(const ValueKey('purchase-order-mail-settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('purchase-order-awaits-2026-0001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('purchase-order-email-2026-0001')),
        findsNothing,
        reason: 'no new send while the earlier one awaits a decision',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('purchase-order-arrived-2026-0001')),
      );
      await tester.tap(
        find.byKey(const ValueKey('purchase-order-arrived-2026-0001')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.sends.single.state, PurchaseOrderSendState.delivered);
      expect(
        (repo.orders.single.state, repo.orders.single.sentVia),
        (PurchaseOrderState.sent, 'email'),
      );
    },
  );

  testWidgets(
    'a pending attempt with no outcome is decided by a person too (#3774)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (repo, suppliers, order) = await _withOrder();
      repo.mail = const PurchaseOrderMailSettings(
        senderEmail: 'a@b.co',
        hasApiKey: true,
        revision: 1,
      );
      repo.sends.add(
        PurchaseOrderSend(
          id: 'lost',
          orderId: order.id,
          state: PurchaseOrderSendState.pending,
          recipient: 'orders@alpha.test',
        ),
      );
      await tester.pumpWidget(
        _scope([
          currentWorkspaceProvider.overrideWith(
            (ref) async => const Workspace(
              id: 'ws',
              name: 'Space',
              countryCode: 'FR',
              currencyCode: 'EUR',
              timezone: 'Europe/Paris',
              inviteCode: 'x',
            ),
          ),
          myMemberProvider.overrideWith((ref) async => null),
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.managePurchases,
            WorkspacePermission.manageBilling,
          }),
          enabledFeaturesSyncProvider.overrideWithValue({
            WorkspaceFeature.purchases,
            WorkspaceFeature.purchaseOrders,
          }),
          supplierRepositoryProvider.overrideWithValue(suppliers),
          purchaseOrderRepositoryProvider.overrideWithValue(repo),
          servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
        ]),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.byKey(const ValueKey('purchase-order-mail-settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('purchase-order-awaits-2026-0001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('purchase-order-email-2026-0001')),
        findsNothing,
        reason: 'no new send while the earlier one awaits a decision',
      );
    },
  );
}

// #3774 — the function's 409 is the decision a person owes; a pending
// attempt in the list has no outcome either and is decided the same way.
void _undecided() {
  test('the send function\'s 409 is an earlier e-mail to decide first', () {
    expect(
      SupabasePurchaseOrderRepository.sendFailureOf(
        const FunctionException(status: 409, details: {'code': '55000'}),
      ),
      isA<PurchaseOrderSendUndecided>(),
    );
    const other = FunctionException(status: 502);
    expect(SupabasePurchaseOrderRepository.sendFailureOf(other), same(other));
  });
}

Widget _scope(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PurchaseOrdersScreen(),
  ),
);
