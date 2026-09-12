// SPDX-License-Identifier: 0BSD
//
// #1061 slice two — the statement builder's golden, written by the
// PRE-seam `statementReportData(context, …)` from this fixture. See
// report_data_golden_test.dart for the rule.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deskilo/features/money/domain/report_data_letters.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');

const _statement = Statement(
  period: '2026-07',
  subscriptionPct: 50,
  feeCents: 15000,
  includedHalfDays: 10,
  openDays: 22,
  usedHalfDays: 13,
  extraHalfDays: 3,
  overageCents: 4500,
  accessorySupplementCents: 1200,
  levelSupplementCents: 800,
  officeSupplementCents: 900,
  deskSupplementCents: 300,
  creditsCents: -10000,
  balanceCents: 12700,
);

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Test Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'CODE123456',
  invoiceLegal: {'is_association': false},
);

void main() {
  for (final locale in const [Locale('en'), Locale('fr')]) {
    final name = 'statement_report_data_${locale.languageCode}';
    testWidgets('$name is byte-identical to the pre-seam golden',
        (tester) async {
      late Map<String, Object?> data;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          data = statementReportData(
            reportStringsFor(context),
            statement: _statement,
            workspaceName: 'Test Space',
            memberName: 'Ana Martin',
            periodLabel: 'July 2026',
            currencyCode: 'EUR',
            workspace: _workspace,
          );
          return const SizedBox();
        }),
      ));
      final encoded = const JsonEncoder.withIndent('  ').convert(data);
      final file = File('test/features/money/goldens/$name.json');
      if (_write) {
        file.writeAsStringSync('$encoded\n');
        return;
      }
      expect(encoded, file.readAsStringSync().trimRight());
    });
  }
}
