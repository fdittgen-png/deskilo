// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 -- the Demo's cycle counts, behind the same port as the server's and on the Demo's ONE ledger:
// one plan for the shop's high-value shelf has made a task (still open, past its due day, so the inbox
// notice and the page agree), whose lines are the goods the ledger holds at or above the plan's
// threshold, listed WITHOUT what is expected. Counting a line records a count of #4172 in the same
// store its counts page reads, so the approval flow is the one already there; a blind counter is told
// the line is counted and never what the ledger held; a skip needs a reason; a task is complete when
// every line is counted or skipped. Nothing leaves the process.
import 'package:deskilo/features/stock/domain/stock_count_tasks.dart';
import 'package:deskilo/features/stock/domain/stock_cycle_counts.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_reversal_book.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../codes/dk_code.dart';
import 'demo_stock_ledger.dart';
import 'demo_stock_tags.dart';

PostgrestException _refused(String code, String message) => PostgrestException(message: message, code: code);

String _day(DateTime at) => at.toIso8601String().substring(0, 10);

/// The in-memory cycle counts of the reference business.
class DemoStockCycleCounts implements StockCycleCounts {
  DemoStockCycleCounts(this._workspaceId, this._ledger, this._reversals, this._registry, this._tags, this._held, this._now);

  final String _workspaceId;
  final DemoStockLedger _ledger;
  final StockReversals _reversals;
  final StockRegistry _registry;
  final DemoStockTags _tags;

  /// What the person holds: a blind counter does not see what the ledger expects.
  final Set<WorkspacePermission> Function() _held;
  final DateTime Function() _now;

  /// The tasks and the rules of their lines: the domain's (#4403).
  final CountTaskBook _book = CountTaskBook();
  final Map<String, CountLineResult> _answers = {};
  bool _seeded = false;

  /// Runs [run] for the reference business, a refusal leaving as the server's own (its code and message).
  Future<T> _run<T>(String workspaceId, String what, Future<T> Function() run) async {
    if (!_mine(workspaceId)) throw _refused(DkCode.dkg04, 'not a $what of this business');
    await _seed();
    try {
      return await run();
    } on StockCodeRefused catch (e, st) {
      Error.throwWithStackTrace(_refused(e.code, e.message), st);
    }
  }

  bool _mine(String id) => id == _workspaceId;

  /// What a place holds of an item is worth this many minor units at the registry's last known cost.
  static int? _value(StockOnHandRow r, Map<String, String?> costs) {
    final cost = costs[r.itemId];
    if (cost == null) return null;
    final scaled = r.quantity.micro * BigInt.parse(cost);
    final unit = BigInt.from(10).pow(exactQuantityScale);
    return ((scaled + unit ~/ BigInt.two) ~/ unit).toInt();
  }

  Future<void> _seed() async {
    if (_seeded) return;
    _seeded = true;
    final now = _now();
    final plan = _book.plans['demo-count-plan-1'] = CountPlan(
      id: 'demo-count-plan-1',
      name: 'High-value shelf',
      scope: CountScope.highValue,
      locationIds: const [],
      itemIds: const [],
      highValueMinor: 2000,
      intervalDays: 14,
      nextDueOn: _day(now.add(const Duration(days: 5))),
      active: true,
    );
    final due = now.subtract(const Duration(days: 9));
    final costs = {for (final r in (await _registry.page(_workspaceId, limit: 200)).rows) r.itemId: r.cost};
    final rows = [
      for (final r in await _ledger.onHand())
        if ((_value(r, costs) ?? 0) >= 2000) r,
    ];
    _book.addTask('demo-count-task-1', plan, _day(due), [
      for (var i = 0; i < rows.length; i++)
        CountTaskLine(
          lineId: 'demo-count-line-${i + 1}',
          itemId: rows[i].itemId,
          variantId: rows[i].variantId,
          lotId: rows[i].lotId,
          locationId: rows[i].locationId,
          state: CountLineState.pending,
        ),
    ]);
    // what the earlier counts said: the beans were counted three times, twice exactly
    if (rows.any((r) => r.itemId == 'demo-item-beans')) {
      final r = rows.firstWhere((x) => x.itemId == 'demo-item-beans');
      _book.remember(r.itemId, r.locationId, (at: now.subtract(const Duration(days: 23)), counts: 3, exact: 2));
    }
  }

  @override
  Future<List<CountPlan>> plans(String workspaceId) async {
    if (!_mine(workspaceId)) return const [];
    await _seed();
    return _book.plans.values.toList();
  }

  @override
  Future<void> savePlan(String workspaceId, CountPlanDraft d) => _run(workspaceId, 'plan', () async {
    CountTaskBook.checkPlan(d);
    _book.plans[d.planId] = CountPlan(
      id: d.planId,
      name: d.name.trim(),
      scope: d.scope,
      locationIds: d.locationIds,
      itemIds: d.itemIds,
      highValueMinor: d.highValueMinor,
      intervalDays: d.intervalDays,
      nextDueOn: d.nextDueOn,
      active: d.active,
    );
  });

  @override
  Future<List<CountTaskSummary>> tasks(String workspaceId, {CountTaskState? state}) async {
    if (!_mine(workspaceId)) return const [];
    await _seed();
    return _book.summaries(state: state);
  }

  @override
  Future<CountTask> task(String workspaceId, String taskId) => _run(workspaceId, 'task', () async => _book.task(taskId));

  bool _sees() {
    final held = _held();
    return held.contains(WorkspacePermission.manageStock) || held.contains(WorkspacePermission.approveStockAdjustments);
  }

  @override
  Future<CountLineResult> countLine(String workspaceId, String lineId, String observed, String requestId) async {
    if (_answers[requestId] case final done?) return done;
    return _answers[requestId] = await _run(workspaceId, 'line', () async {
      final line = _book.lineToCount(lineId, observed.trim());
      final baseline = _ledger.balance(line.itemId, line.locationId, lotId: line.lotId);
      await _reversals.recordCount(workspaceId, (
        countId: 'cycle-$lineId',
        itemId: line.itemId,
        locationId: line.locationId,
        observed: observed.trim(),
        requestId: requestId,
        variantId: line.variantId,
        lotId: line.lotId,
        reason: 'cycle count',
      ));
      return _book.counted(lineId, ExactQuantity.parse(observed.trim()), baseline, sees: _sees(), at: _now());
    });
  }

  @override
  Future<CountLineResult> skipLine(String workspaceId, String lineId, String reason, String requestId) async {
    if (_answers[requestId] case final done?) return done;
    return _answers[requestId] = await _run(workspaceId, 'line', () async => _book.skip(lineId, reason));
  }

  @override
  Future<List<CountHistoryRow>> history(String workspaceId) async {
    if (!_mine(workspaceId)) return const [];
    await _seed();
    return _book.history;
  }

  final Map<String, BulkCountResult> _bulk = {};

  @override
  Future<BulkCountResult> countByTagRead(String workspaceId, {required String requestId, required String taskId, required List<String> codes}) async {
    if (_bulk[requestId] case final done?) {
      return BulkCountResult(taskState: done.taskState, lines: done.lines, leftOut: done.leftOut, missing: done.missing, replayed: true);
    }
    final pending = await _run(workspaceId, 'task', () async => _book.openLines(taskId));
    final sees = _sees();
    final seen = <String>{};
    final byItem = <String, int>{};
    final left = <BulkLeftOut>[];
    for (final raw in codes) {
      final typed = raw.trim();
      if (typed.isEmpty || raw.length > 200) {
        left.add(BulkLeftOut(code: typed, reason: 'invalid'));
        continue;
      }
      final code = DemoStockTags.normalise(typed);
      if (!seen.add(code)) continue;
      final item = _tags.pieceItemOf(code);
      if (item == null) {
        left.add(BulkLeftOut(code: code, reason: 'not_a_piece'));
      } else {
        byItem[item] = (byItem[item] ?? 0) + 1;
      }
    }
    final counted = <BulkCountedLine>[];
    for (final line in pending) {
      final n = byItem[line.itemId];
      if (n == null) continue;
      await countLine(workspaceId, line.lineId, '$n', 'bulk-$requestId-${line.lineId}');
      counted.add(BulkCountedLine(lineId: line.lineId, itemId: line.itemId, locationId: line.locationId, read: n, state: 'counted'));
    }
    return _bulk[requestId] = BulkCountResult(
      taskState: _book.stateOf(taskId),
      lines: counted,
      leftOut: left,
      missing: sees ? const [] : null,
      replayed: false,
    );
  }
}
