// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #934 — the treasurer's view reads the database's status and prints it.
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';
import 'package:deskilo/features/money/presentation/screens/workspace_status_screen.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('the totals, the net and the members come from the status',
      (tester) async {
    final money = FakeMoneyRepository()
      ..status = const WorkspaceStatus(
        from: '2026-07', to: '2026-09', currency: 'EUR',
        invoicedCents: 185000, creditNotesCents: 12000,
        paymentsMatchedCents: 160000, paymentsReceivedCents: 160000,
        reimbursedCents: 8640,
        members: [
          StatusMemberRow(memberId: 'm1', name: 'Ma Petite Entreprise', memberNumber: 'M-0001', subscriptionPct: 50, invoicedCents: 30000, paidCents: 30000),
        ],
      );
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: FakeWorkspaceRepository.withWorkspace()),
      child: const MaterialApp(home: WorkspaceStatusScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-invoiced')), findsOneWidget);
    expect(find.textContaining('1,850'), findsWidgets);
    // net = 185000 − 12000 − 8640 − 0 = 164360
    expect(find.textContaining('1,643.60'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-member-m1')), findsOneWidget);
    expect(find.text('Ma Petite Entreprise'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-print')), findsOneWidget);
  });

  testWidgets('#3742 — the first print of a session reads the template it '
      'never read, then prints: no exception, no message', (tester) async {
    var reads = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: FakeMoneyRepository(),
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        enabledFeaturesSyncProvider.overrideWithValue({
          WorkspaceFeature.invoicePdfTemplate,
        }),
        invoicePdfTemplateProvider.overrideWith((ref) async {
          reads++;
          return InvoicePdfTemplate.empty;
        }),
      ],
      child: const MaterialApp(home: WorkspaceStatusScreen()),
    ));
    await tester.pumpAndSettle();
    expect(reads, 0, reason: 'the screen itself never reads the template');
    await tester.tap(find.byKey(const ValueKey('status-print')));
    await tester.pumpAndSettle();
    expect(reads, 1, reason: 'the print read it before drawing');
    expect(find.byKey(const ValueKey('print-read-retry')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
