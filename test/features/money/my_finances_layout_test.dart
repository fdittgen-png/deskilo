// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C4 — Me › Finances: rows on a wide window and compact cards on a
// phone, each with Open and Export; the period and type filters the
// documents' own facts support; the coverage above the results, naming
// each host that answered with each of its workspaces, and a host that did
// not; and the CSV saying inside the file that a host was unavailable.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/domain/finance_filter.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/own_finance_csv.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/features/money/providers/account_activity_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;

const _remote = 'https://two.example';

List<String> _lines(Uint8List bytes) =>
    utf8.decode(bytes).split('\r\n')..removeLast();

class _Saver {
  final files = <String, Uint8List>{};

  Future<SaveOutcome> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    files[fileName] = bytes;
    return const SavedFile('Download/doc.csv');
  }
}

FinanceInvoice _dated(String id, DateTime issuedAt, {int total = 10000}) =>
    FinanceInvoice(
      id: id,
      workspaceId: 'ws-Office A',
      workspaceName: 'Office A',
      number: 'INV-$id',
      issuedAt: issuedAt,
      totalCents: total,
      paidCents: 0,
      currency: 'EUR',
      state: FinanceState.paid,
    );

/// The screen over a home host with [home]'s documents, and a connected
/// host with [remote]'s documents that is selected when [selectRemote].
Future<({FakeAccountActivityRepository remote, _Saver saver})> _pump(
  WidgetTester tester, {
  required Size size,
  required FinanceOverview home,
  FinanceOverview remote = const FinanceOverview(),
  bool remoteDown = false,
  bool selectRemote = false,
}) async {
  final saver = _Saver();
  final remoteRepo = FakeAccountActivityRepository()
    ..unavailable = remoteDown
    ..financeOverview = remote;
  await pumpApp(
    tester,
    const MyFinancesScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        accountActivity: FakeAccountActivityRepository()
          ..financeOverview = home,
      ),
      selectedWorkspaceAccountActivityRepositoryProvider.overrideWithValue(
        remoteRepo,
      ),
      fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
      typedFileSaverProvider.overrideWithValue(saver.save),
    ],
  );
  await tester.pump();
  if (selectRemote) {
    ProviderScope.containerOf(tester.element(find.byType(MyFinancesScreen)))
        .read(selectedWorkspaceHostProvider.notifier)
        .select('ws-Remote Two', _remote);
  }
  await tester.pumpAndSettle();
  return (remote: remoteRepo, saver: saver);
}

void main() {
  group('the filters', () {
    test('period and type keep only what the documents\' own facts say', () {
      final overview = FinanceOverview(
        invoices: [
          _dated('a', DateTime(2025, 6, 2)),
          _dated('b', DateTime(2026, 6, 2)),
          _dated('c', DateTime(2026, 7, 2), total: -500),
        ],
      );
      expect(financeYears(overview), [2026, 2025]);
      expect(
        const FinanceFilter(year: 2025)
            .apply(overview)
            .invoices
            .map((i) => i.id),
        ['a'],
      );
      expect(
        const FinanceFilter(type: FinanceDocType.creditNote)
            .apply(overview)
            .invoices
            .map((i) => i.id),
        ['c'],
      );
      expect(
        const FinanceFilter(
          year: 2026,
          type: FinanceDocType.invoice,
        ).apply(overview).invoices.map((i) => i.id),
        ['b'],
      );
    });

    test('newest first; the qualified id breaks a tie between hosts', () {
      final day = DateTime.utc(2026, 9);
      final sorted = newestFirst([
        _dated('1', day),
        FinanceInvoice(
          id: '1',
          workspaceId: 'ws-0',
          workspaceName: 'Zero',
          number: 'Z-1',
          issuedAt: day,
          totalCents: 1,
          paidCents: 0,
          currency: 'EUR',
          state: FinanceState.paid,
        ),
        _dated('2', DateTime.utc(2026, 10)),
      ]);
      expect(sorted.map((i) => '${i.workspaceId}:${i.id}'), [
        'ws-Office A:2',
        'ws-0:1',
        'ws-Office A:1',
      ]);
    });
  });

  group('the CSV says when a host was unavailable', () {
    test('a note row per host that did not answer, through csvCell', () {
      final rows = _lines(
        ownFinanceCsv(
          FinanceOverview(invoices: [invoice('1')]).withUnavailable(_remote),
        ),
      );
      expect(rows, hasLength(3));
      expect(rows[1], startsWith('"INV-1"'));
      expect(rows[2], '"# unavailable_source","two.example",,,,,,,,,');
    });

    test('every host answered: no note row', () {
      final rows = _lines(
        ownFinanceCsv(
          FinanceOverview(invoices: [invoice('1')]).answeredBy(null),
        ),
      );
      expect(rows, hasLength(2));
      expect(rows.any((r) => r.contains('# unavailable_source')), isFalse);
    });
  });

  testWidgets('a wide window reads rows with a header, Open and Export; '
      'Export writes that one document', (tester) async {
    final hosts = await _pump(
      tester,
      size: const Size(1440, 1000),
      home: FinanceOverview(
        invoices: [
          invoice('1'),
          invoice('2', ws: 'Office B'),
        ],
      ),
    );
    expect(find.byKey(const ValueKey('finances-rows-header')), findsOneWidget);
    expect(find.text('Issued by'), findsOneWidget);
    // Document state and payment state are two facts, side by side.
    final row = find.byKey(const ValueKey('finances-invoice-1'));
    expect(
      find.descendant(of: row, matching: find.text('Invoice')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Unpaid')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('finances-open-1')),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('finances-export-2')));
    await tester.pumpAndSettle();
    final file = hosts.saver.files.entries.single;
    expect(file.key, startsWith('deskilo-my-documents-office-b-inv-2-'));
    final rows = _lines(file.value);
    expect(rows, hasLength(2));
    expect(rows[1], startsWith('"INV-2","Office B"'));
  });

  testWidgets('a phone reads compact cards: no header, Open and Export on '
      'each card', (tester) async {
    await _pump(
      tester,
      size: const Size(390, 844),
      home: FinanceOverview(invoices: [invoice('1')]),
    );
    expect(find.byKey(const ValueKey('finances-rows-header')), findsNothing);
    final card = find.byKey(const ValueKey('finances-invoice-1'));
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('finances-export-1')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the type filter narrows the list to credit notes and back', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(800, 1400),
      home: FinanceOverview(
        invoices: [
          invoice('1'),
          invoice('cn', total: -2000, state: FinanceState.refunded),
        ],
      ),
    );
    // The credit note is settled: it is on the Paid face.
    await tester.tap(find.byKey(const ValueKey('finances-tab-paid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-invoice-cn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finances-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-type-invoice')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-invoice-cn')), findsNothing);
    expect(find.byKey(const ValueKey('finances-paid-empty')), findsOneWidget);
  });

  testWidgets('coverage names each host that answered with each of its '
      'workspaces; a host down is named on its own and recovers', (
    tester,
  ) async {
    final hosts = await _pump(
      tester,
      size: const Size(800, 1400),
      home: FinanceOverview(invoices: [invoice('1'), invoice('2')]),
      remote: FinanceOverview(invoices: [invoice('w1', ws: 'Remote Two')]),
      remoteDown: true,
      selectRemote: true,
    );
    final home = find.byKey(const ValueKey('finances-coverage-home'));
    expect(home, findsOneWidget);
    expect(
      find.descendant(
        of: home,
        matching: find.textContaining('Office A: 2 documents'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('finances-coverage-two.example')),
      findsNothing,
      reason: 'a host that did not answer is never listed as read',
    );
    expect(
      find.byKey(const ValueKey('finances-source-unavailable-two.example')),
      findsOneWidget,
    );

    hosts.remote.unavailable = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('finances-source-unavailable-two.example')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('finances-coverage-two.example')),
        matching: find.textContaining('Remote Two: 1 document'),
      ),
      findsOneWidget,
    );
  });
}
