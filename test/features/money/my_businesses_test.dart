// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (A) -- Me › My businesses: each business's receivables per currency,
// side by side and never added; a refund due apart from what is owed; a business
// that could not be read is said, never a zero; a business the person may not
// read is not shown; a source keeps the installation and workspace it came
// from; a development space is not read.
import 'package:deskilo/app/finance_hosts_wiring.dart';
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/features/money/domain/business_payables.dart';
import 'package:deskilo/features/money/domain/business_receivables.dart';
import 'package:deskilo/features/money/domain/supplier_balance.dart';
import 'package:deskilo/features/money/domain/supplier_payables_page.dart';
import 'package:deskilo/features/money/presentation/widgets/my_businesses_face.dart';
import 'package:deskilo/features/money/providers/business_receivables_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

WorkspaceTarget _target(String installation, String id) => WorkspaceTarget.local(
  installationId: installation,
  workspaceId: id,
);

const _eur = BusinessReceivablesRow(
  currency: 'EUR',
  toCollectCents: 34200,
  declaredCents: 6000,
  receivedUnmatchedCents: 0,
  awaitingCents: 0,
  refundDueCents: 2500,
  invoices: 3,
);
const _usd = BusinessReceivablesRow(
  currency: 'USD',
  toCollectCents: 1000,
  declaredCents: 0,
  receivedUnmatchedCents: 0,
  awaitingCents: 0,
  refundDueCents: 0,
  invoices: 1,
);

Workspace _workspace(String id, {String environment = 'prod'}) => Workspace(
  id: id,
  name: 'Business $id',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
  environment: environment,
);

class _Repo implements BusinessReceivablesRepository {
  _Repo(this.answers);
  final Map<String, Object> answers;

  final reads = <String>[];

  @override
  Future<BusinessReceivables> summary(String workspaceId) async {
    reads.add(workspaceId);
    final answer = answers[workspaceId];
    if (answer is BusinessReceivables) return answer;
    throw answer! as Exception;
  }

  @override
  Future<ReceivablesPage> page(
    String workspaceId,
    String currency, {
    ReceivableState? state,
    ReceivablesCursor? after,
  }) => throw UnimplementedError();
}

void main() {
  test('the summary reads per currency; the receivable leaves the refund out',
      () {
    final summary = BusinessReceivables.fromJson(const {
      'workspace_id': 'ws-a',
      'rows': [
        {
          'currency': 'EUR',
          'to_collect_cents': 34200,
          'declared_cents': 6000,
          'received_unmatched_cents': 5000,
          'awaiting_cents': 1000,
          'refund_due_cents': 2500,
          'receivable_cents': 46200,
          'invoices': 5,
        },
        {
          'currency': 'GBP',
          'to_collect_cents': 24000,
          'declared_cents': 0,
          'received_unmatched_cents': 0,
          'awaiting_cents': 0,
          'refund_due_cents': 0,
          'invoices': 1,
        },
      ],
    });
    expect(summary.rows.map((r) => r.currency), ['EUR', 'GBP']);
    expect(summary.rows.first.receivableCents, 46200);
    expect(summary.rows.first.refundDueCents, 2500);
    expect(summary.rows.last.receivableCents, 24000);
  });

  testWidgets('currencies stand side by side and are never added; the refund '
      'is its own line; an unreadable business is not zero; a refused one is '
      'absent', (tester) async {
    String? opened;
    var retried = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: MyBusinessesFace(
          sources: [
            BusinessReceivablesAnswered(
              _target('inst-1', 'ws-a'),
              'Studio A',
              const BusinessReceivables(workspaceId: 'ws-a', rows: [_eur, _usd]),
            ),
            BusinessReceivablesUnavailable(_target('inst-1', 'ws-b'), 'Studio B'),
            BusinessReceivablesRefused(_target('inst-1', 'ws-c'), 'Studio C'),
          ],
          onRetry: () => retried++,
          onOpen: (id) => opened = id,
          onDetail: (_) {},
        ),
      ),
      size: const Size(800, 1200),
    );
    // EUR 402.00 (342 + 60) and USD 10.00, each in its own row.
    expect(find.byKey(const ValueKey('my-business-owed-EUR')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('my-business-owed-EUR'))).data,
      contains('402'),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('my-business-owed-USD'))).data,
      contains('10'),
    );
    // never one figure over both currencies: 412.00 appears nowhere
    expect(find.textContaining('412'), findsNothing);
    // the refund due is a line of its own, not taken off the receivable
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('my-business-refund-EUR'))).data,
      contains('25'),
    );
    // the business that could not be read says so and has no figure
    expect(find.byKey(const ValueKey('my-business-unavailable-ws-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-business-currency-EUR')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('my-business-retry-ws-b')));
    expect(retried, 1);
    // the business the person may not read is not listed at all
    expect(find.text('Studio C'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('my-business-open-ws-a')));
    expect(opened, 'ws-a');
  });

  test('a business answers, refuses or fails on its own; a development space '
      'is not read; the source keeps its installation', () async {
    final repo = _Repo({
      'ws-a': const BusinessReceivables(workspaceId: 'ws-a', rows: [_eur]),
      'ws-b': const BusinessReceivablesRefusal(),
      'ws-c': Exception('offline'),
    });
    final container = ProviderContainer(
      overrides: [
        businessReceivablesRepositoryProvider.overrideWithValue(repo),
        businessInstallationIdProvider.overrideWith((ref) => 'inst-9'),
        businessWorkspacesFromApp,
        myWorkspacesProvider.overrideWith(
          (ref) async => [
            _workspace('ws-a'),
            _workspace('ws-b'),
            _workspace('ws-c'),
            _workspace('ws-dev', environment: 'dev'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final sources = await container.read(myBusinessReceivablesProvider.future);
    expect(sources.map((s) => s.runtimeType), [
      BusinessReceivablesAnswered,
      BusinessReceivablesRefused,
      BusinessReceivablesUnavailable,
    ]);
    expect(repo.reads, unorderedEquals(['ws-a', 'ws-b', 'ws-c']));
    expect(sources.first.target.installationId, 'inst-9');
    expect(sources.first.target.financeKey, 'inst-9:ws-a');
  });

  group('what a business has to pay (B)', () {
    const suppliers = [
      SupplierBalance(supplierId: 's1', currency: 'EUR', remainingCents: 12500, heldCents: 2500),
      SupplierBalance(supplierId: 's2', currency: 'EUR', remainingCents: 500, heldCents: 0),
      SupplierBalance(supplierId: 's3', currency: 'GBP', remainingCents: 3000, heldCents: 0),
    ];
    const members = MemberReimbursements(
      workspaceId: 'ws-a',
      rows: [
        MemberReimbursementRow(currency: 'EUR', remainingCents: 4000, heldCents: 0, obligations: 2),
      ],
    );
    final target = _target('inst-1', 'ws-a');

    test('the two directions stay apart, held is inside what remains, '
        'currencies are rows of their own', () {
      final payables = BusinessPayables(
        target: target,
        name: 'Studio A',
        suppliers: const PayablesAnswered(suppliers),
        members: const PayablesAnswered(members),
      );
      final eur = payables.currencies.firstWhere((c) => c.currency == 'EUR');
      expect(eur.supplierCents, 13000);
      expect(eur.memberCents, 4000);
      expect(eur.totalCents, 17000); // held 25.00 is already inside 125.00
      expect(eur.heldCents, 2500);
      expect(payables.currencies.map((c) => c.currency), ['EUR', 'GBP']);
      expect(payables.currencies.last.totalCents, 3000);
    });

    testWidgets('a direction that was refused or could not be read is said, '
        'never a zero; the other direction still shows', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: MyBusinessesFace(
            sources: [
              BusinessReceivablesAnswered(
                target,
                'Studio A',
                const BusinessReceivables(workspaceId: 'ws-a', rows: []),
              ),
            ],
            payables: [
              BusinessPayables(
                target: target,
                name: 'Studio A',
                suppliers: const PayablesAnswered(suppliers),
                members: const PayablesRefused(),
              ),
            ],
            onRetry: () {},
            onOpen: (_) {},
            onDetail: (_) {},
          ),
        ),
        size: const Size(800, 1400),
      );
      expect(find.byKey(const ValueKey('my-business-payable-EUR')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('my-business-payable-suppliers-EUR'))).data,
        contains('130'),
      );
      expect(find.byKey(const ValueKey('my-business-payable-members-EUR')), findsNothing);
      expect(find.byKey(const ValueKey('my-business-payable-held-EUR')), findsOneWidget);
      expect(find.byKey(const ValueKey('my-business-payables-note-ws-a')), findsOneWidget);
      // pounds beside euros, never one figure over both
      expect(find.byKey(const ValueKey('my-business-payable-GBP')), findsOneWidget);
    });

    test('each direction answers, refuses or fails on its own', () async {
      final container = ProviderContainer(
        overrides: [
          businessPayablesRepositoryProvider.overrideWithValue(
            _Payables(
              suppliers: () async => suppliers,
              members: () async => throw const BusinessPayablesRefusal(),
            ),
          ),
          businessInstallationIdProvider.overrideWith((ref) => 'inst-9'),
          myBusinessWorkspacesProvider.overrideWith(
            (ref) async => [(networkId: '', id: 'ws-a', name: 'Studio A')],
          ),
        ],
      );
      addTearDown(container.dispose);
      final list = await container.read(myBusinessPayablesProvider.future);
      expect(list.single.suppliers, isA<PayablesAnswered<List<SupplierBalance>>>());
      expect(list.single.members, isA<PayablesRefused<MemberReimbursements>>());
      expect(list.single.target.financeKey, 'inst-9:ws-a');

      final failing = ProviderContainer(
        overrides: [
          businessPayablesRepositoryProvider.overrideWithValue(
            _Payables(
              suppliers: () async => throw Exception('offline'),
              members: () async => members,
            ),
          ),
          businessInstallationIdProvider.overrideWith((ref) => 'inst-9'),
          myBusinessWorkspacesProvider.overrideWith(
            (ref) async => [(networkId: '', id: 'ws-a', name: 'Studio A')],
          ),
        ],
      );
      addTearDown(failing.dispose);
      final second = await failing.read(myBusinessPayablesProvider.future);
      expect(second.single.suppliers, isA<PayablesUnavailable<List<SupplierBalance>>>());
      expect(second.single.members, isA<PayablesAnswered<MemberReimbursements>>());
    });
  });
}

class _Payables implements BusinessPayablesRepository {
  _Payables({required this.suppliers, required this.members});

  final Future<List<SupplierBalance>> Function() suppliers;
  final Future<MemberReimbursements> Function() members;

  @override
  Future<List<SupplierBalance>> supplierBalances(String workspaceId) => suppliers();

  @override
  Future<MemberReimbursements> memberReimbursements(String workspaceId) => members();

  @override
  Future<SupplierPayablesPage> payablesPage(
    String workspaceId,
    String currency, {
    String? creditorKind,
    SupplierPayablesCursor? after,
  }) => throw UnimplementedError();
}
