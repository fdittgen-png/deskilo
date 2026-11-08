// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what the declarations screen offers for a prepared return,
// per country, pinned BEFORE the rule moves behind the VAT filing contract: the
// label of the file's button (DE ELSTER, FR EDI-TVA, GB MTD CSV, CH MWST XML,
// CA GST/QST CSV, ES AEAT 303, IT LIPE XML, nothing elsewhere) and what the
// file still asks of the person before it is written (DE the Steuernummer, ES
// its facts, IT the declarant, nobody else). The move must change none of it.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/presentation/vat_filing_file_actions.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

VatDeclaration _prepared() => VatDeclaration(
  id: 'd1',
  workspaceId: 'ws-1',
  periodStart: DateTime(2026, 9),
  periodEnd: DateTime(2026, 9, 30),
  status: 'prepared',
  lines: [
    const VatDeclarationLine(
      percent: 20,
      category: 'S',
      grossCents: 120000,
      netCents: 100000,
      vatCents: 20000,
      invoiceCount: 1,
    ),
  ],
  totalNetCents: 100000,
  totalVatCents: 20000,
  currency: 'EUR',
  invoiceCount: 1,
  createdAt: DateTime.utc(2026, 10, 2),
);

/// The countries that have a file.
const _withFile = ['DE', 'FR', 'GB', 'CH', 'CA', 'ES', 'IT'];

/// The dialog a country asks first: the keys of its OK button, or none.
const _asks = <String, String?>{
  'DE': 'vat-filing-tax-number-ok',
  'ES': 'vat-filing-es-ok',
  'IT': 'vat-filing-it-ok',
  'FR': null,
  'GB': null,
  'CH': null,
  'CA': null,
};

void main() {
  test('every country has the label it had before the move', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final expected = {
      'DE': l10n.vatDeclElster,
      'FR': l10n.vatDeclEdiTva,
      'GB': l10n.vatDeclMtdCsv,
      'CH': l10n.vatDeclMwstXml,
      'CA': l10n.vatDeclGstQstCsv,
      'ES': l10n.vatDeclAeat303,
      'IT': l10n.vatDeclLipeXml,
    };
    for (final c in _withFile) {
      expect(vatFilingFileLabel(l10n, c), expected[c], reason: c);
    }
    for (final c in ['AT', 'PL', 'IE', 'US', 'ZZ', '', null]) {
      expect(vatFilingFileLabel(l10n, c), isNull, reason: '$c');
    }
  });

  for (final entry in _asks.entries) {
    testWidgets('a ${entry.key} space is asked ${entry.value ?? 'nothing'} '
        'before its file is written', (tester) async {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      workspace.workspaces[0] = workspace.workspaces[0].copyWith(
        vatRegime: 'vat_registered',
        countryCode: entry.key,
        legalId: '21/815/08150',
      );
      final money = FakeMoneyRepository()..vatDeclarations.add(_prepared());
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(money: money, workspace: workspace),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(GoRouter.of(context).push('/vat-declarations'));
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('vat-decl-filing-d1'));
      expect(button, findsOneWidget, reason: '${entry.key} offers a file');
      await tester.tap(button);
      await tester.pumpAndSettle();
      for (final key in _asks.values.whereType<String>()) {
        expect(
          find.byKey(ValueKey(key)),
          key == entry.value ? findsOneWidget : findsNothing,
          reason: '${entry.key}: $key',
        );
      }
    });
  }

  testWidgets('a country with no file has no button', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      vatRegime: 'vat_registered',
      countryCode: 'AT',
    );
    final money = FakeMoneyRepository()..vatDeclarations.add(_prepared());
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money, workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/vat-declarations'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vat-decl-filing-d1')), findsNothing);
  });
}
