// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3470 — the owner's form for the business's accounting journals: a code
// used twice or a forbidden character is said under its field and nothing
// is kept; a whole value is kept; the standard codes are kept as none.
import 'package:deskilo/features/money/domain/accounting_journals.dart';
import 'package:deskilo/features/money/presentation/widgets/accounting_journals_sheet.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Future<FakeWorkspaceRepository> _open(WidgetTester tester) async {
  final workspaces = FakeWorkspaceRepository.withWorkspace();
  await pumpApp(
    tester,
    Consumer(
      builder: (context, ref, _) => FilledButton(
        key: const ValueKey('open'),
        onPressed: () => AccountingJournalsDoor.open(
          context,
          ref,
          workspaceId: workspaces.workspaces.first.id,
          current: accountingJournalsOf(const {}),
        ),
        child: const Text('open'),
      ),
    ),
    size: const Size(390, 1600),
    overrides: standardTestOverrides(workspace: workspaces),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return workspaces;
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('accounting-journals-save')),
  );
  await tester.tap(find.byKey(const ValueKey('accounting-journals-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a code used twice is said under its field and nothing is '
      'kept', (tester) async {
    final workspaces = await _open(tester);
    await _type(tester, 'accounting-journal-sales-code', 'BQ');
    await _save(tester);
    expect(find.text(_en.accountingJournalDuplicate), findsOneWidget);
    expect(workspaces.workspaces.first.accountingJournals, isEmpty);
  });

  testWidgets('a tab in a label is said under that label', (tester) async {
    final workspaces = await _open(tester);
    await _type(tester, 'accounting-journal-bank-label', 'Banque\tBNP');
    await _save(tester);
    expect(find.text(_en.accountingJournalCharacter), findsOneWidget);
    expect(workspaces.workspaces.first.accountingJournals, isEmpty);
  });

  testWidgets('a whole value is kept', (tester) async {
    final workspaces = await _open(tester);
    await _type(tester, 'accounting-journal-sales-code', 'VT');
    await _type(tester, 'accounting-journal-bank-code', 'BNP');
    await _save(tester);
    final kept = FecJournals.fromJson(
      workspaces.workspaces.first.accountingJournals,
    );
    expect(kept?.sales.code, 'VT');
    expect(kept?.bank.code, 'BNP');
    expect(kept?.misc, accountingJournalsOf(const {}).misc);
  });

  testWidgets('the standard codes are kept as none', (tester) async {
    final workspaces = await _open(tester);
    await _type(tester, 'accounting-journal-sales-code', 'VT');
    await tester.ensureVisible(
      find.byKey(const ValueKey('accounting-journals-standard')),
    );
    await tester.tap(
      find.byKey(const ValueKey('accounting-journals-standard')),
    );
    await tester.pump();
    await _save(tester);
    expect(workspaces.workspaces.first.accountingJournals, isEmpty);
  });
}
