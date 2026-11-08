// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3432 -- an accounting export that states the workspace's own tax reference
// (codes, rates, clocks) does not run on a guess: with the workspace context
// not ready the tap is answered with a snack, opens no dialog and saves
// nothing. One case per writer family that needs it (the Sage 50 one is in
// sage_export_flow_test).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/workspace/providers/operation_context_providers.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

/// The export log: the format of each file logged.
class _Log implements BookPeriodRepository {
  final formats = <String>[];

  @override
  Future<String?> recordExport(String workspaceId, BookExportRecord record) async {
    formats.add(record.formatId);
    return 'log-${formats.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('the export called ${invocation.memberName}');
}



Future<List<String>> _tapFormat(
  WidgetTester tester, {
  required String country,
  required String formatId,
}) async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-06',
  );
  money.invoices[0] = money.invoices[0].copyWith(issuedAt: DateTime(2026, 7));
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    countryCode: country,
    currencyCode: 'EUR',
  );
  final saved = <String>[];
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: money, workspace: workspace),
        bookPeriodRepositoryProvider.overrideWithValue(_Log()),
        readyWorkspaceContextProvider.overrideWith((ref) => null),
        typedFileSaverProvider.overrideWithValue(
          ({required bytes, required fileName}) async {
            saved.add(fileName);
            return SavedFile('Download/$fileName');
          },
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('My finances'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
  await tester.pumpAndSettle();
  await openMoneyWorkspaceTools(tester);
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  await tapInvoicingTool(tester, 'invoice-register-button');
  await tester.tap(find.byKey(const ValueKey('invoice-accounting-export')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('accounting-export-$formatId')));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  const cases = [
    ('CH', 'ch_kmu'),
    ('CH', 'banana_transactions'),
    ('DE', 'gobd'),
    ('PT', 'saft_pt'),
    ('FR', 'bundle'),
  ];
  for (final (country, formatId) in cases) {
    testWidgets('$formatId ($country): the workspace context not ready is '
        'answered, not swallowed (#3432)', (tester) async {
      final saved = await _tapFormat(
        tester,
        country: country,
        formatId: formatId,
      );
      expect(saved, isEmpty);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(
        (snack.content as Text).data,
        startsWith('The workspace is still loading its tax settings'),
      );
    });
  }
}
