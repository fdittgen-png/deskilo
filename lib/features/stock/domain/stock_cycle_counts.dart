// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 (G9, client) -- scheduled cycle counts while the shop stays open. A PLAN names a scope (places
// with the places inside them, items, or the high-value goods) and a schedule (every n days from a
// day, or once); when it is due it makes ONE TASK listing the lines to count (item, variant, lot,
// place) WITHOUT the quantities the ledger expects: the counter counts blind. Counting a line records
// a count of #4172 (its stock revision, its approval and its adjustment are that leaf's); skipping
// needs a reason; a task is complete when every line is counted or skipped. The history says per item
// and place when it was last counted and how many counts were exact. Nothing here changes a balance.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What a plan counts.
enum CountScope {
  /// These places and every place inside them.
  places('places'),

  /// These items, in every real place.
  items('items'),

  /// What a place holds of an item that is worth at least a threshold.
  highValue('high_value'),

  /// A scope a newer server sent and this app does not know: the plan is listed and not edited on a guess.
  unknown('');

  const CountScope(this.wire);

  final String wire;

  static CountScope fromWire(String? wire) => values.firstWhere((s) => s != unknown && s.wire == wire, orElse: () => unknown);
}

/// A plan: a scope and a schedule.
class CountPlan {
  const CountPlan({
    required this.id,
    required this.name,
    required this.scope,
    required this.locationIds,
    required this.itemIds,
    required this.nextDueOn,
    required this.active,
    this.highValueMinor,
    this.intervalDays,
  });

  final String id;
  final String name;
  final CountScope scope;
  final List<String> locationIds;
  final List<String> itemIds;

  /// The plan's own threshold, in minor units; null: the business's setting.
  final int? highValueMinor;

  /// Repeats every this many days; null: once.
  final int? intervalDays;

  /// The business's day the plan is next due, `YYYY-MM-DD`.
  final String nextDueOn;
  final bool active;

  factory CountPlan.fromRow(Object? json) {
    final r = JsonReader.of(json, context: 'stock_count_plans');
    return CountPlan(
      id: r.string('id'),
      name: r.stringOr('name'),
      scope: CountScope.fromWire(r.stringOrNull('scope_kind')),
      locationIds: r.strings('location_ids'),
      itemIds: r.strings('item_ids'),
      highValueMinor: r.intOrNull('high_value_minor'),
      intervalDays: r.intOrNull('interval_days'),
      nextDueOn: r.string('next_due_on'),
      active: r.boolOr('active', fallback: true),
    );
  }
}

/// What a plan is saved as: the plan's own id (the same id saves the same plan again) and a request id.
typedef CountPlanDraft = ({
  String planId,
  String requestId,
  String name,
  CountScope scope,
  List<String> locationIds,
  List<String> itemIds,
  String nextDueOn,
  bool active,
  int? highValueMinor,
  int? intervalDays,
});

/// Where a task stands.
enum CountTaskState {
  open,
  complete,
  cancelled,
  /// A value a newer server sent and this app does not know: shown as not known, and nothing is done on a guess.
  unknown;

  static CountTaskState fromWire(String? wire) => values.firstWhere((s) => s != unknown && s.name == wire, orElse: () => unknown);
}

/// One task in the list: how many lines, how many still to count.
class CountTaskSummary {
  const CountTaskSummary({
    required this.taskId,
    required this.planId,
    required this.planName,
    required this.dueOn,
    required this.state,
    required this.lines,
    required this.pending,
  });

  final String taskId;
  final String planId;
  final String planName;
  final String dueOn;
  final CountTaskState state;
  final int lines;
  final int pending;

  factory CountTaskSummary.fromJson(JsonReader r) => CountTaskSummary(
    taskId: r.string('task_id'),
    planId: r.string('plan_id'),
    planName: r.stringOr('plan_name'),
    dueOn: r.string('due_on'),
    state: CountTaskState.fromWire(r.stringOrNull('state')),
    lines: r.integer('lines'),
    pending: r.integer('pending'),
  );
}

/// Where a line stands.
enum CountLineState {
  pending,
  counted,
  skipped,
  /// A value a newer server sent and this app does not know: shown as not known, and nothing is done on a guess.
  unknown;

  static CountLineState fromWire(String? wire) => values.firstWhere((s) => s != unknown && s.name == wire, orElse: () => unknown);
}

/// One line to count: WHAT and WHERE, never what the ledger expects.
class CountTaskLine {
  const CountTaskLine({
    required this.lineId,
    required this.itemId,
    required this.locationId,
    required this.state,
    this.variantId,
    this.lotId,
    this.skipReason,
  });

  final String lineId;
  final String itemId;
  final String? variantId;
  final String? lotId;
  final String locationId;
  final CountLineState state;
  final String? skipReason;

  factory CountTaskLine.fromJson(JsonReader r) => CountTaskLine(
    lineId: r.string('line_id'),
    itemId: r.string('item_id'),
    variantId: r.stringOrNull('variant_id'),
    lotId: r.stringOrNull('lot_id'),
    locationId: r.string('location_id'),
    state: CountLineState.fromWire(r.stringOrNull('state')),
    skipReason: r.stringOrNull('skip_reason'),
  );
}

/// A task with its lines.
class CountTask {
  const CountTask({required this.taskId, required this.dueOn, required this.state, required this.lines});

  final String taskId;
  final String dueOn;
  final CountTaskState state;
  final List<CountTaskLine> lines;

  factory CountTask.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_count_task_v1');
    return CountTask(
      taskId: r.string('task_id'),
      dueOn: r.string('due_on'),
      state: CountTaskState.fromWire(r.stringOrNull('state')),
      lines: r.objects('lines', CountTaskLine.fromJson),
    );
  }
}

/// What counting or skipping a line answered. [observed], [baseline] and [difference] are present only for
/// someone who manages the stock or may approve adjustments; a blind counter is told the line is counted,
/// never what the ledger held or how far off the count was.
class CountLineResult {
  const CountLineResult({required this.lineId, required this.taskState, this.state, this.observed, this.baseline, this.difference});

  final String lineId;
  final CountTaskState taskState;
  final String? state;
  final ExactQuantity? observed;
  final ExactQuantity? baseline;
  final ExactQuantity? difference;

  factory CountLineResult.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_cycle_count_line_v1');
    ExactQuantity? q(String key) {
      final t = r.stringOrNull(key);
      return t == null ? null : ExactQuantity.parse(t);
    }

    return CountLineResult(
      lineId: r.string('line_id'),
      taskState: CountTaskState.fromWire(r.stringOrNull('task_state')),
      state: r.stringOrNull('state'),
      observed: q('observed'),
      baseline: q('baseline'),
      difference: q('difference'),
    );
  }
}

/// When an item at a place was last counted and how many counts were exact.
class CountHistoryRow {
  const CountHistoryRow({required this.itemId, required this.locationId, required this.counts, required this.exact, this.lastCountedAt});

  final String itemId;
  final String locationId;
  final DateTime? lastCountedAt;
  final int counts;
  final int exact;

  /// The share of counts that were exact, 0..100 (null before any count).
  int? get accuracyPercent => counts == 0 ? null : (exact * 100 / counts).round();

  factory CountHistoryRow.fromJson(JsonReader r) => CountHistoryRow(
    itemId: r.string('item_id'),
    locationId: r.string('location_id'),
    lastCountedAt: r.dateTimeOrNull('last_counted_at'),
    counts: r.integer('counts'),
    exact: r.integer('exact'),
  );
}

/// The cycle counts behind one port, so the Demo answers like the server.
/// One line a bulk read counted: how many pieces of its own were read at its place.
class BulkCountedLine {
  const BulkCountedLine({required this.lineId, required this.itemId, required this.locationId, required this.read, required this.state});

  final String lineId;
  final String itemId;
  final String locationId;
  final int read;
  final String state;
}

/// A tag a bulk count left out, and why: `not_a_piece`, `already_counted`, `invalid`, or, for who may see what the ledger
/// holds, `not_in_stock` / `other_place`; a blind counter is told `not_counted`.
class BulkLeftOut {
  const BulkLeftOut({required this.code, required this.reason});

  final String code;
  final String reason;
}

/// #4364 (G15) -- what `stock_count_tag_read_v1` answered. `missing` (the codes of the pieces expected and not read) is
/// null for a blind counter: it is told what it counted, never what was expected.
class BulkCountResult {
  const BulkCountResult({required this.taskState, required this.lines, required this.leftOut, this.missing, required this.replayed});

  final CountTaskState taskState;
  final List<BulkCountedLine> lines;
  final List<BulkLeftOut> leftOut;
  final List<String>? missing;
  final bool replayed;

  factory BulkCountResult.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_count_tag_read_v1');
    final missing = r.raw('missing');
    return BulkCountResult(
      taskState: CountTaskState.fromWire(r.stringOrNull('task_state')),
      lines: [
        for (final l in r.requiredList('lines'))
          () {
            final x = JsonReader.of(l, context: 'stock_count_tag_read_v1.lines');
            return BulkCountedLine(
              lineId: x.string('line_id'),
              itemId: x.string('item_id'),
              locationId: x.string('location_id'),
              read: x.integer('read'),
              state: x.string('state'),
            );
          }(),
      ],
      leftOut: [
        for (final l in r.requiredList('left_out'))
          () {
            final x = JsonReader.of(l, context: 'stock_count_tag_read_v1.left_out');
            return BulkLeftOut(code: x.string('code'), reason: x.string('reason'));
          }(),
      ],
      missing: missing is List
          ? [for (final m in missing) JsonReader.of(m, context: 'stock_count_tag_read_v1.missing').string('code')]
          : null,
      replayed: r.boolOr('replayed', fallback: false),
    );
  }
}

abstract interface class StockCycleCounts {
  /// The plans of the business (read by who manages the stock).
  Future<List<CountPlan>> plans(String workspaceId);

  /// Saves a plan; the same request id answers once.
  Future<void> savePlan(String workspaceId, CountPlanDraft draft);

  /// The tasks, newest due day first, optionally of one state.
  Future<List<CountTaskSummary>> tasks(String workspaceId, {CountTaskState? state});

  /// One task's lines: what to count and where.
  Future<CountTask> task(String workspaceId, String taskId);

  /// Counts a line (blind); one request id answers once.
  Future<CountLineResult> countLine(String workspaceId, String lineId, String observed, String requestId);

  /// Skips a line with a reason.
  Future<CountLineResult> skipLine(String workspaceId, String lineId, String reason, String requestId);

  /// When each item at each place was last counted, and how exact the counts were.
  Future<List<CountHistoryRow>> history(String workspaceId);

  /// #4364 -- fills the lines of a task from a bulk read of tags: a line of a piece-tracked item is counted by the
  /// pieces of its own read at its place; the first read of a line is final. The count waits for its approval, and no
  /// balance moves. One request id answers once.
  Future<BulkCountResult> countByTagRead(String workspaceId, {required String requestId, required String taskId, required List<String> codes});
}
