// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4403 -- the cycle-count tasks of one business and the rules a plan, a counted line and a skipped line meet, in
// the domain beside the stock ledger (stock_ledger.dart), whose counts a counted line records. It does no I/O. The
// server stays the authority: every rule mirrors 0873 at the lines it cites. A refusal is a [StockCodeRefused] with
// the server's code.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/codes/dk_code.dart';
import 'stock_cycle_counts.dart';
import 'stock_ledger.dart';

final _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _quantity = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');

/// The tasks a business's count plans made, their lines, and what earlier counts said of each item at each place.
class CountTaskBook {
  /// The plans, by id.
  final Map<String, CountPlan> plans = {};

  final List<({String taskId, String planId, String planName, String dueOn})> _tasks = [];
  final Map<String, List<CountTaskLine>> _lines = {};
  final Map<String, CountTaskState> _state = {};
  final Map<String, String> _taskOfLine = {};
  final Map<String, ({DateTime at, int counts, int exact})> _history = {};

  /// A plan as the server checks it before it keeps it (0873 stock_count_plan_save_v1:174-243): a name of 1 to 80
  /// characters and a due day, a repeat of 1 to 366 days or none, a threshold above zero, a scope naming what to count.
  static void checkPlan(CountPlanDraft d) {
    final name = d.name.trim();
    if (name.isEmpty || name.length > 80 || !_day.hasMatch(d.nextDueOn)) {
      throw const StockCodeRefused(DkCode.dkg07, 'a plan has a name, a scope (places, items or high value) and a due day');
    }
    if ((d.intervalDays != null && (d.intervalDays! < 1 || d.intervalDays! > 366)) || (d.highValueMinor != null && d.highValueMinor! < 1)) {
      throw const StockCodeRefused(DkCode.dkg07, 'a plan repeats every 1 to 366 days, or once');
    }
    if ((d.scope == CountScope.places && d.locationIds.isEmpty) || (d.scope == CountScope.items && d.itemIds.isEmpty)) {
      throw const StockCodeRefused(DkCode.dkg07, 'the scope names what to count (at most 200)');
    }
  }

  /// A task of [planId] due on [dueOn] with [lines]: open, or complete when it has none.
  void addTask(String taskId, CountPlan plan, String dueOn, List<CountTaskLine> lines) {
    _tasks.add((taskId: taskId, planId: plan.id, planName: plan.name, dueOn: dueOn));
    _state[taskId] = lines.isEmpty ? CountTaskState.complete : CountTaskState.open;
    _lines[taskId] = [...lines];
    for (final l in lines) {
      _taskOfLine[l.lineId] = taskId;
    }
  }

  bool hasTask(String taskId) => _lines.containsKey(taskId);

  /// The tasks, newest first, of [state] when one is named.
  List<CountTaskSummary> summaries({CountTaskState? state}) => [
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

  CountTask task(String taskId) {
    final t = _tasks.where((x) => x.taskId == taskId).firstOrNull;
    if (t == null) throw const StockCodeRefused(DkCode.dkg04, 'not a task of this business');
    return CountTask(taskId: taskId, dueOn: t.dueOn, state: _state[taskId]!, lines: List.unmodifiable(_lines[taskId]!));
  }

  /// The pending lines of [taskId], refused when the task is no longer open (0873:412).
  List<CountTaskLine> openLines(String taskId) {
    if (!hasTask(taskId)) throw const StockCodeRefused(DkCode.dkg04, 'not a task of this business');
    if (_state[taskId] != CountTaskState.open) throw const StockCodeRefused(DkCode.dkg19, 'this task is no longer open');
    return [for (final l in _lines[taskId]!) if (l.state == CountLineState.pending) l];
  }

  ({String taskId, CountTaskLine line}) _line(String lineId) {
    final taskId = _taskOfLine[lineId];
    if (taskId == null) throw const StockCodeRefused(DkCode.dkg04, 'not a line of this business');
    return (taskId: taskId, line: _lines[taskId]!.firstWhere((l) => l.lineId == lineId));
  }

  /// The line [lineId] may be counted as [observed]: a line of an open task (0873:408-412), not skipped
  /// (0873:413), with a quantity as the counts read it (0870:186).
  CountTaskLine lineToCount(String lineId, String observed) {
    final (:taskId, :line) = _line(lineId);
    if (_state[taskId] != CountTaskState.open) throw const StockCodeRefused(DkCode.dkg19, 'this task is no longer open');
    if (line.state == CountLineState.skipped) throw const StockCodeRefused(DkCode.dkg19, 'this line was skipped');
    if (!_quantity.hasMatch(observed)) throw const StockCodeRefused(DkCode.dkg07, 'a count has a quantity');
    return line;
  }

  /// [lineId] counted as [seen] against [baseline] at [at]; a person who may not see the stock ([sees] false) is
  /// told neither (0873:423-427).
  CountLineResult counted(String lineId, ExactQuantity seen, ExactQuantity baseline, {required bool sees, required DateTime at}) {
    final (:taskId, :line) = _line(lineId);
    _set(taskId, lineId, CountLineState.counted);
    final key = '${line.itemId}|${line.locationId}';
    final before = _history[key];
    _history[key] = (at: at, counts: (before?.counts ?? 0) + 1, exact: (before?.exact ?? 0) + (seen == baseline ? 1 : 0));
    return _close(taskId, lineId, state: 'recorded', observed: sees ? seen : null, baseline: sees ? baseline : null);
  }

  /// [lineId] skipped for [reason]: 1 to 300 characters (0873:443-444), a line not counted (0873:451) of an open
  /// task (0873:452-453).
  CountLineResult skip(String lineId, String reason) {
    final why = reason.trim();
    if (why.isEmpty || why.length > 300) throw const StockCodeRefused(DkCode.dkg07, 'a line is skipped with a reason of 1 to 300 characters');
    final (:taskId, :line) = _line(lineId);
    if (line.state == CountLineState.counted) throw const StockCodeRefused(DkCode.dkg19, 'this line was counted');
    if (_state[taskId] != CountTaskState.open) throw const StockCodeRefused(DkCode.dkg19, 'this task is no longer open');
    _set(taskId, lineId, CountLineState.skipped, reason: why);
    return _close(taskId, lineId, state: 'skipped');
  }

  /// What the earlier counts said of [itemId] at [locationId]: when, how often, how often exactly.
  void remember(String itemId, String locationId, ({DateTime at, int counts, int exact}) said) => _history['$itemId|$locationId'] = said;

  List<CountHistoryRow> get history => [
    for (final e in _history.entries)
      CountHistoryRow(
        itemId: e.key.split('|').first,
        locationId: e.key.split('|').last,
        lastCountedAt: e.value.at,
        counts: e.value.counts,
        exact: e.value.exact,
      ),
  ];

  /// The task is complete once no line is pending (0873 stock_count_task_close:382-390).
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

  void _set(String taskId, String lineId, CountLineState state, {String? reason}) {
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

  /// The state of [taskId] now.
  CountTaskState stateOf(String taskId) => _state[taskId]!;
}
