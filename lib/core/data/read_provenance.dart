// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2587 — what a read can honestly claim about its completeness.
//
// A traversal by offset (`fetchPages`) reads a series of independent
// requests. Row-count and unique-id agreement can DETECT some instability
// but never prove a snapshot: with ids [1..6], a first page [1,2,3], then
// delete 1 / insert 7, the second page at offset 3 of [2..7] is [5,6,7];
// the assembly [1,2,3,5,6,7] has six unique ids and the closing count 6,
// yet omits 4 and holds the deleted 1. Even an unchanged id set can mix
// values of different versions. So a traversal is [boundedTraversal] and
// only ONE server response produced under one statement snapshot may be
// [snapshot].
library;

/// How complete a read is, in the order of what it can prove.
enum ReadCompleteness {
  /// One bounded server response produced under one statement snapshot.
  snapshot,

  /// Every page was read to the end within a bound, in a total order. Fit
  /// for ordinary lists and display; NOT evidence of an exact export.
  boundedTraversal,

  /// The read stopped short or could not be shown stable.
  incomplete,
}

/// Where a result came from and what it may be used for.
class ReadProvenance {
  const ReadProvenance._({
    required this.completeness,
    required this.reason,
    required this.target,
    required this.principal,
    required this.queryFingerprint,
    required this.sourceRevision,
  });

  /// A traversal: never a snapshot, whatever the closing count said.
  const ReadProvenance.traversal({
    required String reason,
    String target = '',
    String principal = '',
    String queryFingerprint = '',
  }) : this._(
          completeness: ReadCompleteness.boundedTraversal,
          reason: reason,
          target: target,
          principal: principal,
          queryFingerprint: queryFingerprint,
          sourceRevision: '',
        );

  /// A read that stopped short or could not be shown stable.
  const ReadProvenance.incomplete({
    required String reason,
    String target = '',
    String principal = '',
    String queryFingerprint = '',
  }) : this._(
          completeness: ReadCompleteness.incomplete,
          reason: reason,
          target: target,
          principal: principal,
          queryFingerprint: queryFingerprint,
          sourceRevision: '',
        );

  /// One server response under one statement snapshot; the server's own
  /// [sourceRevision] (its cutoff / computed_at) is what makes it one.
  factory ReadProvenance.snapshot({
    required String sourceRevision,
    required String target,
    required String principal,
    required String queryFingerprint,
    String reason = 'one server statement snapshot',
  }) {
    if (sourceRevision.isEmpty) {
      throw ArgumentError('a snapshot names the revision it was read at');
    }
    return ReadProvenance._(
      completeness: ReadCompleteness.snapshot,
      reason: reason,
      target: target,
      principal: principal,
      queryFingerprint: queryFingerprint,
      sourceRevision: sourceRevision,
    );
  }

  final ReadCompleteness completeness;
  final String reason;

  /// The workspace / issuer the rows belong to.
  final String target;

  /// The principal and authorisation epoch the read ran under.
  final String principal;

  /// Query and cutoff, so W-A and W-B are never "the same" by local ids.
  final String queryFingerprint;

  /// The server's revision/cutoff of a snapshot; empty otherwise.
  final String sourceRevision;

  bool get isSnapshot => completeness == ReadCompleteness.snapshot;
}

/// Rows with the provenance they may be relied on at.
class ProvenancedRows<T> {
  const ProvenancedRows(this.rows, this.provenance);
  final List<T> rows;
  final ReadProvenance provenance;
}
