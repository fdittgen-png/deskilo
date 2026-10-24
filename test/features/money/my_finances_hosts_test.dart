// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C5 — Me › Finances reads every connected host my personal account
// names, each with its own client and its own state: one that answers adds
// its documents and is named in the coverage, one that does not is named
// with its own Try again while the others stay, the reads are bounded by
// the personal limits, and an answer that arrives after the account
// changed never lands. Compact cards hide their amount until asked, and
// the Outstanding face is newest first with the qualified id breaking a
// tie.
import 'dart:async';
import 'dart:math' as math;

import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/money/domain/finance_hosts.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/own_finance_csv.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/features/money/providers/finance_host_providers.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;

/// The personal home, counting its reads.
class _Home extends FakeAccountActivityRepository {
  int reads = 0;

  @override
  Future<FinanceOverview> overview() {
    reads++;
    return super.overview();
  }
}

/// The connected hosts, each answering for itself: an answer set by the
/// test, a failure, or a read held open until the test completes it.
class _Reader implements FinanceHostReader {
  final answers = <String, FinanceOverview>{};
  final down = <String>{};
  final held = <String, Completer<FinanceOverview>>{};
  final reads = <String, int>{};
  int running = 0;
  int mostAtOnce = 0;

  Completer<FinanceOverview> hold(String id) => held[id] = Completer();

  @override
  Future<FinanceOverview> overview(FinanceHost host) async {
    final id = host.installationId;
    reads[id] = (reads[id] ?? 0) + 1;
    running++;
    mostAtOnce = math.max(mostAtOnce, running);
    try {
      final wait = held.remove(id);
      if (wait != null) return await wait.future;
      if (down.contains(id)) throw const FinanceHostUnavailable('down');
      return answers[id] ?? const FinanceOverview();
    } finally {
      running--;
    }
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
  _Home home,
  _Reader reader, {
  int concurrency = 2,
  Duration timeout = const Duration(seconds: 5),
  bool withoutLimits = false,
}) => [
  ...standardTestOverrides(
    auth: FakeAuthRepository.signedIn(),
    accountActivity: home,
  ),
  financeHostsProvider.overrideWith((ref) async => const [_here, _lyon, _nice]),
  financeHostReaderProvider.overrideWithValue(reader),
  financeReadLimitsProvider.overrideWith(
    (ref) async => withoutLimits
        ? throw const FinanceHostUnavailable('no limits')
        : FinanceReadLimits(concurrency: concurrency, timeout: timeout),
  ),
];

Future<void> _pump(
  WidgetTester tester,
  _Home home,
  _Reader reader, {
  Size size = const Size(1440, 1400),
  Duration timeout = const Duration(seconds: 5),
}) async {
  await pumpApp(
    tester,
    const MyFinancesScreen(),
    size: size,
    overrides: _overrides(home, reader, timeout: timeout),
  );
  await tester.pumpAndSettle();
}

_Home _homeWith(List<FinanceInvoice> invoices) =>
    _Home()..financeOverview = FinanceOverview(invoices: invoices);

_Reader _hosts() => _Reader()
  ..answers['inst-b'] = FinanceOverview(invoices: [invoice('b1', ws: 'Lyon')])
  ..answers['inst-c'] = FinanceOverview(invoices: [invoice('c1', ws: 'Nice')]);

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('every connected host my account names adds its own '
      'documents and is named in the coverage; the home\'s own '
      'installation is not asked again', (tester) async {
    final home = _homeWith([invoice('p1')]);
    final reader = _hosts();
    await _pump(tester, home, reader);

    for (final id in ['p1', 'b1', 'c1']) {
      expect(_key('finances-invoice-$id'), findsOneWidget, reason: id);
    }
    expect(
      find.descendant(
        of: _key('finances-coverage-host-inst-b'),
        matching: find.textContaining('Lyon: 1 document'),
      ),
      findsOneWidget,
    );
    expect(_key('finances-coverage-host-inst-c'), findsOneWidget);
    expect(home.reads, 1);
    expect(reader.reads, {'inst-b': 1, 'inst-c': 1});
  });

  testWidgets('a host that does not answer is named with its own Try '
      'again; the others stay, and only that host is read again', (
    tester,
  ) async {
    final home = _homeWith([invoice('p1')]);
    final reader = _hosts()..down.add('inst-c');
    await _pump(tester, home, reader);

    final banner = _key('finances-source-unavailable-inst-c');
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.textContaining('Nice')),
      findsOneWidget,
    );
    expect(_key('finances-invoice-p1'), findsOneWidget);
    expect(_key('finances-invoice-b1'), findsOneWidget);
    expect(_key('finances-invoice-c1'), findsNothing);
    expect(_key('finances-retry'), findsNothing,
        reason: 'one host down is not the whole overview failing');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyFinancesScreen)),
    );
    expect(
      ownFinanceCsvLines(container.read(financeOverviewProvider).value!),
      contains('"# unavailable_source","Nice",,,,,,,,,'),
      reason: 'the file says which host it lacks',
    );

    reader.down.clear();
    await tester.tap(
      find.descendant(of: banner, matching: find.text('Try again')),
    );
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    expect(_key('finances-invoice-c1'), findsOneWidget);
    expect(reader.reads, {'inst-b': 1, 'inst-c': 2});
    expect(home.reads, 1, reason: 'the other hosts keep their own state');
  });

  testWidgets('a host that does not answer within the personal timeout is '
      'named, not waited for', (tester) async {
    final reader = _hosts()..hold('inst-b');
    await pumpApp(
      tester,
      const MyFinancesScreen(),
      size: const Size(1440, 1400),
      overrides: _overrides(
        _homeWith([invoice('p1')]),
        reader,
        timeout: const Duration(seconds: 3),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(_key('finances-coverage-reading-inst-b'), findsOneWidget);
    expect(_key('finances-invoice-c1'), findsOneWidget,
        reason: 'a healthy host renders while another stalls');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(_key('finances-coverage-reading-inst-b'), findsNothing);
    expect(_key('finances-source-unavailable-inst-b'), findsOneWidget);
  });

  test('at most personal.read_concurrency hosts are read at once', () async {
    final reader = _Reader();
    final lyon = reader.hold('inst-b');
    final nice = reader.hold('inst-c');
    final container = ProviderContainer(
      overrides: _overrides(_homeWith(const []), reader, concurrency: 1),
    );
    addTearDown(container.dispose);
    final sub = container.listen(financeOverviewProvider, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    await container.read(financeOverviewProvider.future);
    await pumpEventQueue();
    expect(reader.running, 1);
    lyon.complete(const FinanceOverview());
    await pumpEventQueue();
    expect(reader.reads, {'inst-b': 1, 'inst-c': 1});
    nice.complete(const FinanceOverview());
    await pumpEventQueue();
    expect(reader.mostAtOnce, 1);
    final hosts = container.read(financeOverviewProvider).value!.hosts;
    expect(hosts.map((h) => h.status), [
      FinanceHostStatus.answered,
      FinanceHostStatus.answered,
    ]);
  });

  test('without the personal limits every connected host is named as not '
      'read; the home\'s documents stay', () async {
    final reader = _hosts();
    final container = ProviderContainer(
      overrides: _overrides(
        _homeWith([invoice('p1')]),
        reader,
        withoutLimits: true,
      ),
    );
    addTearDown(container.dispose);
    final sub = container.listen(financeOverviewProvider, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    final overview = await container.read(financeOverviewProvider.future);
    expect(overview.invoices.map((i) => i.id), ['p1']);
    expect(overview.hosts.map((h) => h.status), [
      FinanceHostStatus.failed,
      FinanceHostStatus.failed,
    ]);
    expect(overview.notAnswered, ['Lyon', 'Nice']);
    expect(reader.reads, isEmpty);
  });

  test('an answer that arrives after the account changed never lands', () async {
    final session = StreamController<String?>.broadcast();
    addTearDown(session.close);
    final reader = _Reader();
    final stale = reader.hold('inst-b');
    final container = ProviderContainer(
      overrides: [
        ..._overrides(_homeWith(const []), reader),
        sessionStateProvider.overrideWith((ref) => session.stream),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(financeOverviewProvider, (_, _) {});
    addTearDown(sub.close);
    session.add('person-1');
    await pumpEventQueue();
    await container.read(financeOverviewProvider.future);
    await pumpEventQueue();

    // Another account signs in; its read of the same host waits.
    final fresh = reader.hold('inst-b');
    session.add('person-2');
    await pumpEventQueue();
    await container.read(financeOverviewProvider.future);
    await pumpEventQueue();

    stale.complete(FinanceOverview(invoices: [invoice('old', ws: 'Lyon')]));
    await pumpEventQueue();
    var now = container.read(financeOverviewProvider).value!;
    expect(now.invoices, isEmpty,
        reason: 'the first account\'s documents never fill the second\'s view');
    expect(
      now.hosts.firstWhere((h) => h.host == _lyon).status,
      FinanceHostStatus.reading,
    );

    fresh.complete(FinanceOverview(invoices: [invoice('new', ws: 'Lyon')]));
    await pumpEventQueue();
    now = container.read(financeOverviewProvider).value!;
    expect(now.invoices.map((i) => i.id), ['new']);
  });

  test('two hosts\' equal local ids in different workspaces are two '
      'documents; the same qualified id is one', () {
    final merged = FinanceOverview(invoices: [invoice('1')]).merge(
      FinanceOverview(
        invoices: [invoice('1', ws: 'Lyon'), invoice('1')],
      ),
    );
    expect(
      merged.invoices.map((i) => '${i.workspaceId}:${i.id}'),
      ['ws-Office A:1', 'ws-Lyon:1'],
    );
  });

  testWidgets('a compact card hides its amount until asked, and hides it '
      'again', (tester) async {
    await _pump(
      tester,
      _homeWith([invoice('p1', total: 12345)]),
      _Reader(),
      size: const Size(390, 844),
    );
    final amount = _key('finances-amount-p1');
    expect(
      find.descendant(of: amount, matching: find.text('EUR ••••')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: amount, matching: find.textContaining('123')),
      findsNothing,
    );
    await tester.tap(amount);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: amount, matching: find.textContaining('123.45')),
      findsOneWidget,
    );
    await tester.tap(amount);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: amount, matching: find.text('EUR ••••')),
      findsOneWidget,
    );
  });

  testWidgets('a wide row shows its amount', (tester) async {
    await _pump(tester, _homeWith([invoice('p1', total: 12345)]), _Reader());
    expect(_key('finances-amount-p1'), findsNothing);
    expect(
      find.descendant(
        of: _key('finances-invoice-p1'),
        matching: find.textContaining('123.45'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Outstanding is newest first; the qualified id breaks a tie', (
    tester,
  ) async {
    FinanceInvoice dated(String id, String ws, DateTime at) => FinanceInvoice(
      id: id,
      workspaceId: 'ws-$ws',
      workspaceName: ws,
      number: 'INV-$id',
      issuedAt: at,
      // An earlier due date does not move a document up.
      dueOn: id == 'old' ? DateTime(2026, 1, 2) : null,
      totalCents: 100,
      paidCents: 0,
      currency: 'EUR',
      state: FinanceState.open,
    );
    await _pump(
      tester,
      _homeWith([
        dated('old', 'Office A', DateTime.utc(2026, 1, 5)),
        dated('2', 'Office A', DateTime.utc(2026, 9)),
        dated('2', 'Lyon', DateTime.utc(2026, 9)),
        dated('new', 'Office A', DateTime.utc(2026, 10)),
      ]),
      _Reader(),
    );
    final cards = find.byWidgetPredicate((w) {
      final key = w.key;
      return w is Card &&
          key is ValueKey<String> &&
          key.value.startsWith('finances-invoice-');
    });
    final order = [
      for (final card in cards.evaluate())
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byWidget(card.widget),
                    matching: find.textContaining('INV-'),
                  )
                  .first,
            )
            .data,
    ];
    expect(order, ['INV-new', 'INV-2', 'INV-2', 'INV-old']);
    bool has(Element card, String text) => find
        .descendant(of: find.byWidget(card.widget), matching: find.text(text))
        .evaluate()
        .isNotEmpty;
    final workspaces = [
      for (final card in cards.evaluate())
        if (has(card, 'INV-2'))
          if (has(card, 'Lyon')) 'Lyon' else 'Office A',
    ];
    expect(workspaces, ['Lyon', 'Office A'],
        reason: 'ws-Lyon sorts before ws-Office A on the same day');
  });
}

/// The CSV of [overview], line by line.
List<String> ownFinanceCsvLines(FinanceOverview overview) =>
    String.fromCharCodes(ownFinanceCsv(overview)).split('\r\n');
