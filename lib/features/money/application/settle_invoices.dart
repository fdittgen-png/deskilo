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
import '../domain/billing_rules.dart';
import '../domain/invoice.dart';
import '../domain/money_repository.dart';

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

/// Regrouping, as the decision behind it.
class Settlements {
  const Settlements(this._money);

  final MoneyRepository _money;

  /// Settles [invoiceIds] into one document and returns the NUMBER a
  /// person is shown.
  ///
  /// Falls back to the id when the fresh list does not carry the new
  /// document — the person still gets something they can quote, rather
  /// than a sentence with a hole in it.
  Future<String> settle({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
  }) async {
    final id = await _money.settleInvoices(
      workspaceId: workspaceId,
      memberId: memberId,
      invoiceIds: invoiceIds,
    );
    final fresh = await _money.fetchInvoices(workspaceId);
    return fresh.where((i) => i.id == id).firstOrNull?.number ?? id;
  }
}
