// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 -- the Demo's cycle counts, behind the same port as the server's and on the Demo's ONE ledger:
// one plan for the shop's high-value shelf has made a task (still open, past its due day, so the inbox
// notice and the page agree), whose lines are the goods the ledger holds at or above the plan's
// threshold, listed WITHOUT what is expected. Counting a line records a count of #4172 in the same
// store its counts page reads, so the approval flow is the one already there; a blind counter is told
// the line is counted and never what the ledger held; a skip needs a reason; a task is complete when
// every line is counted or skipped. Nothing leaves the process.
import 'package:deskilo/features/stock/domain/stock_cycle_counts.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../codes/dk_code.dart';
import 'demo_stock_ledger.dart';
import 'demo_stock_tags.dart';

PostgrestException _refused(String code, String message) => PostgrestException(message: message, code: code);

final _quantity = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');

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

  final Map<String, CountPlan> _plans = {};
  final List<({String taskId, String planId, String planName, String dueOn})> _tasks = [];
  final Map<String, List<CountTaskLine>> _lines = {};
  final Map<String, CountTaskState> _state = {};
  final Map<String, String> _taskOfLine = {};
  final Map<String, CountLineResult> _answers = {};
  final Map<String, ({DateTime at, int counts, int exact})> _history = {};
  bool _seeded = false;

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
    _plans['demo-count-plan-1'] = CountPlan(
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
    const taskId = 'demo-count-task-1';
    _tasks.add((taskId: taskId, planId: 'demo-count-plan-1', planName: 'High-value shelf', dueOn: _day(due)));
    _state[taskId] = rows.isEmpty ? CountTaskState.complete : CountTaskState.open;
    _lines[taskId] = [
      for (var i = 0; i < rows.length; i++)
        CountTaskLine(
          lineId: 'demo-count-line-${i + 1}',
          itemId: rows[i].itemId,
          variantId: rows[i].variantId,
          lotId: rows[i].lotId,
          locationId: rows[i].locationId,
          state: CountLineState.pending,
        ),
    ];
    for (final l in _lines[taskId]!) {
      _taskOfLine[l.lineId] = taskId;
    }
    // what the earlier counts said: the beans were counted three times, twice exactly
    if (rows.any((r) => r.itemId == 'demo-item-beans')) {
      final r = rows.firstWhere((x) => x.itemId == 'demo-item-beans');
      _history['${r.itemId}|${r.locationId}'] = (at: now.subtract(const Duration(days: 23)), counts: 3, exact: 2);
    }
  }

  @override
  Future<List<CountPlan>> plans(String workspaceId) async {
    if (!_mine(workspaceId)) return const [];
    await _seed();
    return _plans.values.toList();
  }

  @override
  Future<void> savePlan(String workspaceId, CountPlanDraft d) async {
    if (!_mine(workspaceId)) throw _refused(DkCode.dkg04, 'not a plan of this business');
    await _seed();
    final name = d.name.trim();
    if (name.isEmpty || name.length > 80 || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d.nextDueOn)) {
      throw _refused(DkCode.dkg07, 'a plan has a name, a scope (places, items or high value) and a due day');
    }
    if ((d.intervalDays != null && (d.intervalDays! < 1 || d.intervalDays! > 366)) || (d.highValueMinor != null && d.highValueMinor! < 1)) {
      throw _refused(DkCode.dkg07, 'a plan repeats every 1 to 366 days, or once');
    }
    if ((d.scope == CountScope.places && d.locationIds.isEmpty) || (d.scope == CountScope.items && d.itemIds.isEmpty)) {
      throw _refused(DkCode.dkg07, 'the scope names what to count (at most 200)');
    }
    _plans[d.planId] = CountPlan(
      id: d.planId,
      name: name,
      scope: d.scope,
      locationIds: d.locationIds,
      itemIds: d.itemIds,
      highValueMinor: d.highValueMinor,
      intervalDays: d.intervalDays,
      nextDueOn: d.nextDueOn,
      active: d.active,
    );
  }

  @override
  Future<List<CountTaskSummary>> tasks(String workspaceId, {CountTaskState? state}) async {
    if (!_mine(workspaceId)) return const [];
    await _seed();
    return [
      for (final t in _tasks.reversed)
        if (state == null || _state[t.taskId] == state)
          CountTaskSummary(
            taskId: t.taskId,
            planId: t.planId,
            planName: t.planName,
            dueOn: t.dueOn,
            state: _state[t.taskId]!,
            lines: _lines[t.taskId]!.length,
            pending: _lines[t.taskId]!.where((l) => l.state == CountLineState.pending).length,
          ),
    ];
  }

  @override
  Future<CountTask> task(String workspaceId, String taskId) async {
    if (!_mine(workspaceId)) throw _refused(DkCode.dkg04, 'not a task of this business');
    await _seed();
    final t = _tasks.where((x) => x.taskId == taskId).firstOrNull;
    if (t == null) throw _refused(DkCode.dkg04, 'not a task of this business');
    return CountTask(taskId: taskId, dueOn: t.dueOn, state: _state[taskId]!, lines: List.unmodifiable(_lines[taskId]!));
  }

  CountLineResult _close(String taskId, String lineId, {String? state, ExactQuantity? observed, ExactQuantity? baseline}) {
    if (_lines[taskId]!.every((l) => l.state != CountLineState.pending)) _state[taskId] = CountTaskState.complete;
    return CountLineResult(
      lineId: lineId,
      taskState: _state[taskId]!,
      state: state,
      observed: observed,
      baseline: baseline,
      difference: observed == null || baseline == null ? null : observed - baseline,
    );
  }

  void _setLine(String taskId, String lineId, CountLineState state, {String? reason}) {
    final lines = _lines[taskId]!;
    final i = lines.indexWhere((l) => l.lineId == lineId);
    final l = lines[i];
    lines[i] = CountTaskLine(
      lineId: l.lineId,
      itemId: l.itemId,
      variantId: l.variantId,
      lotId: l.lotId,
      locationId: l.locationId,
      state: state,
      skipReason: reason,
    );
  }

  @override
  Future<CountLineResult> countLine(String workspaceId, String lineId, String observed, String requestId) async {
    if (_answers[requestId] case final done?) return done;
    if (!_mine(workspaceId)) throw _refused(DkCode.dkg04, 'not a line of this business');
    await _seed();
    final taskId = _taskOfLine[lineId];
    if (taskId == null) throw _refused(DkCode.dkg04, 'not a line of this business');
    if (_state[taskId] != CountTaskState.open) throw _refused(DkCode.dkg19, 'this task is no longer open');
    final line = _lines[taskId]!.firstWhere((l) => l.lineId == lineId);
    if (line.state == CountLineState.skipped) throw _refused(DkCode.dkg19, 'this line was skipped');
    if (!_quantity.hasMatch(observed.trim())) throw _refused(DkCode.dkg07, 'a count has a quantity');
    final seen = ExactQuantity.parse(observed.trim());
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
    _setLine(taskId, lineId, CountLineState.counted);
    final key = '${line.itemId}|${line.locationId}';
    final before = _history[key];
    _history[key] = (at: _now(), counts: (before?.counts ?? 0) + 1, exact: (before?.exact ?? 0) + (seen == baseline ? 1 : 0));
    final held = _held();
    final sees = held.contains(WorkspacePermission.manageStock) || held.contains(WorkspacePermission.approveStockAdjustments);
    return _answers[requestId] = _close(taskId, lineId, state: 'recorded', observed: sees ? seen : null, baseline: sees ? baseline : null);
  }

  @override
  Future<CountLineResult> skipLine(String workspaceId, String lineId, String reason, String requestId) async {
    if (_answers[requestId] case final done?) return done;
    final why = reason.trim();
    if (why.isEmpty || why.length > 300) throw _refused(DkCode.dkg07, 'a line is skipped with a reason of 1 to 300 characters');
    if (!_mine(workspaceId)) throw _refused(DkCode.dkg04, 'not a line of this business');
    await _seed();
    final taskId = _taskOfLine[lineId];
    if (taskId == null) throw _refused(DkCode.dkg04, 'not a line of this business');
    final line = _lines[taskId]!.firstWhere((l) => l.lineId == lineId);
    if (line.state == CountLineState.counted) throw _refused(DkCode.dkg19, 'this line was counted');
    if (_state[taskId] != CountTaskState.open) throw _refused(DkCode.dkg19, 'this task is no longer open');
    _setLine(taskId, lineId, CountLineState.skipped, reason: why);
    return _answers[requestId] = _close(taskId, lineId, state: 'skipped');
  }

  @override
  Future<List<CountHistoryRow>> history(String workspaceId) async {
    if (!_mine(workspaceId)) return const [];
    await _seed();
    return [
      for (final e in _history.entries)
        CountHistoryRow(
          itemId: e.key.split('|').first,
          locationId: e.key.split('|').last,
          lastCountedAt: e.value.at,
          counts: e.value.counts,
          exact: e.value.exact,
        ),
    ];
  }

  final Map<String, BulkCountResult> _bulk = {};

  @override
  Future<BulkCountResult> countByTagRead(String workspaceId, {required String requestId, required String taskId, required List<String> codes}) async {
    if (_bulk[requestId] case final done?) {
      return BulkCountResult(taskState: done.taskState, lines: done.lines, leftOut: done.leftOut, missing: done.missing, replayed: true);
    }
    if (!_mine(workspaceId) || !_lines.containsKey(taskId)) {
      if (_mine(workspaceId)) await _seed();
      if (!_mine(workspaceId) || !_lines.containsKey(taskId)) throw _refused(DkCode.dkg04, 'not a task of this business');
    }
    if (_state[taskId] != CountTaskState.open) throw _refused(DkCode.dkg19, 'this task is no longer open');
    final held = _held();
    final sees = held.contains(WorkspacePermission.manageStock) || held.contains(WorkspacePermission.approveStockAdjustments);
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
    for (final line in [..._lines[taskId]!]) {
      final n = byItem[line.itemId];
      if (line.state != CountLineState.pending || n == null) continue;
      await countLine(workspaceId, line.lineId, '$n', 'bulk-$requestId-${line.lineId}');
      counted.add(BulkCountedLine(lineId: line.lineId, itemId: line.itemId, locationId: line.locationId, read: n, state: 'counted'));
    }
    return _bulk[requestId] = BulkCountResult(
      taskState: _state[taskId]!,
      lines: counted,
      leftOut: left,
      missing: sees ? const [] : null,
      replayed: false,
    );
  }
}
