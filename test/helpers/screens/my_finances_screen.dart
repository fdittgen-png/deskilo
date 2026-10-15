// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in my_finances_screen_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mock_providers.dart';

FinanceInvoice invoice(
  String id, {
  String ws = 'Office A',
  FinanceState state = FinanceState.open,
  DateTime? due,
  int total = 10000,
  int paid = 0,
  String currency = 'EUR',
  int reminders = 0,
}) => FinanceInvoice(
  id: id,
  workspaceId: 'ws-$ws',
  workspaceName: ws,
  number: 'INV-$id',
  issuedAt: DateTime.utc(2026, 9),
  dueOn: due,
  totalCents: total,
  paidCents: paid,
  currency: currency,
  state: state,
  reminderCount: reminders,
);

Future<void> show(
  WidgetTester tester,
  FinanceOverview overview, {
  String? workspaceId,
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeAccountActivityRepository()..financeOverview = overview;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        accountActivity: repo,
        workspace: workspace,
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyFinancesScreen(workspaceId: workspaceId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
