// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3615 — approving several purchases from a selection, as the decision on
// #3615 settles it: each item is decided on its own. The selection is a
// snapshot of what the person saw (the document, its amount, its currency,
// its reference); each is read again and decided through the existing
// approval command with its own request identity, kept across an uncertain
// retry; the result is said per item. The approval rules and the separation
// of duties are those of the single flow: the server's `canApprove` and
// its revision check. There is no all-or-nothing bulk command.
import '../../../core/trace/trace_logger.dart';
import '../domain/purchase.dart';
import '../domain/purchase_approval_reads.dart';
import 'purchase_commands.dart';

/// What became of one item of a selection.
enum ApprovalOutcome {
  /// Approved.
  applied,

  /// The person may not approve it (their own, not pending, not theirs to
  /// decide): nothing was sent.
  refused,

  /// It changed since it was shown: nothing was sent; it is shown again.
  changed,

  /// The read or the decision did not answer: it may or may not have been
  /// decided. A retry sends the same request again, which never decides
  /// twice.
  unknown,
}

/// One document as the person saw it when they selected it.
typedef ApprovalItem = ({
  String id,
  int grossCents,
  String currency,
  String reference,
});

/// A selection of approvals, decided item by item.
class PurchaseBatchApproval {
  PurchaseBatchApproval({
    required this.workspaceId,
    required this.reads,
    required this.commands,
    required this.newRequestId,
  });

  final String workspaceId;
  final PurchaseApprovalReads reads;
  final PurchaseCommands commands;
  final String Function() newRequestId;

  /// Each item's request identity, the same on every retry of it.
  final Map<String, String> _requests = {};

  /// What became of each item so far.
  final Map<String, ApprovalOutcome> outcomes = {};

  /// Decides [items] one after the other; an item already applied is not
  /// sent again.
  Future<Map<String, ApprovalOutcome>> run(List<ApprovalItem> items) async {
    for (final item in items) {
      if (outcomes[item.id] == ApprovalOutcome.applied) continue;
      outcomes[item.id] = await _one(item);
    }
    return Map.unmodifiable(outcomes);
  }

  /// The items whose outcome is not known: what a retry sends again.
  List<ApprovalItem> uncertain(List<ApprovalItem> items) => [
    for (final i in items)
      if (outcomes[i.id] == ApprovalOutcome.unknown) i,
  ];

  Future<ApprovalOutcome> _one(ApprovalItem item) async {
    final PurchaseApprovalDetail current;
    try {
      current = await reads.detail(workspaceId, item.id);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'an approval of a selection was not read; its outcome is unknown',
        error: e,
        stackTrace: st,
      );
      return ApprovalOutcome.unknown;
    }
    final summary = current.detail.summary;
    // Sent before without an answer: the decision may have been taken then.
    // Approved now is what the person asked for; anything else is not.
    if (_requests.containsKey(item.id) &&
        summary.state != PurchaseState.pending) {
      return summary.state == PurchaseState.approved
          ? ApprovalOutcome.applied
          : ApprovalOutcome.refused;
    }
    if (summary.grossCents != item.grossCents ||
        summary.currency != item.currency ||
        summary.reference != item.reference) {
      return ApprovalOutcome.changed;
    }
    if (!current.canApprove || summary.state != PurchaseState.pending) {
      return ApprovalOutcome.refused;
    }
    final requestId = _requests[item.id] ??= newRequestId();
    try {
      final state = await commands.decide(
        workspaceId,
        current.detail,
        approve: true,
        reason: '',
        requestId: requestId,
      );
      return state == null ? ApprovalOutcome.refused : ApprovalOutcome.applied;
    } on Object catch (e, st) {
      // The same request identity goes on a retry: never decided twice.
      TraceLogger.instance.warn(
        'money',
        'an approval of a selection did not answer; its outcome is unknown',
        error: e,
        stackTrace: st,
      );
      return ApprovalOutcome.unknown;
    }
  }
}
