// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 / #1234 — regrouping invoices is a rule about which ones may be
// regrouped, and an answer that has to be looked up afterwards.
//
// **Which ones.** An invoice can join a settlement only if it is still
// open, not voided, not already settled by another document, not itself
// a settlement, and has no payment match waiting on somebody's decision.
// Each of those is a reason, and together they are the difference
// between a regrouping that is honest and one that quietly swallows a
// document somebody is in the middle of. Two is the minimum: regrouping
// one invoice is not regrouping.
//
// **The answer.** The server mints a new document and its NUMBER is what
// the person is told — *"Regrouped into FA-2026-0031."* The sheet
// discovered it by re-reading every invoice of the workspace and looking
// for the id it had just been handed, falling back to the id when the
// number was not there.
//
// Both lived in a widget. The eligibility rule is pure and now testable
// as such; the write and its look-up are a class behind a provider, so
// the sheet resolves no repository.
import '../../../core/trace/trace_logger.dart';
import '../domain/billing_rules.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice.dart';
import '../domain/invoice_action_commands.dart';
import '../domain/invoice_queries.dart';
import 'command_failure.dart';

/// The invoices of [memberId] that may be regrouped, from the open list.
///
/// Pure: it takes what the overview already computed rather than asking
/// for it, so the rule can be argued with in a unit test.
List<Invoice> settlementCandidates(
  Iterable<({Invoice invoice, dynamic pendingMatch})> open,
  String memberId,
) =>
    [
      for (final entry in open)
        if (entry.invoice.memberId == memberId &&
            !entry.invoice.isVoided &&
            entry.invoice.settledByInvoiceId == null &&
            entry.invoice.kind != InvoiceKind.settlement &&
            entry.pendingMatch == null)
          entry.invoice,
    ];

/// Whether [chosen] is a regrouping at all.
///
/// Its own name because "at least two" is a rule and not an off-by-one:
/// a settlement of one invoice is that invoice, with a second number
/// pointing at it.
bool isRegrouping(List<Invoice> chosen) => chosen.length >= 2;

/// What the person confirmed: the member, the invoices to regroup and the
/// attempt's own request id (#2585 C2). Immutable, so a look can only ever
/// concern this regrouping.
final class SettleAttempt {
  const SettleAttempt({
    required this.workspaceId,
    required this.memberId,
    required this.invoiceIds,
    required this.requestId,
  });

  final String workspaceId;
  final String memberId;
  final List<String> invoiceIds;
  final String requestId;
}

sealed class SettleOutcome {
  const SettleOutcome(this.attempt);
  final SettleAttempt attempt;
}

/// The regrouping exists; [number] is what the person is shown.
final class Settled extends SettleOutcome {
  const Settled(super.attempt, this.number);
  final String number;
}

/// The server said no, in words: nothing was regrouped.
final class SettleRefused extends SettleOutcome {
  const SettleRefused(super.attempt, this.error);
  final Object error;
}

/// The answer did not come back usable; whether it applied is not known.
final class SettleUnknown extends SettleOutcome {
  const SettleUnknown(super.attempt, this.cause);
  final Object cause;
}

/// Regrouping, as the decision behind it.
class Settlements {
  const Settlements(this._commands, this._invoices);

  final InvoiceActionCommands _commands;
  final InvoiceQueries _invoices;

  /// Settles [SettleAttempt.invoiceIds] into one document, ONCE, and answers
  /// the NUMBER a person is shown (the id when the fresh list does not carry
  /// the new document — they still get something they can quote). A lost or
  /// undecodable answer is [SettleUnknown], never a reason to send again.
  Future<SettleOutcome> settle(SettleAttempt attempt) async {
    try {
      final id = await _commands.settleInvoicesOnce(
        workspaceId: attempt.workspaceId,
        memberId: attempt.memberId,
        invoiceIds: attempt.invoiceIds,
        requestId: attempt.requestId,
      );
      return Settled(attempt, await _numberOf(attempt.workspaceId, id));
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'settle invoices failed', error: e, stackTrace: st);
      return isDefiniteRefusal(e) ? SettleRefused(attempt, e) : SettleUnknown(attempt, e);
    }
  }

  /// Reads THAT request's receipt on the attempt's own workspace.
  Future<SettleOutcome> look(SettleUnknown unknown) async {
    final attempt = unknown.attempt;
    try {
      final receipt = await _invoices.invoiceCommandOutcome(
        workspaceId: attempt.workspaceId,
        requestId: attempt.requestId,
      );
      return switch (receipt.state) {
        CommandReceiptState.applied =>
          Settled(attempt, await _numberOf(attempt.workspaceId, receipt.invoiceId!)),
        _ => unknown,
      };
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'settlement receipt unreadable', error: e, stackTrace: st);
      return SettleUnknown(attempt, e);
    }
  }

  Future<String> _numberOf(String workspaceId, String id) async {
    final fresh = await _invoices.fetchInvoices(workspaceId);
    return fresh.where((i) => i.id == id).firstOrNull?.number ?? id;
  }
}
