// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the guest passes screen: the space's passes and who sees what,
// and a sale through THE identity form with the pass in its extra
// section: one Save sends the guest's identity, the place and the window.
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/presentation/screens/guest_passes_screen.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

class _Passes implements GuestPassRepository {
  _Passes({this.records = const [], this.refused = const {}});

  final sold = <({GuestPassDraft draft, Map<String, dynamic> guest, String requestId})>[];

  /// #3829 — the passes sold, and which of them the server refuses to revoke.
  List<GuestPassRecord> records;
  final Set<String> refused;
  final revoked = <({String passId, String requestId})>[];

  @override
  Future<List<GuestPassOffer>> offers(String workspaceId) async => const [
        GuestPassOffer(id: 'day', name: 'Day pass', unit: GuestPassUnit.day, priceCents: 2400),
      ];

  @override
  Future<List<GuestPassRecord>> passesSold(String workspaceId) async => records;

  @override
  Future<List<GuestPassPlace>> places(String workspaceId) async => const [(seatId: 'seat-1', label: 'Ground · A1')];

  @override
  Future<String> saveOffer(String workspaceId,
          {String? id,
          required String name,
          required GuestPassUnit unit,
          required int priceCents,
          String? vatRateId,
          bool active = true}) async =>
      'new';

  @override
  Future<GuestPassSale> sell(String workspaceId,
      {required GuestPassDraft draft, required Map<String, dynamic> guest, required String requestId}) async {
    sold.add((draft: draft, guest: guest, requestId: requestId));
    return GuestPassSale(
      passId: 'p',
      memberId: 'g',
      reservationIds: const ['r'],
      units: draft.days,
      amountCents: draft.days * 2400,
      invoiceId: 'i',
    );
  }

  @override
  Future<int> revoke(String workspaceId, {required String passId, required String requestId}) async {
    revoked.add((passId: passId, requestId: requestId));
    if (refused.contains(passId)) {
      throw const PostgrestException(message: 'this guest pass is already revoked', code: 'DKD01');
    }
    records = [
      for (final p in records)
        if (p.id == passId)
          GuestPassRecord(
                id: p.id,
                memberId: p.memberId,
                offerId: p.offerId,
                unit: p.unit,
                units: p.units,
                amountCents: p.amountCents,
                startsAt: p.startsAt,
                endsAt: p.endsAt,
                revokedAt: DateTime.utc(2026, 11, 13),
                cancelledBookings: 2,
              )
        else
          p,
    ];
    return 2;
  }
}

Future<void> _pump(WidgetTester tester, _Passes passes, Set<WorkspacePermission> held) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentWorkspaceProvider.overrideWith((ref) async => _workspace),
        myMemberProvider.overrideWith((ref) async => null),
        myPermissionsProvider.overrideWithValue(held),
        guestPassRepositoryProvider.overrideWithValue(passes),
        memberLabelsProvider.overrideWithValue(const {'g1': 'Gale Guest', 'g2': 'Hal Host'}),
        // #3837 — the table reads the invoices beside the passes.
        invoicesProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GuestPassesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the passes are listed; pricing and selling follow the rights', (tester) async {
    await _pump(tester, _Passes(), {WorkspacePermission.issueInvoices, WorkspacePermission.manageServices});
    expect(find.text('Day pass'), findsOneWidget);
    expect(find.textContaining('per day'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-pass-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-pass-sell')), findsOneWidget);

    await _pump(tester, _Passes(), const {});
    expect(find.text('Day pass'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-pass-add')), findsNothing);
    expect(find.byKey(const ValueKey('guest-pass-sell')), findsNothing);
  });

  testWidgets('one Save sells: the guest from the identity form, the pass from its section', (tester) async {
    final passes = _Passes();
    await _pump(tester, passes, {WorkspacePermission.issueInvoices});
    await tester.tap(find.byKey(const ValueKey('guest-pass-sell')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('personal-info-first-name')), 'Gina');
    await tester.enterText(find.byKey(const ValueKey('personal-info-last-name')), 'Guest');
    await tester.tap(find.byKey(const ValueKey('guest-pass-seat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ground · A1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guest-pass-days-more')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 ×'), findsOneWidget, reason: 'the total says what will be charged');

    await tester.ensureVisible(find.byKey(const ValueKey('personal-info-save')));
    await tester.tap(find.byKey(const ValueKey('personal-info-save')));
    await tester.pumpAndSettle();

    final sale = passes.sold.single;
    expect(sale.guest['first_name'], 'Gina');
    expect(sale.guest['last_name'], 'Guest');
    expect(sale.draft.seatId, 'seat-1');
    expect(sale.draft.days, 2);
    expect(sale.draft.offer?.id, 'day');
    expect(sale.requestId, isNotEmpty);
    expect(find.textContaining('Pass sold'), findsOneWidget);
  });

  testWidgets('without a place the pass is not sent', (tester) async {
    final passes = _Passes();
    await _pump(tester, passes, {WorkspacePermission.issueInvoices});
    await tester.tap(find.byKey(const ValueKey('guest-pass-sell')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('personal-info-first-name')), 'Gina');
    await tester.enterText(find.byKey(const ValueKey('personal-info-last-name')), 'Guest');
    expect(find.text('Choose a place.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('personal-info-save')));
    await tester.tap(find.byKey(const ValueKey('personal-info-save')));
    await tester.pumpAndSettle();
    expect(passes.sold, isEmpty);
  });

  // #3829 — whoever sells revokes a selection, one pass after another, with
  // one outcome per pass; a refused pass stays and says why.
  GuestPassRecord sold(String id, String guest) => GuestPassRecord(
        id: id,
        memberId: guest,
        offerId: 'day',
        unit: GuestPassUnit.day,
        units: 3,
        amountCents: 7200,
        startsAt: DateTime.utc(2030, 1, 7, 8),
        endsAt: DateTime.utc(2030, 1, 9, 16),
      );

  testWidgets('a selection is revoked pass by pass, each with its outcome', (tester) async {
    final passes = _Passes(records: [sold('p1', 'g1'), sold('p2', 'g2')], refused: {'p2'});
    await _pump(tester, passes, {WorkspacePermission.issueInvoices});
    expect(find.byKey(const ValueKey('guest-pass-revoked-p1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('records-select-shown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-bulk-revoke')));
    await tester.pumpAndSettle();
    expect(find.text('Revoke these 2 passes?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guest-pass-revoke-confirm')));
    await tester.pumpAndSettle();

    expect([for (final r in passes.revoked) r.passId], ['p1', 'p2']);
    expect(passes.revoked.first.requestId, isNot(passes.revoked.last.requestId),
        reason: 'each pass has its own request id');
    final result = find.byKey(const ValueKey('guest-pass-revoke-result'));
    expect(result, findsOneWidget);
    expect(find.descendant(of: result, matching: find.text('1 pass revoked')), findsOneWidget);
    expect(find.descendant(of: result, matching: find.text('2 bookings cancelled')), findsOneWidget);
    expect(find.descendant(of: result, matching: find.text('Not revoked')), findsOneWidget);
    expect(find.descendant(of: result, matching: find.text('Hal Host')), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guest-pass-revoked-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-pass-revoked-p2')), findsNothing);
  });

  testWidgets('who may not sell may not revoke: the table offers no selection', (tester) async {
    await _pump(tester, _Passes(records: [sold('p1', 'g1')]), {WorkspacePermission.viewFinances});
    expect(find.text('Gale Guest'), findsOneWidget);
    expect(find.byKey(const ValueKey('records-select-shown')), findsNothing);
  });
}
