// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the payments list behind the collected figure: the window the
// figure drilled with, one bounded page at a time, and an honest
// loading / empty / failed / refused / switched-off state.
import 'dart:io';

import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/features/money/domain/recorded_payments.dart';
import 'package:deskilo/features/money/presentation/screens/recorded_payments_screen.dart';
import 'package:deskilo/features/money/providers/recorded_payments_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/read_probe.dart';

final _en = AppLocalizationsEn();

RecordedPayment _payment(String id, {int minor = 12500, String? number}) =>
    RecordedPayment(
      id: id,
      matchedAt: DateTime.utc(2026, 5, 20, 8),
      amountMinor: minor,
      currency: 'EUR',
      invoiceId: 'inv-$id',
      invoiceNumber: number ?? 'F-$id',
      payerName: 'Payer $id',
    );

class _Calls implements RecordedPaymentsRepository {
  final probes = <ReadProbe<RecordedPaymentsPage>>[];
  final windows = <({DateTime from, DateTime to, String? after})>[];

  @override
  Future<RecordedPaymentsPage> page(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    RecordedPaymentsCursor? after,
    int? limit,
  }) {
    windows.add((from: from, to: to, after: after?.id));
    final probe = ReadProbe<RecordedPaymentsPage>();
    probes.add(probe);
    return probe();
  }
}

Future<_Calls> _pump(WidgetTester tester, {String? from, String? to}) async {
  final calls = _Calls();
  await pumpStateScreen(
    tester,
    RecordedPaymentsScreen(from: from, to: to),
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(),
      ),
      recordedPaymentsRepositoryProvider.overrideWithValue(calls),
    ],
  );
  await tester.pump();
  await tester.pump();
  return calls;
}

RecordedPaymentsPage _page(List<RecordedPayment> items, {String? next}) =>
    RecordedPaymentsPage(
      items: items,
      pageSize: 2,
      nextCursor: next == null
          ? null
          : RecordedPaymentsCursor(
              matchedAt: '2026-05-20T08:00:00+00:00',
              id: next,
            ),
    );

void main() {
  testWidgets('the figure\'s window reaches the read; loading is not empty', (
    tester,
  ) async {
    final calls = await _pump(tester, from: '2026-04', to: '2026-05');
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(_en.recordedPaymentsEmpty), findsNothing);
    expect(calls.windows.single.from, DateTime(2026, 4));
    expect(calls.windows.single.to, DateTime(2026, 5, 31));
    expect(calls.windows.single.after, isNull);
  });

  testWidgets('a missing window reads the current month', (tester) async {
    final calls = await _pump(tester);
    final w = calls.windows.single;
    expect(w.from.day, 1);
    expect(DateTime(w.to.year, w.to.month, w.to.day + 1).day, 1);
    expect(w.from.month, w.to.month);
  });

  testWidgets('rows show invoice, payer and the exact amount; more asks the '
      'next page from the last row', (tester) async {
    final calls = await _pump(tester, from: '2026-05', to: '2026-05');
    calls.probes.single.answer(
      _page([_payment('a'), _payment('b')], next: 'b'),
    );
    await tester.pump();
    expect(find.text('F-a · Payer a'), findsOneWidget);
    expect(find.textContaining('125'), findsWidgets);
    expect(
      find.byKey(const ValueKey('recorded-payments-more')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('recorded-payments-more')));
    await tester.pump();
    expect(calls.windows.last.after, 'b');
    calls.probes.last.answer(_page([_payment('c')]));
    await tester.pump();
    expect(find.text('F-c · Payer c'), findsOneWidget);
    expect(
      find.text('F-a · Payer a'),
      findsOneWidget,
      reason: 'earlier rows stay',
    );
    expect(find.byKey(const ValueKey('recorded-payments-more')), findsNothing);
  });

  testWidgets('no payments says so', (tester) async {
    final calls = await _pump(tester, from: '2026-05', to: '2026-05');
    calls.probes.single.answer(_page(const []));
    await tester.pump();
    expect(find.text(_en.recordedPaymentsEmpty), findsOneWidget);
  });

  testWidgets('a failed read is not empty; Try again asks again', (
    tester,
  ) async {
    final calls = await _pump(tester, from: '2026-05', to: '2026-05');
    calls.probes.single.fail(const SocketException('offline'));
    await tester.pump();
    expect(find.text(_en.recordedPaymentsEmpty), findsNothing);
    expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
    await tester.tap(find.text(_en.commonRetry));
    await tester.pump();
    await tester.pump();
    expect(calls.probes.length, 2);
    calls.probes.last.answer(_page([_payment('a')]));
    await tester.pump();
    expect(find.text('F-a · Payer a'), findsOneWidget);
  });

  testWidgets('a refusal says no access, not empty', (tester) async {
    final calls = await _pump(tester, from: '2026-05', to: '2026-05');
    calls.probes.single.fail(const RecordedPaymentsForbidden());
    await tester.pump();
    expect(find.text(_en.readStateDenied), findsOneWidget);
    expect(find.text(_en.recordedPaymentsEmpty), findsNothing);
  });

  testWidgets('money switched off is named', (tester) async {
    final calls = await _pump(tester, from: '2026-05', to: '2026-05');
    calls.probes.single.fail(const RecordedPaymentsSwitchedOff());
    await tester.pump();
    expect(find.text(_en.recordedPaymentsOff), findsOneWidget);
  });
}
