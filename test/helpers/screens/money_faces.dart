// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the money faces pump, moved out of `test/features/money/money_faces_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/bill_sections.dart';
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_money_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

Future<FakeMoneyRepository> pumpFaces(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  Map<String, dynamic> flags = const {},
  bool admin = true,
  // #1339 — the responsive matrix asks for a narrow surface. Every
  // other caller keeps the tall one this file has always used, so
  // nothing existing changes.
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  money ??= FakeMoneyRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  if (!admin) {
    workspace.myMember =
        workspace.myMember.copyWith(isAdmin: false, isOwner: false);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  // #1246 — by icon, not by the English label (see navigation.dart).
  await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
  await tester.pumpAndSettle();
  return money;
}

Future<void> face(WidgetTester tester, MoneyFace face) async {
  await tester.ensureVisible(find.byKey(ValueKey('money-face-${face.name}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('money-face-${face.name}')));
  await tester.pumpAndSettle();
}

/// An OPEN invoice for me, issued [ageDays] ago.
Future<String> openInvoice(FakeMoneyRepository money, {int ageDays = 0}) async {
  final id = await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: currentPeriod(kTestNow),
  );
  final i = money.invoices.indexWhere((x) => x.id == id);
  money.invoices[i] = money.invoices[i].copyWith(
    issuedAt: kTestNow.subtract(Duration(days: ageDays)),
  );
  return id;
}
