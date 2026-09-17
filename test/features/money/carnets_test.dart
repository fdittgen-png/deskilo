// SPDX-License-Identifier: 0BSD
//
// #1279 S4 — the carnet surfaces: Billing keeps the catalogue, a member's
// page shows what is left and lets whoever issues invoices sell another.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/credit_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_credit_repository.dart';
import '../../helpers/mock_providers.dart';

Future<void> _pumpBilling(WidgetTester tester, FakeCreditRepository credits,
    {required bool carnetsOn}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(
      credits: credits,
      workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {'carnets': carnetsOn}),
    ),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/billing'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Billing offers no carnets while the feature is off',
      (tester) async {
    await _pumpBilling(tester, FakeCreditRepository(), carnetsOn: false);
    expect(find.byKey(const ValueKey('carnets-editor')), findsNothing);
  });

  testWidgets('an owner adds a carnet and switches it off', (tester) async {
    final credits = FakeCreditRepository();
    await _pumpBilling(tester, credits, carnetsOn: true);

    final editor = find.byKey(const ValueKey('carnets-editor'));
    await tester.ensureVisible(editor);
    await tester.enterText(find.byKey(const ValueKey('carnet-name')), 'Carnet 10');
    await tester.enterText(find.byKey(const ValueKey('carnet-half-days')), '10');
    await tester.enterText(find.byKey(const ValueKey('carnet-price')), '50');
    await tester.ensureVisible(find.byKey(const ValueKey('carnet-add')));
    await tester.tap(find.byKey(const ValueKey('carnet-add')));
    await tester.pumpAndSettle();

    expect(credits.products.single.name, 'Carnet 10');
    expect(credits.products.single.halfDays, 10);
    expect(credits.products.single.priceCents, 5000);
    expect(credits.products.single.validityMonths, isNull,
        reason: 'an empty validity is a carnet that never expires');

    final row = find.byKey(ValueKey('carnet-${credits.products.single.id}'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(credits.products.single.active, isFalse);
  });

  Future<void> pumpMemberPage(WidgetTester tester, FakeCreditRepository credits,
      {bool admin = true}) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workspace =
        FakeWorkspaceRepository.withWorkspace(featureFlags: {'carnets': true});
    if (!admin) {
      workspace.myMember =
          workspace.myMember.copyWith(isAdmin: false, isOwner: false);
    }
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(credits: credits, workspace: workspace),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/member/${workspace.myMember.id}'));
    await tester.pumpAndSettle();
  }

  testWidgets('a member page shows what is left and sells another',
      (tester) async {
    final credits = FakeCreditRepository()
      ..products.add(const CreditProduct(
          id: 'c10', name: 'Carnet 10', halfDays: 10, priceCents: 5000))
      ..balances['member-1'] = 3;
    await pumpMemberPage(tester, credits);
    final tile = find.byKey(const ValueKey('member-carnets'));
    await tester.ensureVisible(tile);
    expect(find.text('3 half-days left'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sell-carnet-c10')));
    await tester.pumpAndSettle();

    expect(credits.sales.single, (memberId: 'member-1', productId: 'c10'));
    expect(find.text('13 half-days left'), findsOneWidget);
  });

  testWidgets('a single half-day reads in the singular, and the tile is '
      'there to read, not to sell, for someone who does not invoice',
      (tester) async {
    final credits = FakeCreditRepository()..balances['member-1'] = 1;
    await pumpMemberPage(tester, credits, admin: false);
    final tile = find.byKey(const ValueKey('member-carnets'));
    await tester.ensureVisible(tile);
    expect(find.text('1 half-day left'), findsOneWidget);
    expect(tester.widget<ListTile>(tile).onTap, isNull);
  });
}
