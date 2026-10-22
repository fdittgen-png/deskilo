// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/lease_commitment.dart';

/// #2575 — the lease's expected obligations in memory, with the server's
/// arithmetic the screen shows: an allocation is at most what the occurrence
/// still expects, a reversal restores it, the same request answers the same.
class FakeLeaseCommitmentRepository implements LeaseCommitmentRepository {
  FakeLeaseCommitmentRepository([
    Map<String, List<CommitmentOccurrence>> byLease = const {},
  ]) : _byLease = {for (final e in byLease.entries) e.key: [...e.value]};

  final Map<String, List<CommitmentOccurrence>> _byLease;
  final Set<String> _requests = {};
  var _next = 1;

  @override
  Future<CommitmentPage> fetchCommitments(
    String workspaceId,
    String leaseId, {
    DateTime? before,
  }) async => CommitmentPage(
    occurrences: [
      for (final o in _byLease[leaseId] ?? const <CommitmentOccurrence>[])
        if (before == null || o.dueOn.isBefore(before)) o,
    ],
  );

  @override
  Future<void> matchCommitments(
    String workspaceId,
    CommitmentMatchCommand command,
  ) async {
    if (!_requests.add(command.requestId)) return;
    for (final a in command.allocations) {
      final lease = _byLease.entries.firstWhere(
        (e) => e.value.any((o) => o.id == a.occurrenceId),
        orElse: () => throw StateError('unknown occurrence'),
      );
      final i = lease.value.indexWhere((o) => o.id == a.occurrenceId);
      final o = lease.value[i];
      if (a.cents > o.remainingCents) {
        throw StateError('the amount exceeds what the occurrence still expects');
      }
      lease.value[i] = _with(
        o,
        matched: o.matchedCents + a.cents,
        matches: [
          ...o.matches,
          CommitmentMatch(
            id: 'demo-match-${_next++}',
            purchaseId: command.purchaseId,
            lineNo: a.lineNo,
            allocatedCents: a.cents,
            reference: command.purchaseId,
          ),
        ],
      );
    }
  }

  @override
  Future<void> reverseMatch(
    String workspaceId, {
    required String matchId,
    required String reason,
    required String requestId,
  }) async {
    if (!_requests.add(requestId)) return;
    for (final lease in _byLease.values) {
      for (var i = 0; i < lease.length; i++) {
        final o = lease[i];
        final m = o.matches.where((x) => x.id == matchId && !x.reversed);
        if (m.isEmpty) continue;
        lease[i] = _with(
          o,
          matched: o.matchedCents - m.first.allocatedCents,
          matches: [
            for (final x in o.matches)
              if (x.id == matchId)
                CommitmentMatch(
                  id: x.id,
                  purchaseId: x.purchaseId,
                  lineNo: x.lineNo,
                  allocatedCents: x.allocatedCents,
                  reference: x.reference,
                  reversed: true,
                )
              else
                x,
          ],
        );
        return;
      }
    }
    throw StateError('unknown or already reversed match');
  }

  @override
  Future<String?> acceptVariance(
    String workspaceId, {
    required String occurrenceId,
    required CommitmentMatch match,
    required String reason,
    required String requestId,
  }) async {
    if (!_requests.add(requestId)) return null;
    for (final lease in _byLease.values) {
      final i = lease.indexWhere((o) => o.id == occurrenceId);
      if (i < 0) continue;
      final o = lease[i];
      if (o.remainingCents > 0) {
        throw StateError('match the occurrence in full before accepting a difference');
      }
      lease[i] = _with(
        o,
        matched: o.matchedCents + match.lineUnallocatedCents,
        matches: [
          for (final x in o.matches)
            if (x.id == match.id)
              CommitmentMatch(
                id: x.id,
                purchaseId: x.purchaseId,
                lineNo: x.lineNo,
                allocatedCents: x.allocatedCents,
                reference: x.reference,
                lineGrossCents: x.lineGrossCents,
              )
            else
              x,
          CommitmentMatch(
            id: 'demo-variance-${_next++}',
            purchaseId: match.purchaseId,
            lineNo: match.lineNo,
            allocatedCents: match.lineUnallocatedCents,
            reference: match.reference,
            isVariance: true,
            reason: reason,
          ),
        ],
      );
      return null;
    }
    throw StateError('unknown occurrence');
  }

  static CommitmentOccurrence _with(
    CommitmentOccurrence o, {
    required int matched,
    required List<CommitmentMatch> matches,
  }) => CommitmentOccurrence(
    id: o.id,
    dueOn: o.dueOn,
    expectedCents: o.expectedCents,
    matchedCents: matched,
    termLabel: o.termLabel,
    matches: matches,
  );
}
