// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';

/// #2575 — what a lease still expects, and the bills that replaced it
/// (`purchase_commitment_page_v1`, 0479). An occurrence of a lease is an
/// EXPECTED obligation; a bill line allocated to it replaces the expectation
/// without adding a second cost.

enum CommitmentState { expected, partial, matched }

/// One allocation of a bill line to an occurrence.
class CommitmentMatch {
  const CommitmentMatch({
    required this.id,
    required this.purchaseId,
    required this.lineNo,
    required this.allocatedCents,
    this.reference = '',
    this.lineGrossCents = 0,
    this.lineUnallocatedCents = 0,
    this.reversed = false,
  });

  factory CommitmentMatch.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'commitment match');
    return CommitmentMatch(
      id: r.string('id'),
      purchaseId: r.string('purchase_id'),
      lineNo: r.integer('line_no'),
      allocatedCents: r.integer('allocated_cents'),
      reference: r.stringOr('reference'),
      lineGrossCents: r.intOrNull('line_gross_cents') ?? 0,
      lineUnallocatedCents: r.intOrNull('line_unallocated_cents') ?? 0,
      reversed: r.boolOr('reversed', fallback: false),
    );
  }

  final String id;
  final String purchaseId;
  final int lineNo;
  final int allocatedCents;
  final String reference;

  /// The line's own total, and what of it no occurrence has taken: a bill
  /// above the expectation leaves its variance here.
  final int lineGrossCents;
  final int lineUnallocatedCents;
  final bool reversed;
}

class CommitmentOccurrence {
  const CommitmentOccurrence({
    required this.id,
    required this.dueOn,
    required this.expectedCents,
    required this.matchedCents,
    this.termLabel = '',
    this.matches = const [],
  });

  factory CommitmentOccurrence.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'commitment occurrence');
    return CommitmentOccurrence(
      id: r.string('id'),
      dueOn: DateTime.parse(r.string('due_on')),
      expectedCents: r.integer('expected_cents'),
      matchedCents: r.integer('matched_cents'),
      termLabel: r.stringOr('term_label'),
      matches: [for (final m in r.list('matches')) CommitmentMatch.fromJson(m)],
    );
  }

  final String id;
  final DateTime dueOn;
  final int expectedCents;
  final int matchedCents;
  final String termLabel;
  final List<CommitmentMatch> matches;

  int get remainingCents => expectedCents - matchedCents;

  CommitmentState get state => matchedCents <= 0
      ? CommitmentState.expected
      : matchedCents >= expectedCents
      ? CommitmentState.matched
      : CommitmentState.partial;
}

class CommitmentPage {
  const CommitmentPage({required this.occurrences, this.nextBefore});

  factory CommitmentPage.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'commitment page');
    return CommitmentPage(
      occurrences: [
        for (final o in r.list('occurrences')) CommitmentOccurrence.fromJson(o),
      ],
      nextBefore: DateTime.tryParse(r.stringOr('next_before')),
    );
  }

  final List<CommitmentOccurrence> occurrences;

  /// Pass it back to read the older occurrences; null when there are none.
  final DateTime? nextBefore;
}

/// One bill line allocated to one occurrence.
class CommitmentAllocation {
  const CommitmentAllocation({
    required this.occurrenceId,
    required this.lineNo,
    required this.cents,
  });

  final String occurrenceId;

  /// The line of the bill, by its number.
  final int lineNo;
  final int cents;
}

class CommitmentMatchCommand {
  const CommitmentMatchCommand({
    required this.purchaseId,
    required this.revision,
    required this.allocations,
    required this.requestId,
  });

  final String purchaseId;
  final int revision;
  final List<CommitmentAllocation> allocations;
  final String requestId;
}

abstract interface class LeaseCommitmentRepository {
  Future<CommitmentPage> fetchCommitments(
    String workspaceId,
    String leaseId, {
    DateTime? before,
  });

  Future<void> matchCommitments(
    String workspaceId,
    CommitmentMatchCommand command,
  );

  Future<void> reverseMatch(
    String workspaceId, {
    required String matchId,
    required String reason,
    required String requestId,
  });
}
