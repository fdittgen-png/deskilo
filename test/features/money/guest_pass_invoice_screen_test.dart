// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3837 — a revoked guest pass leads to its invoice and says whether the
// money is corrected: the revoke result opens the invoice at its address,
// the State cell says "not corrected yet" until a credit note or a void
// exists, the chip finds exactly the revoked passes still to correct, and
// a row opens its invoice. A free pass has no invoice and says nothing.
//
// "Who may not read the finances gets no link" cannot occur here: the
// passes table is built only for who may read the invoices
// (guest_passes_screen.dart), the same rights `/invoices/:id` admits.
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/presentation/screens/guest_passes_screen.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

GuestPassRecord _pass(
  String id,
  String guest, {
  String? invoiceId,
  bool revoked = false,
}) => GuestPassRecord(
  id: id,
  memberId: guest,
  offerId: 'day',
  unit: GuestPassUnit.day,
  units: 2,
  amountCents: invoiceId == null ? 0 : 4800,
  startsAt: DateTime.utc(2030, 1, 7, 8),
  endsAt: DateTime.utc(2030, 1, 8, 16),
  revokedAt: revoked ? DateTime.utc(2026, 11, 13) : null,
  invoiceId: invoiceId,
);

Invoice _invoice(String id, String guest, {int total = 4800}) => Invoice(
  id: id,
  workspaceId: 'ws',
  memberId: guest,
  number: 'F-$id',
  issuedAt: DateTime.utc(2026, 11, 2),
  title: 'Guest pass',
  lines: [InvoiceLine(label: 'Day pass', amountCents: total)],
  totalCents: total,
  currency: 'EUR',
  memberName: guest,
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'O',
  signature: '',
);

class _Passes implements GuestPassRepository {
  _Passes(this.records);

  List<GuestPassRecord> records;

  @override
  Future<List<GuestPassOffer>> offers(String workspaceId) async => const [
    GuestPassOffer(
      id: 'day',
      name: 'Day pass',
      unit: GuestPassUnit.day,
      priceCents: 2400,
    ),
  ];

  @override
  Future<List<GuestPassRecord>> passesSold(String workspaceId) async => records;

  @override
  Future<int> revoke(
    String workspaceId, {
    required String passId,
    required String requestId,
  }) async {
    records = [
      for (final p in records)
        if (p.id == passId)
          _pass(p.id, p.memberId, invoiceId: p.invoiceId, revoked: true)
        else
          p,
    ];
    return 2;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The passes at their page and an invoice at its address.
Future<List<Invoice>> _pump(WidgetTester tester, _Passes passes) async {
  tester.view.physicalSize = const Size(1440, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final invoices = [_invoice('inv-1', 'g1'), _invoice('inv-2', 'g2')];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentWorkspaceProvider.overrideWith((ref) async => _workspace),
        myMemberProvider.overrideWith((ref) async => null),
        myPermissionsProvider.overrideWithValue({
          WorkspacePermission.issueInvoices,
          WorkspacePermission.viewFinances,
        }),
        guestPassRepositoryProvider.overrideWithValue(passes),
        memberLabelsProvider.overrideWithValue(const {
          'g1': 'Gale Guest',
          'g2': 'Hal Host',
          'g3': 'Ivy Free',
        }),
        invoicesProvider.overrideWith((ref) async => [...invoices]),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/money/guest-passes',
          routes: [
            GoRoute(
              path: '/money/guest-passes',
              builder: (context, state) => const GuestPassesScreen(),
            ),
            GoRoute(
              path: '/invoices/:id',
              builder: (context, state) =>
                  Scaffold(body: Text('invoice ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return invoices;
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(GuestPassesScreen, skipOffstage: false).first),
);

void main() {
  testWidgets('the revoke result opens each revoked pass\'s invoice at its '
      'address and says it is not corrected yet', (tester) async {
    final passes = _Passes([_pass('p1', 'g1', invoiceId: 'inv-1')]);
    await _pump(tester, passes);
    await tester.tap(find.byKey(const ValueKey('records-select-shown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-bulk-revoke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guest-pass-revoke-confirm')));
    await tester.pumpAndSettle();

    final result = find.byKey(const ValueKey('guest-pass-revoke-result'));
    expect(
      find.descendant(
        of: result,
        matching: find.textContaining('Invoice F-inv-1 not corrected yet'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('guest-pass-open-invoice-p1')));
    await tester.pumpAndSettle();
    expect(find.text('invoice inv-1'), findsOneWidget);
  });

  testWidgets('a revoked pass says "not corrected yet" until its guest has a '
      'credit note; the chip lists exactly those still to correct', (
    tester,
  ) async {
    final passes = _Passes([
      _pass('p1', 'g1', invoiceId: 'inv-1', revoked: true),
      _pass('p2', 'g2', invoiceId: 'inv-2'),
      _pass('p3', 'g3', revoked: true),
    ]);
    final invoices = await _pump(tester, passes);
    final line = find.byKey(const ValueKey('guest-pass-invoice-p1'));
    expect(tester.widget<Text>(line).data, 'Invoice F-inv-1 not corrected yet');
    expect(
      find.byKey(const ValueKey('guest-pass-invoice-p3')),
      findsNothing,
      reason: 'a free pass has no invoice to correct',
    );

    await tester.tap(find.byKey(const ValueKey('records-chip-uncorrected')));
    await tester.pumpAndSettle();
    expect(find.text('Gale Guest'), findsOneWidget);
    expect(find.text('Hal Host'), findsNothing, reason: 'not revoked');
    expect(find.text('Ivy Free'), findsNothing, reason: 'no invoice');

    invoices.add(_invoice('cn-1', 'g1', total: -4800));
    _container(tester).invalidate(invoicesProvider);
    await tester.pumpAndSettle();
    expect(
      find.text('Gale Guest'),
      findsNothing,
      reason: 'nothing left to correct',
    );
    await tester.tap(find.byKey(const ValueKey('records-chip-uncorrected')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(line).data, 'Invoice F-inv-1 corrected');
  });

  testWidgets('a row opens its invoice; a free pass opens nothing', (
    tester,
  ) async {
    final passes = _Passes([
      _pass('p1', 'g1', invoiceId: 'inv-1'),
      _pass('p3', 'g3'),
    ]);
    await _pump(tester, passes);
    await tester.tap(find.text('Ivy Free'));
    await tester.pumpAndSettle();
    expect(find.byType(GuestPassesScreen), findsOneWidget);
    await tester.tap(find.text('Gale Guest'));
    await tester.pumpAndSettle();
    expect(find.text('invoice inv-1'), findsOneWidget);
  });
}
