// SPDX-License-Identifier: AGPL-3.0-or-later
// #2379 — Boundary for a future source-book producer. Metadata checks do
// not prove that the producer captured every real accounting entry.
import '../../../core/data/read_provenance.dart';
import 'fiscal_year.dart';
import 'jpk_kr_pd_facts.dart';

/// One source-book entry, with identities supplied by its producer.
class JpkSourceEntry {
  const JpkSourceEntry({
    required this.entryId,
    required this.postingId,
    required this.facts,
  });

  final String entryId;
  final String postingId;
  final JpkEntryFact facts;
}

/// An issuer-scoped source response. [complete] is the producer's assertion,
/// not a completeness proof supplied by this value object.
class JpkSourceBook {
  const JpkSourceBook({
    required this.issuerId,
    required this.period,
    required this.provenance,
    required this.complete,
    required this.entryCount,
    required this.entries,
  });

  final String issuerId;
  final FiscalYear period;
  final ReadProvenance provenance;
  final bool complete;
  final int entryCount;
  final List<JpkSourceEntry> entries;
}

/// Detects inconsistent scope, provenance and entry links. Matching caller
/// metadata does not establish that two reads shared a server snapshot, bind
/// an issuer or prove completeness. A trusted producer must establish those
/// properties independently before this boundary can be used for an export.
List<String> jpkSourceGaps({
  required JpkSourceBook source,
  required String issuerId,
  required FiscalYear period,
  required ReadProvenance postingProvenance,
  required Map<String, String> postingDocuments,
}) {
  final gaps = <String>{};
  final p = source.provenance;
  if (issuerId.trim().isEmpty || source.issuerId != issuerId) {
    gaps.add('Issuer source mismatch');
  }
  if (source.period != period) gaps.add('Period source mismatch');
  if (!p.isSnapshot ||
      !postingProvenance.isSnapshot ||
      p.target.isEmpty ||
      p.principal.isEmpty ||
      p.queryFingerprint.isEmpty ||
      p.target != postingProvenance.target ||
      p.principal != postingProvenance.principal ||
      p.queryFingerprint != postingProvenance.queryFingerprint ||
      p.sourceRevision != postingProvenance.sourceRevision) {
    gaps.add('Source snapshot mismatch or unavailable');
  }
  if (!source.complete || source.entryCount != source.entries.length) {
    gaps.add('Source-book completeness unavailable');
  }
  final entryIds = <String>{};
  final linkedPostings = <String>{};
  for (final entry in source.entries) {
    if (entry.entryId.trim().isEmpty || !entryIds.add(entry.entryId)) {
      gaps.add('Missing or duplicate source entry identity');
    }
    if (entry.postingId.trim().isEmpty ||
        !linkedPostings.add(entry.postingId)) {
      gaps.add('Missing or duplicate posting identity');
    }
    if (entry.facts.documentId.trim().isEmpty) {
      gaps.add('Missing source document identity');
    }
    if (postingDocuments[entry.postingId] != entry.facts.documentId) {
      gaps.add('Posting document source mismatch');
    }
  }
  if (postingDocuments.keys.any((id) => id.trim().isEmpty) ||
      linkedPostings.length != postingDocuments.length ||
      !linkedPostings.containsAll(postingDocuments.keys)) {
    gaps.add('Posting source links mismatch');
  }
  return List.unmodifiable(gaps);
}
