// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2590 — a month of usage is read without being written, and recording it
// is the person's own action: an unprepared month reads as incomplete (never
// as "no usage"), the button records it once, and the list then reads whole.
import 'package:deskilo/features/money/application/usage_commands.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';
import 'package:deskilo/features/money/presentation/widgets/usage_face.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

class _Preparation implements UsagePreparation {
  final List<String> calls = <String>[];
  late void Function() onPrepared;

  @override
  Future<int> prepare(
    String workspaceId,
    String period,
    String requestId,
  ) async {
    calls.add('$period/$requestId');
    onPrepared();
    return 2;
  }
}

class _Money extends FakeMoneyRepository {
  int unprepared = 2;
  int readCalls = 0;

  @override
  Future<UsageRead> readUsageRecords({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async {
    readCalls++;
    return UsageRead(records: const [], unpreparedReservations: unprepared);
  }
}

void main() {
  test('a coverage of zero is complete, anything else is not', () {
    expect(const UsageRead(records: []).complete, isTrue);
    expect(
      const UsageRead(records: [], unpreparedReservations: 1).complete,
      isFalse,
    );
    final read = UsageRead.fromRpc(<String, Object?>{
      'records': const <Object?>[],
      'coverage': {'unprepared_reservations': 3, 'complete': false},
    });
    expect(read.unpreparedReservations, 3);
  });

  test('only a month is sent to be recorded', () async {
    final preparation = _Preparation()..onPrepared = () {};
    final commands = UsageCommands(preparation);
    expect(await commands.prepare('ws', '2026-13', 'r1'), isNull);
    expect(await commands.prepare('ws', 'last month', 'r2'), isNull);
    expect(preparation.calls, isEmpty);
    expect(await commands.prepare('ws', '2026-09', 'r3'), 2);
    expect(preparation.calls, ['2026-09/r3']);
  });

  testWidgets(
    'an unprepared month says it is incomplete; the button records it',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final reads = _Money();
      final preparation = _Preparation()
        ..onPrepared = () => reads.unprepared = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(
            money: reads,
            usagePreparation: preparation,
          ),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: UsageFace(period: '2026-09')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('usage-prepare-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('usage-empty')),
        findsNothing,
        reason: 'a month nobody recorded is not "no usage"',
      );
      expect(reads.readCalls, 1, reason: 'reading it recorded nothing');
      expect(preparation.calls, isEmpty);

      await tester.tap(find.byKey(const ValueKey('usage-prepare')));
      await tester.pumpAndSettle();
      expect(preparation.calls, hasLength(1));
      expect(preparation.calls.single, startsWith('2026-09/'));
      expect(find.byKey(const ValueKey('usage-prepare-banner')), findsNothing);
      expect(
        find.byKey(const ValueKey('usage-empty')),
        findsOneWidget,
        reason: 'prepared and still empty: now it really is no usage',
      );
    },
  );
}
