// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C7 — the full history reads every connected host my personal
// account names through that host's own reader, page after page; one host
// down is named with its own Try again while the others stay, and an
// answer for a previous account never lands. The CSV of one workspace
// carries every payment of it, read on its own source, unmasked, each row
// naming that source; a source that does not answer is noted in the file,
// and a file read for one account is never written under another.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/domain/finance_hosts.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/finance_sources.dart';
import 'package:deskilo/features/money/domain/own_finance_csv.dart';
import 'package:deskilo/features/money/presentation/screens/account_activity_screen.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/features/money/providers/finance_host_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;

/// One row of my history, [minutes] before a fixed instant.
AccountActivity _row(
  String id, {
  String ws = 'Lyon',
  int minutes = 0,
  int amount = 8000,
  String currency = 'CHF',
}) => AccountActivity(
  id: id,
  workspaceId: 'ws-$ws',
  workspaceName: ws,
  occurredAt: DateTime.utc(2026, 9, 28).subtract(Duration(minutes: minutes)),
  reference: 'R-$id',
  description: 'Card',
  currency: currency,
  status: 'confirmed',
  amountCents: amount,
);

/// The connected hosts: each answers its overview and its history pages
/// (keyset, [activityPageSize] at a time, as `my_financial_activity`),
/// fails, or holds a page open until the test completes it.
class _Reader implements FinanceHostReader {
  final overviews = <String, FinanceOverview>{};
  final rows = <String, List<AccountActivity>>{};
  final down = <String>{};
  final held = <String, Completer<List<AccountActivity>>>{};

  /// Every page asked: installation, kind and the cursor's id.
  final asked = <String>[];

  Completer<List<AccountActivity>> hold(String id) => held[id] = Completer();

  int askedOf(String id) => asked.where((a) => a.startsWith('$id:')).length;

  @override
  Future<FinanceOverview> overview(FinanceHost host) async =>
      overviews[host.installationId] ?? const FinanceOverview();

  @override
  Future<List<AccountActivity>> activity(
    FinanceHost host,
    AccountActivityKind kind, {
    ActivityCursor? before,
  }) async {
    final id = host.installationId;
    asked.add('$id:${kind.name}:${before?.id}');
    final wait = held.remove(id);
    if (wait != null) return wait.future;
    if (down.contains(id)) throw const FinanceHostUnavailable('down');
    final all = [...?rows[id]]
      ..sort((a, b) {
        final time = b.occurredAt.compareTo(a.occurredAt);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
    return all
        .where(
          (r) =>
              before == null ||
              r.occurredAt.isBefore(before.at) ||
              (r.occurredAt == before.at && r.id.compareTo(before.id) < 0),
        )
        .take(activityPageSize)
        .toList();
  }
}

const _here = FinanceHost(
  installationId: 'inst-home',
  workspaceIds: ['ws-Office A'],
  hostedHere: true,
  labels: ['Office A'],
);
const _lyon = FinanceHost(
  installationId: 'inst-b',
  workspaceIds: ['ws-Lyon'],
  labels: ['Lyon'],
);
const _nice = FinanceHost(
  installationId: 'inst-c',
  workspaceIds: ['ws-Nice'],
  labels: ['Nice'],
);

List<Override> _overrides(
  FakeAccountActivityRepository home,
  _Reader reader, {
  Stream<String?>? session,
}) => [
  ...standardTestOverrides(
    auth: FakeAuthRepository.signedIn(),
    accountActivity: home,
  ),
  financeHostsProvider.overrideWith((ref) async => const [_here, _lyon, _nice]),
  financeHostReaderProvider.overrideWithValue(reader),
  financeReadLimitsProvider.overrideWith(
    (ref) async => const FinanceReadLimits(
      concurrency: 2,
      timeout: Duration(seconds: 5),
    ),
  ),
  if (session != null) sessionStateProvider.overrideWith((ref) => session),
];

Finder _key(String key) => find.byKey(ValueKey(key));

/// A few frames: a held read shows a spinner, which never settles.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pump();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

List<String> _lines(Uint8List bytes) =>
    utf8.decode(bytes).split('\r\n')..removeLast();

class _Saver {
  final files = <String, Uint8List>{};
  int calls = 0;

  Future<SaveOutcome> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls++;
    files[fileName] = bytes;
    return const SavedFile('Download/my-documents.csv');
  }
}

void main() {
  group('the full history, host by host', () {
    Future<void> pumpHistory(
      WidgetTester tester,
      FakeAccountActivityRepository home,
      _Reader reader, {
      Stream<String?>? session,
    }) async {
      await pumpApp(
        tester,
        const AccountActivityScreen(),
        size: const Size(1200, 6000),
        overrides: _overrides(home, reader, session: session),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('every connected host my account names is read through its '
        'own reader and pages on by its own cursor; the home\'s own '
        'installation is the home\'s list', (tester) async {
      final home = FakeAccountActivityRepository()
        ..records[AccountActivityKind.invoices] = [
          _row('home-1', ws: 'Office A'),
        ];
      final reader = _Reader()
        ..rows['inst-b'] = [
          for (var i = 0; i < activityPageSize + 1; i++)
            _row('b$i', minutes: i),
        ]
        ..rows['inst-c'] = [_row('c1', ws: 'Nice')];
      await pumpHistory(tester, home, reader);

      expect(_key('account-activity-home-1'), findsOneWidget);
      expect(_key('host-activity-ws-Lyon-b0'), findsOneWidget);
      expect(_key('host-activity-ws-Nice-c1'), findsOneWidget);
      expect(_key('host-activity-ws-Lyon-b50'), findsNothing);
      expect(reader.askedOf('inst-home'), 0);
      expect(reader.asked, containsAll(['inst-b:invoices:null']));

      await _tap(tester, 'host-activity-next-inst-b');
      expect(reader.asked.last, 'inst-b:invoices:b49');
      expect(_key('host-activity-ws-Lyon-b50'), findsOneWidget);
      expect(_key('host-activity-ws-Lyon-b0'), findsNothing);
      // Nice's page is its own: it was not asked again.
      expect(reader.askedOf('inst-c'), 1);
      expect(_key('host-activity-next-inst-c'), findsOneWidget);
    });

    testWidgets('a host that does not answer is named with its own Try '
        'again while the others stay; Try again re-reads that host only', (
      tester,
    ) async {
      final reader = _Reader()
        ..rows['inst-b'] = [_row('b1')]
        ..rows['inst-c'] = [_row('c1', ws: 'Nice')]
        ..down.add('inst-c');
      await pumpHistory(tester, FakeAccountActivityRepository(), reader);

      expect(_key('host-activity-ws-Lyon-b1'), findsOneWidget);
      expect(_key('host-activity-retry-inst-c'), findsOneWidget);
      expect(_key('host-activity-ws-Nice-c1'), findsNothing);

      reader.down.remove('inst-c');
      await _tap(tester, 'host-activity-retry-inst-c');
      expect(_key('host-activity-retry-inst-c'), findsNothing);
      expect(_key('host-activity-ws-Nice-c1'), findsOneWidget);
      expect(_key('host-activity-ws-Lyon-b1'), findsOneWidget);
      expect(reader.askedOf('inst-b'), 1);
    });

    testWidgets('CACHE-01: a page that arrives after the account changed '
        'never lands', (tester) async {
      final session = StreamController<String?>.broadcast();
      addTearDown(session.close);
      final reader = _Reader();
      await pumpHistory(
        tester,
        FakeAccountActivityRepository(),
        reader,
        session: session.stream,
      );
      final stale = reader.hold('inst-b');
      session.add('person-1');
      await _frames(tester);
      final fresh = reader.hold('inst-b');
      session.add('person-2');
      await _frames(tester);
      stale.complete([_row('old')]);
      await _frames(tester);
      expect(_key('host-activity-ws-Lyon-old'), findsNothing);

      fresh.complete([_row('new')]);
      await _frames(tester);
      expect(_key('host-activity-ws-Lyon-new'), findsOneWidget);
      expect(_key('host-activity-ws-Lyon-old'), findsNothing);
    });
  });

  group('every page', () {
    test('is read until a short page, by the last row\'s cursor', () async {
      final cursors = <String?>[];
      final all = await everyActivityPage((before) async {
        cursors.add(before?.id);
        return before == null
            ? [
                for (var i = 0; i < activityPageSize; i++)
                  _row('p$i', minutes: i),
              ]
            : [_row('last', minutes: 99)];
      });
      expect(all, hasLength(activityPageSize + 1));
      expect(cursors, [null, 'p49']);
    });

    test('a host that repeats its page ends the read, nothing twice', () async {
      final page = [
        for (var i = 0; i < activityPageSize; i++) _row('p$i', minutes: i),
      ];
      var asked = 0;
      final all = await everyActivityPage((_) async {
        asked++;
        return page;
      });
      expect(asked, 2);
      expect(all, hasLength(activityPageSize));
    });

    test('a failed page fails the whole read', () async {
      await expectLater(
        everyActivityPage((before) async {
          if (before != null) throw StateError('down');
          return [
            for (var i = 0; i < activityPageSize; i++) _row('p$i', minutes: i),
          ];
        }),
        throwsStateError,
      );
    });

    test('the page is the RPC\'s own: 50', () {
      expect(activityPageSize, 50);
    });
  });

  group('the CSV of one workspace with its payments', () {
    test('payments follow the documents, unmasked, newest first, each row '
        'naming its record and its source', () {
      final overview = FinanceOverview(
        invoices: [invoice('b1', ws: 'Lyon', currency: 'CHF', total: 8000)],
      ).reading(const [_lyon]).hostSettled(
        _lyon,
        FinanceHostStatus.answered,
        FinanceOverview(invoices: [invoice('b1', ws: 'Lyon')]),
      );
      final rows = _lines(
        ownFinanceCsv(
          overview,
          payments: OwnPayments(const HostFinanceSource(_lyon), [
            _row('old', minutes: 5, amount: 1234, currency: 'KWD'),
            _row('new'),
          ]),
        ),
      );
      expect(
        rows.first,
        'number,workspace,issued_at,due_on,state,currency,total,paid,'
        'remaining,reminders,invoice_id,record,source,paid_at,payment_id,'
        'description',
      );
      expect(rows, hasLength(4));
      expect(rows[1], endsWith(',"b1",invoice,"Lyon",,,'));
      expect(
        rows[2],
        '"R-new","Lyon",,,"confirmed","CHF",,80.00,,,,payment,"Lyon",'
        '2026-09-28T00:00:00.000Z,"new","Card"',
      );
      expect(rows[3], contains(',"KWD",,1.234,'));
    });

    test('the personal home is named home; a payment\'s text cells cannot '
        'start a formula', () {
      final evil = AccountActivity(
        id: 'x',
        workspaceId: 'ws-Office A',
        workspaceName: 'Office A',
        occurredAt: DateTime.utc(2026, 9),
        reference: '=HYPERLINK("http://evil")',
        description: '+1\nrow',
        currency: 'EUR',
        status: 'confirmed',
        amountCents: 500,
      );
      final rows = _lines(
        ownFinanceCsv(
          FinanceOverview(invoices: [invoice('1')]),
          payments: OwnPayments(const HomeFinanceSource(), [evil]),
        ),
      );
      expect(rows[1], contains(',invoice,"home",'));
      expect(rows[2], startsWith('"\'=HYPERLINK(""http://evil"")",'));
      expect(
        rows[2],
        endsWith(',payment,"home",2026-09-01T00:00:00.000Z,"x","\'+1 row"'),
      );
    });

    test('a source that did not answer for the payments is noted once', () {
      final rows = _lines(
        ownFinanceCsv(
          FinanceOverview(invoices: [invoice('1')]),
          payments: const OwnPayments.unavailable(
            SelectedFinanceSource('https://w-b.test'),
          ),
        ),
      );
      expect(rows, hasLength(3));
      expect(rows[2], startsWith('"# unavailable_source","w-b.test",'));
    });
  });

  group('Me › Finances › Export with payments', () {
    Future<void> pumpFinances(
      WidgetTester tester,
      FakeAccountActivityRepository home,
      _Reader reader,
      _Saver saver, {
      Stream<String?>? session,
    }) async {
      await pumpApp(
        tester,
        const MyFinancesScreen(),
        size: const Size(1440, 1400),
        overrides: [
          ..._overrides(home, reader, session: session),
          fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
          typedFileSaverProvider.overrideWithValue(saver.save),
        ],
      );
      await tester.pumpAndSettle();
    }

    Future<void> export(WidgetTester tester, String workspace) async {
      await tester.tap(_key('my-finances-export'));
      await tester.pumpAndSettle();
      await tester.tap(_key('my-finances-export-ws-$workspace'));
      await tester.pumpAndSettle();
    }

    _Reader lyon() => _Reader()
      ..overviews['inst-b'] = FinanceOverview(
        invoices: [invoice('b1', ws: 'Lyon')],
      )
      ..rows['inst-b'] = [
        for (var i = 0; i < activityPageSize + 1; i++)
          _row('pay-$i', minutes: i),
        _row('elsewhere', ws: 'Geneva', minutes: 200),
      ];

    testWidgets('a host\'s workspace carries every page of its payments, '
        'read on that host and named after it', (tester) async {
      final saver = _Saver();
      final reader = lyon();
      await pumpFinances(tester, FakeAccountActivityRepository(), reader, saver);
      await export(tester, 'Lyon');

      final rows = _lines(saver.files.values.single);
      final payments = rows.where((r) => r.contains(',payment,')).toList();
      expect(payments, hasLength(activityPageSize + 1));
      expect(payments.every((r) => r.contains(',payment,"Lyon",')), isTrue);
      expect(payments.first, contains(',"CHF",,80.00,'));
      expect(rows.where((r) => r.contains('elsewhere')), isEmpty);
      expect(
        reader.asked.where((a) => a.startsWith('inst-b:payments:')),
        containsAll(['inst-b:payments:null', 'inst-b:payments:pay-49']),
      );
      expect(rows.where((r) => r.contains('unavailable_source')), isEmpty);
    });

    testWidgets('the home\'s workspace carries the home\'s payments',
        (tester) async {
      final saver = _Saver();
      final home = FakeAccountActivityRepository()
        ..financeOverview = FinanceOverview(invoices: [invoice('1')])
        ..records[AccountActivityKind.payments] = [
          _row('pay-home', ws: 'Office A', currency: 'EUR', amount: 1200),
        ];
      await pumpFinances(tester, home, _Reader(), saver);
      await export(tester, 'Office A');

      final rows = _lines(saver.files.values.single);
      expect(rows.last, contains(',"EUR",,12.00,,,,payment,"home",'));
    });

    testWidgets('a host that does not answer for the payments is noted in '
        'the file; exported again, they are there', (tester) async {
      final saver = _Saver();
      final reader = lyon()..down.add('inst-b');
      await pumpFinances(tester, FakeAccountActivityRepository(), reader, saver);
      await export(tester, 'Lyon');

      var rows = _lines(saver.files.values.single);
      expect(rows.where((r) => r.contains(',payment,')), isEmpty);
      expect(rows.last, startsWith('"# unavailable_source","Lyon",'));
      expect(rows.where((r) => r.contains(',invoice,')), hasLength(1));

      reader.down.remove('inst-b');
      saver.files.clear();
      await export(tester, 'Lyon');
      rows = _lines(saver.files.values.single);
      expect(
        rows.where((r) => r.contains(',payment,')),
        hasLength(activityPageSize + 1),
      );
      expect(rows.where((r) => r.contains('unavailable_source')), isEmpty);
    });

    testWidgets('CACHE-01: payments read for one account are never written '
        'to a file under another', (tester) async {
      final session = StreamController<String?>.broadcast();
      addTearDown(session.close);
      final saver = _Saver();
      final reader = lyon();
      await pumpFinances(
        tester,
        FakeAccountActivityRepository(),
        reader,
        saver,
        session: session.stream,
      );
      session.add('person-1');
      await _frames(tester);
      final stale = reader.hold('inst-b');
      await export(tester, 'Lyon');

      session.add('person-2');
      await _frames(tester);
      stale.complete([_row('old')]);
      await _frames(tester);
      expect(saver.calls, 0);
    });
  });
  group('Me › Finances › Payments, host by host', () {
    Future<void> pumpPayments(
      WidgetTester tester,
      _Reader reader,
    ) async {
      await pumpApp(
        tester,
        const MyFinancesScreen(),
        size: const Size(1440, 9000),
        overrides: _overrides(FakeAccountActivityRepository(), reader),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'finances-tab-payments');
    }

    /// Lyon holds one page and one row more; its overview answered the
    /// first page, as the host reader does. Nice holds one payment.
    _Reader twoHosts() {
      final lyon = [
        for (var i = 0; i < activityPageSize + 1; i++)
          _row('pay-$i', minutes: i),
      ];
      return _Reader()
        ..rows['inst-b'] = lyon
        ..overviews['inst-b'] = FinanceOverview(
          invoices: [invoice('b1', ws: 'Lyon')],
          payments: lyon.take(activityPageSize).toList(),
        )
        ..rows['inst-c'] = [_row('nice-1', ws: 'Nice', minutes: 300)]
        ..overviews['inst-c'] = FinanceOverview(
          payments: [_row('nice-1', ws: 'Nice', minutes: 300)],
        );
    }

    testWidgets('a host with a full first page offers more of its own, read '
        'on that host after its last row; a short page ends it', (
      tester,
    ) async {
      final reader = twoHosts();
      await pumpPayments(tester, reader);
      expect(_key('finances-payment-pay-0'), findsOneWidget);
      expect(_key('finances-payment-pay-49'), findsOneWidget);
      expect(_key('finances-payment-pay-50'), findsNothing);
      expect(_key('finances-payment-nice-1'), findsOneWidget);
      expect(_key('finances-payments-more-inst-c'), findsNothing,
          reason: 'a short first page has nothing more');
      expect(reader.askedOf('inst-b'), 0);

      await _tap(tester, 'finances-payments-more-inst-b');
      expect(reader.asked, ['inst-b:payments:pay-49']);
      expect(_key('finances-payment-pay-50'), findsOneWidget);
      expect(_key('finances-payment-pay-0'), findsOneWidget);
      expect(_key('finances-payments-more-inst-b'), findsNothing);
    });

    testWidgets('a page that does not answer is named with its own Try '
        'again; the rows shown stay, and the retry reads that page again', (
      tester,
    ) async {
      final reader = twoHosts()..down.add('inst-b');
      await pumpPayments(tester, reader);
      await _tap(tester, 'finances-payments-more-inst-b');
      expect(_key('finances-payments-more-retry-inst-b'), findsOneWidget);
      expect(_key('finances-payment-pay-49'), findsOneWidget);
      expect(_key('finances-payment-nice-1'), findsOneWidget);

      reader.down.remove('inst-b');
      await _tap(tester, 'finances-payments-more-retry-inst-b');
      expect(_key('finances-payment-pay-50'), findsOneWidget);
      expect(reader.asked, [
        'inst-b:payments:pay-49',
        'inst-b:payments:pay-49',
      ]);
    });
  });

  group('Me › Finances › Export of a workspace with payments only', () {
    Future<void> pumpFinances(
      WidgetTester tester,
      FakeAccountActivityRepository home,
      _Reader reader,
      _Saver saver,
    ) async {
      await pumpApp(
        tester,
        const MyFinancesScreen(),
        size: const Size(1440, 1400),
        overrides: [
          ..._overrides(home, reader),
          fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
          typedFileSaverProvider.overrideWithValue(saver.save),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a connected host\'s workspace with payments and no invoice '
        'has its entry; its file carries its payments, named after the '
        'host', (tester) async {
      final saver = _Saver();
      final reader = _Reader()
        ..rows['inst-b'] = [_row('pay-1')]
        ..overviews['inst-b'] = FinanceOverview(payments: [_row('pay-1')]);
      await pumpFinances(tester, FakeAccountActivityRepository(), reader, saver);
      await _tap(tester, 'my-finances-export');
      await _tap(tester, 'my-finances-export-ws-Lyon');

      final rows = _lines(saver.files.values.single);
      final payments = rows.where((r) => r.contains(',payment,')).toList();
      expect(payments, hasLength(1));
      expect(payments.single, contains(',payment,"Lyon",'));
      expect(rows.where((r) => r.contains(',invoice,')), isEmpty);
    });

    testWidgets('the home\'s workspace with payments and no invoice has its '
        'entry, read on the home', (tester) async {
      final saver = _Saver();
      final home = FakeAccountActivityRepository()
        ..records[AccountActivityKind.payments] = [
          _row('pay-home', ws: 'Office A', currency: 'EUR', amount: 1200),
        ];
      await pumpFinances(tester, home, _Reader(), saver);
      await _tap(tester, 'my-finances-export');
      await _tap(tester, 'my-finances-export-ws-Office A');

      final rows = _lines(saver.files.values.single);
      expect(rows.last, contains(',"EUR",,12.00,,,,payment,"home",'));
    });
  });
}
