// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the engagement screens as an issuer uses them, on a phone and on
// a desk: the list says where each service stands and is never an empty list when
// it could not be read; the engagement shows its history and what is billed and
// paid beside it; a step is the server's decision (a stale one is refused and the
// engagement read again, a lost answer is retried under the same request, a
// cancellation needs its reason); a direct engagement is committed from a form.
import 'package:deskilo/core/demo/data/fake_billing_customers.dart';
import 'package:deskilo/core/demo/data/fake_customer_quotes.dart';
import 'package:deskilo/core/demo/data/fake_service_fulfilments.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:deskilo/features/money/domain/service_fulfilment.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/presentation/screens/customer_quote_screen.dart';
import 'package:deskilo/features/money/presentation/screens/service_fulfilment_screen.dart';
import 'package:deskilo/features/money/presentation/screens/service_fulfilments_screen.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/money/providers/customer_quote_providers.dart';
import 'package:deskilo/features/money/providers/service_fulfilment_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
final _now = DateTime.utc(2026, 11, 21, 10);

const _lumi = BillingParty(
  subjectId: 'c-1',
  revision: 1,
  capacity: 'business',
  draft: BillingPartyDraft(
    company: 'Atelier Lumi',
    city: 'Pezenas',
    countryCode: 'FR',
  ),
);

/// The fake repository a test can make fail, to stand for the server.
class _Repo extends FakeServiceFulfilmentRepository {
  _Repo({
    required super.workspaceId,
    required super.quotes,
    required super.hasCustomer,
  }) : super(
         invoices: () => const [],
         matches: () => const {},
         actor: () => 'owner',
         clock: () => _now,
       );

  /// What the next step does instead of answering: a refusal, or nothing came back.
  Exception? failNext;

  /// The request identities steps were taken under, in order.
  final stepRequests = <String>[];

  @override
  Future<ServiceFulfilment> transition(
    String workspaceId,
    String fulfilmentId, {
    required int expectedRevision,
    required FulfilmentState to,
    required String requestId,
    String reason = '',
  }) async {
    stepRequests.add(requestId);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return super.transition(
      workspaceId,
      fulfilmentId,
      expectedRevision: expectedRevision,
      to: to,
      requestId: requestId,
      reason: reason,
    );
  }
}

class _Setup {
  _Setup(this.repo, this.workspaceId);

  final _Repo repo;
  final String workspaceId;
}

Future<_Setup> _open(
  WidgetTester tester,
  Size size,
  String initial, {
  bool seeded = true,
  Set<WorkspacePermission>? permissions,
  bool acceptedQuote = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final quotes = FakeCustomerQuoteRepository(clock: () => _now);
  final customers = FakeBillingCustomerRepository();
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/money/engagements',
        builder: (_, _) => const ServiceFulfilmentsScreen(),
      ),
      GoRoute(
        path: '/money/quotes/:id',
        builder: (_, s) => CustomerQuoteScreen(quoteId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/money/engagements/:id',
        builder: (_, s) =>
            ServiceFulfilmentScreen(fulfilmentId: s.pathParameters['id']!),
      ),
    ],
  );
  await pumpApp(
    tester,
    null,
    router: router,
    overrides: [
      ...standardTestOverrides(),
      customerQuoteRepositoryProvider.overrideWithValue(quotes),
      billingCustomerRepositoryProvider.overrideWithValue(customers),
      serviceFulfilmentRepositoryProvider.overrideWith((ref) {
        final workspaceId = ref.read(currentWorkspaceProvider).value!.id;
        return _Repo(
          workspaceId: workspaceId,
          quotes: quotes,
          hasCustomer: (id) => id == 'c-1',
        );
      }),
      enabledFeaturesSyncProvider.overrideWithValue({
        WorkspaceFeature.serviceFulfilment,
      }),
      myPermissionsProvider.overrideWithValue(
        permissions ??
            const {
              WorkspacePermission.issueInvoices,
              WorkspacePermission.viewFinances,
            },
      ),
    ],
  );
  await _settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  final workspaceId = container.read(currentWorkspaceProvider).value!.id;
  customers.seed(workspaceId, _lumi);
  container.invalidate(billingCustomersProvider(workspaceId));
  if (acceptedQuote) {
    quotes
      ..seedSent(
        workspaceId,
        subjectId: 'c-1',
        lines: const [
          StandaloneLine(
            description: 'Training',
            quantity: '1',
            unitCode: 'unit',
            unitLabel: 'day',
            unEceCode: 'DAY',
            unitPrice: '400',
          ),
        ],
        issuedOn: _now.subtract(const Duration(days: 2)),
        validUntil: _now.add(const Duration(days: 20)),
      )
      ..seedAccepted(
        workspaceId,
        0,
        decidedOn: _now.subtract(const Duration(days: 1)),
      );
    container.invalidate(customerQuotesProvider(workspaceId));
  }
  await _settle(tester);
  final read = container.read(serviceFulfilmentRepositoryProvider) as _Repo;
  if (seeded) {
    await read.openDirect(
      workspaceId,
      requestId: 'seed-1',
      input: const DirectEngagementInput(
        subjectId: 'c-1',
        description: 'Coaching',
        quantity: '3',
        unit: 'session',
      ),
    );
    container.invalidate(serviceFulfilmentsProvider(workspaceId));
    await _settle(tester);
  }
  return _Setup(read, workspaceId);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await _settle(tester);
}

void main() {
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desk', const Size(1440, 900)),
  ]) {
    group('on a $name', () {
      testWidgets(
        'the list says where each service stands, for whom and where it came from',
        (tester) async {
          final s = await _open(tester, size, '/money/engagements');
          final id = (await s.repo.fulfilments(s.workspaceId)).single.id;

          expect(find.text('3 session · Coaching'), findsOneWidget);
          expect(
            find.text('Atelier Lumi · ${_en.engagementDirect}'),
            findsOneWidget,
          );
          expect(find.byKey(ValueKey('engagement-state-$id')), findsOneWidget);
          expect(find.text(_en.engagementStateOrdered), findsOneWidget);
          expect(find.byKey(const ValueKey('engagement-new')), findsOneWidget);
        },
      );

      testWidgets(
        'with nothing it says so, and a person who may not issue has no New door',
        (tester) async {
          await _open(
            tester,
            size,
            '/money/engagements',
            seeded: false,
            permissions: const {WorkspacePermission.viewFinances},
          );

          expect(
            find.byKey(const ValueKey('engagements-empty')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('engagement-new')), findsNothing);
        },
      );

      testWidgets('an engagement is committed from the form and then listed', (
        tester,
      ) async {
        final s = await _open(
          tester,
          size,
          '/money/engagements',
          seeded: false,
        );
        await _tap(tester, 'engagement-new');
        await tester.tap(
          find.byKey(const ValueKey('engagement-direct-customer')),
        );
        await _settle(tester);
        await tester.tap(find.text('Atelier Lumi').last);
        await _settle(tester);
        await tester.enterText(
          find.byKey(const ValueKey('engagement-direct-description')),
          'Workshop',
        );
        await tester.enterText(
          find.byKey(const ValueKey('engagement-direct-quantity')),
          '2',
        );
        // #4471 -- the unit is picked from the business's units, never typed
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('engagement-direct-unit')),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('engagement-direct-unit')));
        await _settle(tester);
        await tester.tap(find.text('kg').last);
        await _settle(tester);
        await _tap(tester, 'engagement-direct-save');

        final all = await s.repo.fulfilments(s.workspaceId);
        expect(all.single.scope.description, 'Workshop');
        expect(all.single.scope.quantity, '2');
        expect(all.single.scope.unit, 'kg');
        expect(find.text('2 kg · Workshop'), findsOneWidget);
      });

      testWidgets(
        'a mistake in the form is shown under its field and nothing is committed',
        (tester) async {
          final s = await _open(
            tester,
            size,
            '/money/engagements',
            seeded: false,
          );
          await _tap(tester, 'engagement-new');
          await tester.enterText(
            find.byKey(const ValueKey('engagement-direct-quantity')),
            'abc',
          );
          await _tap(tester, 'engagement-direct-save');

          expect(await s.repo.fulfilments(s.workspaceId), isEmpty);
          expect(find.text(_en.engagementRefusedIncomplete), findsWidgets);
        },
      );

      testWidgets(
        'the engagement is followed to done, its history growing and the books untouched',
        (tester) async {
          final s = await _open(tester, size, '/money/engagements');
          final id = (await s.repo.fulfilments(s.workspaceId)).single.id;
          await tester.tap(find.byKey(ValueKey('engagement-row-$id')));
          await _settle(tester);

          expect(
            find.byKey(const ValueKey('engagement-title')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('engagement-no-invoice')),
            findsOneWidget,
          );
          await _tap(tester, 'engagement-step-started');
          expect(
            find.byKey(const ValueKey('engagement-state')),
            findsOneWidget,
          );
          expect(find.text(_en.engagementStateStarted), findsWidgets);
          await _tap(tester, 'engagement-step-done');

          final e = await s.repo.fulfilment(s.workspaceId, id);
          expect(e.state, FulfilmentState.done);
          expect(e.history.map((h) => h.to), [
            FulfilmentState.ordered,
            FulfilmentState.started,
            FulfilmentState.done,
          ]);
          expect(
            find.byKey(const ValueKey('engagement-step-started')),
            findsNothing,
            reason: 'nothing leaves done',
          );
          expect(
            find.byKey(const ValueKey('engagement-step-row-3')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'a stale step is refused and the engagement is read again; a lost answer is retried under the same request',
        (tester) async {
          final s = await _open(tester, size, '/money/engagements');
          final id = (await s.repo.fulfilments(s.workspaceId)).single.id;
          await tester.tap(find.byKey(ValueKey('engagement-row-$id')));
          await _settle(tester);

          s.repo.failNext = const FulfilmentRefusal(
            FulfilmentRefusalKind.stale,
            detail: '2',
          );
          await _tap(tester, 'engagement-step-started');
          expect(find.text(_en.engagementRefusedStale), findsOneWidget);
          expect(
            (await s.repo.fulfilment(s.workspaceId, id)).state,
            FulfilmentState.ordered,
            reason: 'a refused step wrote nothing',
          );

          s.repo.failNext = Exception('the connection is lost');
          await _tap(tester, 'engagement-step-started');
          expect(find.text(_en.engagementUnreached), findsOneWidget);
          await _tap(tester, 'engagement-step-started');

          final last3 = s.repo.stepRequests.reversed.take(2).toList();
          expect(
            last3[0],
            last3[1],
            reason: 'the retry after a lost answer keeps its request identity',
          );
          expect(
            (await s.repo.fulfilment(s.workspaceId, id)).state,
            FulfilmentState.started,
          );
        },
      );

      testWidgets(
        'a cancellation asks for its reason and keeps it in the history',
        (tester) async {
          final s = await _open(tester, size, '/money/engagements');
          final id = (await s.repo.fulfilments(s.workspaceId)).single.id;
          await tester.tap(find.byKey(ValueKey('engagement-row-$id')));
          await _settle(tester);

          await _tap(tester, 'engagement-step-cancelled');
          await _tap(tester, 'engagement-cancel-confirm');
          expect(
            find.text(_en.engagementRefusedIncomplete),
            findsOneWidget,
            reason: 'no reason: nothing is sent',
          );
          expect(
            (await s.repo.fulfilment(s.workspaceId, id)).state,
            FulfilmentState.ordered,
          );

          await _tap(tester, 'engagement-step-cancelled');
          await tester.enterText(
            find.byKey(const ValueKey('engagement-cancel-reason')),
            'the customer withdrew',
          );
          await _tap(tester, 'engagement-cancel-confirm');

          final e = await s.repo.fulfilment(s.workspaceId, id);
          expect(e.state, FulfilmentState.cancelled);
          expect(e.history.last.reason, 'the customer withdrew');
          expect(find.text(_en.engagementStateCancelled), findsWidgets);
        },
      );

      testWidgets(
        'a person who may only read sees the engagement and no step',
        (tester) async {
          final s = await _open(
            tester,
            size,
            '/money/engagements',
            permissions: const {WorkspacePermission.viewFinances},
          );
          final id = (await s.repo.fulfilments(s.workspaceId)).single.id;
          await tester.tap(find.byKey(ValueKey('engagement-row-$id')));
          await _settle(tester);

          expect(
            find.byKey(const ValueKey('engagement-title')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('engagement-step-started')),
            findsNothing,
          );
        },
      );
    });
  }
}
