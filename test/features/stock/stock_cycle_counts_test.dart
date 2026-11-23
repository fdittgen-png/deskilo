// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 (G9, client): cycle counts as a person uses them, at a phone (390) and a desk (1440) width.
// The tasks to count, the plans a stock manager keeps (a scope, a schedule, mistakes said under their
// field) and the history. A task is counted BLIND: the lines say what and where and never what the
// ledger expects; a barcode finds the line; counting sends the observed quantity once per request id;
// a person who may only count is told the line is counted, one who manages the stock is told the
// difference; a skip needs a reason; a closed task offers no buttons; a failed read says so and asks
// again. Nothing here moves a balance.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_code_resolver.dart';
import 'package:deskilo/features/stock/domain/stock_cycle_counts.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/presentation/stock_count_task_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_cycle_counts_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _Stock implements StockQueries {
  @override
  Future<List<StockItem>> items(String workspaceId) async => const [
    StockItem(id: 'i-beans', name: 'Coffee beans', unit: 'kg'),
    StockItem(id: 'i-mugs', name: 'Mugs', unit: 'piece'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Registry implements StockRegistry {
  @override
  Future<StockPage<StockRegistryRow>> page(String workspaceId, {String? placeId, bool noHome = false, int limit = 50, StockCursor? after}) async =>
      StockPage(
        complete: true,
        rows: [
          StockRegistryRow(itemId: 'i-beans', itemName: 'Coffee beans', unit: 'kg', onHand: ExactQuantity.parse('12'), barcode: '3017620422003'),
          StockRegistryRow(itemId: 'i-mugs', itemName: 'Mugs', unit: 'piece', onHand: ExactQuantity.parse('8'), barcode: '4006381333931'),
        ],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Resolves a code the way the server does, whatever the size of the registry: the barcode of an item names the item.
class _Resolver implements StockCodeResolver {
  _Resolver([Map<String, ScannedItem>? byCode])
    : _byCode = byCode ?? {
        '3017620422003': const ScannedItem(id: 'i-beans', name: 'Coffee beans', unit: 'kg'),
        '4006381333931': const ScannedItem(id: 'i-mugs', name: 'Mugs', unit: 'piece'),
      };

  final Map<String, ScannedItem> _byCode;

  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async {
    final item = _byCode[code];
    return item == null ? StockCodeResolution.unknown(code) : StockCodeResolution(kind: ScannedKind.item, code: code, item: item);
  }
}

class _Cycle implements StockCycleCounts {
  _Cycle({this.failTasks = false, this.state = CountTaskState.open, this.seeDifference = false, List<CountTaskLine> more = const []}) {
    lines = [
      ...more,
      const CountTaskLine(lineId: 'l-1', itemId: 'i-beans', locationId: 'demo-place-main', state: CountLineState.pending),
      const CountTaskLine(lineId: 'l-2', itemId: 'i-mugs', locationId: 'demo-place-main', state: CountLineState.pending),
    ];
  }

  bool failTasks;
  final CountTaskState state;
  final bool seeDifference;
  late List<CountTaskLine> lines;
  final counted = <({String line, String observed, String request})>[];
  final skipped = <({String line, String reason})>[];
  final saved = <CountPlanDraft>[];
  int taskCalls = 0;

  @override
  Future<List<CountPlan>> plans(String workspaceId) async => const [
    CountPlan(id: 'p-1', name: 'High-value shelf', scope: CountScope.highValue, locationIds: [], itemIds: [], highValueMinor: 5000, intervalDays: 14, nextDueOn: '2026-03-20', active: true),
  ];

  @override
  Future<void> savePlan(String workspaceId, CountPlanDraft draft) async => saved.add(draft);

  @override
  Future<List<CountTaskSummary>> tasks(String workspaceId, {CountTaskState? state}) async {
    taskCalls++;
    if (failTasks) {
      failTasks = false;
      throw StateError('unreachable');
    }
    return [
      CountTaskSummary(taskId: 't-1', planId: 'p-1', planName: 'High-value shelf', dueOn: '2026-03-10', state: this.state, lines: 2, pending: lines.where((l) => l.state == CountLineState.pending).length),
    ];
  }

  @override
  Future<CountTask> task(String workspaceId, String taskId) async => CountTask(taskId: 't-1', dueOn: '2026-03-10', state: state, lines: List.of(lines));

  CountLineResult _answer(String id) => CountLineResult(
    lineId: id,
    taskState: CountTaskState.open,
    state: 'recorded',
    observed: seeDifference ? ExactQuantity.parse('11') : null,
    baseline: seeDifference ? ExactQuantity.parse('12') : null,
    difference: seeDifference ? ExactQuantity.parse('-1') : null,
  );

  @override
  Future<CountLineResult> countLine(String workspaceId, String lineId, String observed, String requestId) async {
    counted.add((line: lineId, observed: observed, request: requestId));
    lines = [
      for (final l in lines)
        if (l.lineId == lineId) CountTaskLine(lineId: l.lineId, itemId: l.itemId, locationId: l.locationId, state: CountLineState.counted) else l,
    ];
    return _answer(lineId);
  }

  @override
  Future<CountLineResult> skipLine(String workspaceId, String lineId, String reason, String requestId) async {
    skipped.add((line: lineId, reason: reason));
    lines = [
      for (final l in lines)
        if (l.lineId == lineId) CountTaskLine(lineId: l.lineId, itemId: l.itemId, locationId: l.locationId, state: CountLineState.skipped, skipReason: reason) else l,
    ];
    return CountLineResult(lineId: lineId, taskState: CountTaskState.open, state: 'skipped');
  }

  @override
  Future<List<CountHistoryRow>> history(String workspaceId) async => [
    CountHistoryRow(itemId: 'i-beans', locationId: 'demo-place-main', counts: 4, exact: 3, lastCountedAt: DateTime.utc(2026, 3)),
  ];
}

Future<void> _open(WidgetTester tester, Widget home, _Cycle cycle, Size size, {Set<WorkspacePermission>? held, StockCodeResolver? resolver}) async {
  await pumpApp(
    tester,
    home,
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(_Stock()),
      stockRegistryProvider.overrideWithValue(_Registry()),
      stockCodeResolverProvider.overrideWithValue(resolver ?? _Resolver()),
      stockConfigCommandsProvider.overrideWithValue(DemoStockConfigCommands('ws-1')),
      stockCycleCountsProvider.overrideWithValue(cycle),
      myPermissionsProvider.overrideWithValue(held ?? {WorkspacePermission.manageStock, WorkspacePermission.countStock}),
    ],
  );
  await _frames(tester);
}

/// Frames enough for a page, a sheet or a read to arrive (bounded: no settling loop).
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _phone = Size(390, 844);
const _desk = Size(1440, 900);

void main() {
  for (final (name, size) in [('phone', _phone), ('desk', _desk)]) {
    group('on a $name', () {
      testWidgets('the tasks to count are listed with the plan, the due day and what is left; a manager also sees plans and history', (tester) async {
        await _open(tester, const StockCycleCountsScreen(), _Cycle(), size);
        expect(find.byKey(const ValueKey('stock-cycle-task-t-1')), findsOneWidget);
        expect(find.textContaining('High-value shelf'), findsWidgets);
        expect(find.text(_en.stockCycleTaskProgress('2', '2')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-cycle-tab-plans')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-cycle-tab-history')), findsOneWidget);
      });

      testWidgets('a person who may only count has the tasks and nothing else (no plans, no history)', (tester) async {
        await _open(tester, const StockCycleCountsScreen(), _Cycle(), size, held: {WorkspacePermission.countStock});
        expect(find.byKey(const ValueKey('stock-cycle-task-t-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-cycle-tab-plans')), findsNothing);
        expect(find.byKey(const ValueKey('stock-cycle-tab-history')), findsNothing);
      });

      testWidgets('a failed read says so and asks again; it is never an empty list', (tester) async {
        final cycle = _Cycle(failTasks: true);
        await _open(tester, const StockCycleCountsScreen(), cycle, size);
        expect(find.byKey(const ValueKey('stock-cycle-tasks-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-cycle-no-tasks')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-tasks-retry')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-cycle-task-t-1')), findsOneWidget);
      });

      testWidgets('the plans show what each counts, how often and when next; the history says when and how exact', (tester) async {
        await _open(tester, const StockCycleCountsScreen(), _Cycle(), size);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-tab-plans')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-cycle-plan-p-1')), findsOneWidget);
        expect(find.textContaining(_en.stockCyclePlanEvery(14)), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-tab-history')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-cycle-history-i-beans-demo-place-main')), findsOneWidget);
        expect(find.textContaining(_en.stockCycleHistoryAccuracy(4, '75')), findsOneWidget);
      });

      testWidgets('a new plan: a mistake is said under its field, then the scope and schedule are sent once', (tester) async {
        final cycle = _Cycle();
        await _open(tester, const StockCycleCountsScreen(), cycle, size);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-tab-plans')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-add-plan')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-plan-save')));
        await _frames(tester);
        expect(cycle.saved, isEmpty, reason: 'no name and nothing chosen: nothing is sent');
        expect(find.text(_en.stockCyclePlanNameRequired), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-plan-scope-error')), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-plan-name')), 'Back room');
        await tester.tap(find.byKey(const ValueKey('stock-plan-place-demo-place-main')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('stock-plan-save')));
        await _frames(tester);
        final draft = cycle.saved.single;
        expect((draft.name, draft.scope, draft.intervalDays), ('Back room', CountScope.places, 14));
        expect(draft.locationIds, ['demo-place-main']);
        expect(draft.planId, isNotEmpty);
      });

      testWidgets('a task is counted blind: no expected quantity anywhere; counting sends what was counted once', (tester) async {
        final cycle = _Cycle();
        await _open(tester, const StockCountTaskScreen(taskId: 't-1'), cycle, size, held: {WorkspacePermission.countStock});
        expect(find.text(_en.stockCycleBlind), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-cycle-line-l-1')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-l-1')));
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-observed')), '11,5');
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-save')));
        await _frames(tester);
        expect(cycle.counted.single.observed, '11.5', reason: 'a decimal comma is read as the server reads it');
        expect(find.text(_en.stockCycleCounted), findsOneWidget, reason: 'a counter is told the line is counted, nothing more');
        expect(find.textContaining(_en.stockCycleCountedDifference('').split(':').first), findsNothing);
        expect(find.textContaining(_en.stockCycleLineCounted), findsWidgets);
      });

      testWidgets('a person who manages the stock is told the difference', (tester) async {
        final cycle = _Cycle(seeDifference: true);
        await _open(tester, const StockCountTaskScreen(taskId: 't-1'), cycle, size);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-l-1')));
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-observed')), '11');
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-save')));
        await _frames(tester);
        expect(find.text(_en.stockCycleCountedDifference('-1')), findsOneWidget);
      });

      testWidgets('a quantity that is not a number is said under the field and nothing is sent', (tester) async {
        final cycle = _Cycle();
        await _open(tester, const StockCountTaskScreen(taskId: 't-1'), cycle, size);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-l-1')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-save')));
        await _frames(tester);
        expect(cycle.counted, isEmpty);
      });

      testWidgets('a line is skipped only with a reason', (tester) async {
        final cycle = _Cycle();
        await _open(tester, const StockCountTaskScreen(taskId: 't-1'), cycle, size);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-skip-l-2')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-cycle-skip-save')));
        await _frames(tester);
        expect(cycle.skipped, isEmpty, reason: 'no reason, nothing is sent');
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-skip-reason')), 'Behind the pallet');
        await tester.tap(find.byKey(const ValueKey('stock-cycle-skip-save')));
        await _frames(tester);
        expect(cycle.skipped.single, (line: 'l-2', reason: 'Behind the pallet'));
        expect(find.textContaining(_en.stockCycleLineSkipped('Behind the pallet')), findsOneWidget);
      });

      testWidgets('a scanned barcode opens the line of its item; an unknown code says so', (tester) async {
        final cycle = _Cycle();
        await _open(tester, const StockCountTaskScreen(taskId: 't-1'), cycle, size);
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-scan')), '0000');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await _frames(tester);
        expect(find.text(_en.stockCycleScanNone), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-scan')), '4006381333931');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await _frames(tester);
        expect(find.text(_en.stockCycleCountObserved('piece')), findsOneWidget, reason: 'the mugs line, in its own unit');
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-observed')), '8');
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-save')));
        await _frames(tester);
        expect(cycle.counted.single.line, 'l-2');
      });

      testWidgets('a code of an item far beyond the first 200 of a registry of 250 opens its line', (tester) async {
        final byCode = {for (var i = 0; i < 250; i++) '90000000${i.toString().padLeft(5, '0')}': ScannedItem(id: 'i-$i', name: 'Item $i', unit: 'piece')};
        final cycle = _Cycle(more: const [CountTaskLine(lineId: 'l-240', itemId: 'i-240', locationId: 'demo-place-main', state: CountLineState.pending)]);
        await _open(tester, const StockCountTaskScreen(taskId: 't-1'), cycle, size, resolver: _Resolver(byCode));
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-scan')), '9000000000240');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-observed')), '3');
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-save')));
        await _frames(tester);
        expect(cycle.counted.single.line, 'l-240');
      });

      testWidgets('a task that is no longer open offers no count or skip', (tester) async {
        final cycle = _Cycle(state: CountTaskState.complete);
        await _open(tester, const StockCountTaskScreen(taskId: 't-1'), cycle, size);
        expect(find.byKey(const ValueKey('stock-cycle-count-l-1')), findsNothing);
        expect(find.byKey(const ValueKey('stock-cycle-scan')), findsNothing);
        expect(find.byKey(const ValueKey('stock-cycle-done')), findsOneWidget);
      });
    });
  }

  test('the model reads the server answers: a blind answer has no quantities, an approver sees the difference', () {
    final blind = CountLineResult.fromJson({'line_id': 'l', 'state': 'recorded', 'task_state': 'open'});
    expect(blind.difference, isNull);
    expect(blind.observed, isNull);
    final full = CountLineResult.fromJson({'line_id': 'l', 'state': 'recorded', 'task_state': 'complete', 'observed': '11.000000', 'baseline': '12.000000', 'difference': '-1.000000'});
    expect(full.difference?.text, '-1');
    expect(full.taskState, CountTaskState.complete);
    const history = CountHistoryRow(itemId: 'i', locationId: 'p', counts: 4, exact: 3);
    expect(history.accuracyPercent, 75);
    expect(const CountHistoryRow(itemId: 'i', locationId: 'p', counts: 0, exact: 0).accuracyPercent, isNull);
  });
}
