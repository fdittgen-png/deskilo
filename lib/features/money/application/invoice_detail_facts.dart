// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what an invoice's detail sheet says beyond the figures: which
// notes the issuer sees, who the document is billed to, and which trail
// sections apply. The sheet maps over these values; it decides nothing.
import '../domain/billing_rules.dart';
import '../domain/invoice.dart';

class InvoiceDetailFacts {
  const InvoiceDetailFacts({
    required this.billedTo,
    required this.client,
    required this.showKindRow,
    required this.heldReason,
    required this.showMaturityReview,
    required this.showSettlementTrail,
    required this.showFolded,
    required this.standingMatch,
  });

  /// [heldReason] is the active dunning hold's reason code (#1913), or
  /// null; it only reaches an issuer.
  factory InvoiceDetailFacts.of(
    Invoice invoice,
    InvoiceMatch? match, {
    required bool canIssue,
    required bool showMemberName,
    String? heldReason,
  }) => InvoiceDetailFacts(
    // #910 — "Billed to: , SASU KaloA, …": the name was empty and its
    // comma stayed behind. Build the parts, then join.
    billedTo: [
      invoice.clientName,
      ...invoice.memberAddress.split('\n'),
    ].map((p) => p.trim()).where((p) => p.isNotEmpty).join(', '),
    client: showMemberName && invoice.clientName.isNotEmpty
        ? invoice.clientName
        : null,
    showKindRow: invoice.kind != InvoiceKind.full,
    heldReason: canIssue ? heldReason : null,
    // A due date nobody agreed to, said where the issuer decides.
    showMaturityReview:
        canIssue &&
        invoice.maturityBasis != null &&
        invoice.maturityBasis != 'document_term',
    showSettlementTrail: invoice.settles.isNotEmpty,
    showFolded: invoice.settledByInvoiceId != null,
    standingMatch: match != null && !match.pending ? match : null,
  );

  /// The client and the address lines, empty parts left out.
  final String billedTo;

  /// The client named beside the period, or null.
  final String? client;

  /// #802/#804 — a document that is not a plain invoice says what it is.
  final bool showKindRow;

  /// Why reminders stop (#1913), for an issuer; null otherwise.
  final String? heldReason;
  final bool showMaturityReview;

  /// #804 — a settlement names every invoice inside it.
  final bool showSettlementTrail;

  /// #804 — a settled invoice names the document carrying its balance.
  final bool showFolded;

  /// The match that stands (not waiting for validation), or null.
  final InvoiceMatch? standingMatch;
}
