// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the guest passes screen: the space's passes and who sees what,
// and a sale through THE identity form with the pass in its extra
// section: one Save sends the guest's identity, the place and the window.
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/presentation/screens/guest_passes_screen.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

class _Passes implements GuestPassRepository {
  final sold = <({GuestPassDraft draft, Map<String, dynamic> guest, String requestId})>[];

  @override
  Future<List<GuestPassOffer>> offers(String workspaceId) async => const [
        GuestPassOffer(id: 'day', name: 'Day pass', unit: GuestPassUnit.day, priceCents: 2400),
      ];

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
        guestPassPlacesProvider.overrideWith((ref) async => const [(seatId: 'seat-1', label: 'Ground · A1')]),
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
}
