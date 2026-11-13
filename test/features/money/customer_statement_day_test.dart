// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3876 — the statements are printed for the BUSINESS's day (the one the
// customer page reads), never the device's: a device on the evening of the
// 13th, a business already on the 14th. And a period with no balance and no
// movement says so instead of printing nothing.
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/customer_statement.dart';
import 'package:deskilo/features/money/presentation/customer_statement_period_print.dart';
import 'package:deskilo/features/money/presentation/customer_statement_print.dart';
import 'package:deskilo/features/money/providers/customer_statement_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

final _l10n = AppLocalizationsEn();

/// The device's evening of the 13th; six hours later, the business's 14th.
final _device = DateTime(2026, 11, 13, 20);

DateTime _businessDay(DateTime instant) {
  final there = instant.add(const Duration(hours: 6));
  return DateTime(there.year, there.month, there.day);
}

class _Reader implements CustomerStatementReader {
  final asOfs = <DateTime>[];
  final periods = <(DateTime, DateTime)>[];

  @override
  Future<CustomerStatement> read(
    String workspaceId,
    String memberId,
    DateTime asOf,
  ) async {
    asOfs.add(asOf);
    return CustomerStatement(memberId: memberId, asOf: asOf);
  }

  @override
  Future<CustomerStatementPeriod> period(
    String workspaceId,
    String memberId,
    DateTime from,
    DateTime to,
  ) async {
    periods.add((from, to));
    return CustomerStatementPeriod(memberId: memberId, from: from, to: to);
  }
}

Future<void> _open(
  WidgetTester tester,
  _Reader reader,
  void Function(BuildContext, WidgetRef) onTap,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: FakeMoneyRepository(),
          clock: FixedClock(_device),
        ),
        customerStatementReaderProvider.overrideWithValue(reader),
        invoicingBusinessProvider.overrideWithValue((
          id: 'ws',
          currency: 'EUR',
          country: 'FR',
          dayOf: _businessDay,
        )),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('go'),
              onPressed: () => onTap(context, ref),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('go')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the open-items statement is read for the business day', (
    tester,
  ) async {
    final reader = _Reader();
    await _open(
      tester,
      reader,
      (context, ref) => CustomerStatementPrint(
        context,
        ref,
      ).show(workspaceId: 'ws', customerId: 'm'),
    );
    expect(reader.asOfs, [DateTime(2026, 11, 14)]);
  });

  testWidgets('the period picker ends on the business day', (tester) async {
    final reader = _Reader();
    await _open(
      tester,
      reader,
      (context, ref) => CustomerStatementPeriodPrint(
        context,
        ref,
      ).show(workspaceId: 'ws', customerId: 'm'),
    );
    // The default range is selected: confirm it.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(reader.periods.single.$2, DateTime(2026, 11, 14));
  });

  testWidgets('a period without balance or movement says so', (tester) async {
    final reader = _Reader();
    await _open(
      tester,
      reader,
      (context, ref) => CustomerStatementPeriodPrint(context, ref).printPeriod(
        workspaceId: 'ws',
        customerId: 'm',
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      ),
    );
    expect(find.text(_l10n.customerStatementPeriodNothing), findsOne);
    expect(
      find.byKey(const ValueKey('customer-statement-period-quick')),
      findsNothing,
    );
  });
}
