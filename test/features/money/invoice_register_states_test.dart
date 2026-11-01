// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — the invoice register's states: loading is not empty; a failed or
// refused read is never drawn as an empty register and Try again repeats the
// same read; a refresh keeps the rows on screen; the period chip survives an
// empty answer.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/screens/invoice_register_screen.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/read_probe.dart';

final _en = AppLocalizationsEn();
const _failure = ValueKey('read-failure');
const _retry = ValueKey('inline-banner-action');
const _refreshing = ValueKey('read-refreshing');

Future<List<Invoice>> _invoices() async {
  final money = FakeMoneyRepository();
  for (final period in ['2026-05', '2026-06']) {
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: period,
    );
  }
  for (var i = 0; i < money.invoices.length; i++) {
    money.invoices[i] = money.invoices[i].copyWith(
      issuedAt: DateTime(2026, 5 + i, 3),
    );
  }
  return money.invoices;
}

Finder _row(Invoice i) => find.byKey(ValueKey('invoice-register-${i.id}'));

Future<ReadProbe<List<Invoice>>> _pump(
  WidgetTester tester, {
  String? from,
  String? to,
}) async {
  final probe = ReadProbe<List<Invoice>>();
  await pumpStateScreen(
    tester,
    InvoiceRegisterScreen(from: from, to: to),
    overrides: [
      ...standardTestOverrides(workspace: FakeWorkspaceRepository.withWorkspace()),
      invoicesProvider.overrideWith((ref) => probe()),
    ],
  );
  await tester.pump();
  return probe;
}

void main() {
  testWidgets('loading is not empty: a spinner, then the rows', (tester) async {
    final all = await _invoices();
    final probe = await _pump(tester);
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(_en.invoicesEmpty), findsNothing);

    probe.answer(all);
    await tester.pump();
    expect(find.byType(LoadingView), findsNothing);
    expect(_row(all.first), findsOneWidget);
  });

  testWidgets('a successful empty answer says so', (tester) async {
    final probe = await _pump(tester);
    probe.answer(const []);
    await tester.pump();
    expect(find.text(_en.invoicesEmpty), findsOneWidget);
    expect(find.byKey(_failure), findsNothing);
  });

  testWidgets('a connectivity failure is not empty; Try again asks again', (
    tester,
  ) async {
    final all = await _invoices();
    final probe = await _pump(tester);
    probe.fail(const SocketException('no route'));
    await tester.pump();
    expect(find.text(_en.readStateOffline), findsOneWidget);
    expect(find.text(_en.invoicesEmpty), findsNothing);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(probe.calls, 1);

    await tester.tap(find.byKey(_retry));
    await tester.pump();
    expect(probe.calls, 2, reason: 'the same read, once more');
    expect(find.byType(LoadingView), findsOneWidget);
    probe.answer(all);
    await tester.pump();
    expect(find.byKey(_failure), findsNothing);
    expect(_row(all.first), findsOneWidget);
  });

  testWidgets('a refused read says access is missing, never an empty register', (
    tester,
  ) async {
    final probe = await _pump(tester);
    probe.fail(const PostgrestException(message: 'denied', code: '42501'));
    await tester.pump();
    expect(find.text(_en.readStateDenied), findsOneWidget);
    expect(find.text(_en.invoicesEmpty), findsNothing);
    expect(find.textContaining('denied'), findsNothing);
  });

  testWidgets('a refresh keeps the rows with a thin progress line; a failed '
      'refresh keeps them under the failure', (tester) async {
    final all = await _invoices();
    final probe = await _pump(tester);
    probe.answer(all);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(InvoiceRegisterScreen)),
    );
    container.invalidate(invoicesProvider);
    await tester.pump();
    expect(probe.calls, 2);
    expect(_row(all.first), findsOneWidget, reason: 'content stays');
    expect(find.byKey(_refreshing), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);

    probe.fail(const SocketException('gone'));
    await tester.pump();
    expect(_row(all.first), findsOneWidget, reason: 'old rows survive');
    expect(find.byKey(_refreshing), findsNothing);
    expect(find.text(_en.readStateOffline), findsOneWidget);
  });

  testWidgets('loading, failure, Try again, an empty period with its chip, '
      'then every invoice (state transition)', (tester) async {
    final all = await _invoices();
    final probe = await _pump(tester, from: '2025-01', to: '2025-01');
    expect(find.byType(LoadingView), findsOneWidget);

    probe.fail(StateError('boom'));
    await tester.pump();
    expect(find.text(_en.workspaceGenericError), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-register-period')), findsOneWidget);

    await tester.tap(find.byKey(_retry));
    await tester.pump();
    probe.answer(all);
    await tester.pump();
    expect(find.text(_en.invoicesEmpty), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-register-period')), findsOneWidget);
    expect(probe.calls, 2);

    await tester.tap(
      find.byKey(const ValueKey('invoice-register-period-clear')),
    );
    await tester.pump();
    for (final i in all) {
      expect(_row(i), findsOneWidget);
    }
  });
}
