// SPDX-License-Identifier: AGPL-3.0-or-later
// #2379 — source metadata detects mismatches; it is not completeness proof.
import 'package:deskilo/core/data/read_provenance.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jpk_kr_pd_sample.dart';

void main() {
  final period = FiscalYear.calendar(2026);
  ReadProvenance snapshot(String revision) => ReadProvenance.snapshot(
    sourceRevision: revision,
    target: 'workspace',
    principal: 'principal',
    queryFingerprint: 'issuer-and-period',
  );
  final fact = jpkSampleFacts().entries.single;
  JpkSourceBook source({
    String issuer = 'issuer',
    bool complete = true,
    int count = 1,
    ReadProvenance? provenance,
    List<JpkSourceEntry>? entries,
  }) => JpkSourceBook(
    issuerId: issuer,
    period: period,
    provenance: provenance ?? snapshot('revision-1'),
    complete: complete,
    entryCount: count,
    entries:
        entries ??
        [
          JpkSourceEntry(
            entryId: 'entry-1',
            postingId: 'posting-1',
            facts: fact,
          ),
        ],
  );
  List<String> check(
    JpkSourceBook book, {
    FiscalYear? requestedPeriod,
    Map<String, String> postingDocuments = const {'posting-1': 'doc'},
  }) => jpkSourceGaps(
    source: book,
    issuerId: 'issuer',
    period: requestedPeriod ?? period,
    postingProvenance: snapshot('revision-1'),
    postingDocuments: postingDocuments,
  );

  test('matching snapshot and entry links pass boundary checks only', () {
    expect(check(source()), isEmpty);
  });
  test('another issuer, period, revision or traversal is refused', () {
    expect(check(source(issuer: 'other')), contains('Issuer source mismatch'));
    expect(
      check(source(), requestedPeriod: FiscalYear.calendar(2025)),
      contains('Period source mismatch'),
    );
    expect(
      check(source(provenance: snapshot('revision-2'))),
      contains('Source snapshot mismatch or unavailable'),
    );
    expect(
      check(
        source(provenance: const ReadProvenance.traversal(reason: 'pages')),
      ),
      contains('Source snapshot mismatch or unavailable'),
    );
  });
  test('incomplete, inconsistent and duplicated entries refuse', () {
    expect(
      check(source(complete: false)),
      contains('Source-book completeness unavailable'),
    );
    expect(
      check(source(count: 2)),
      contains('Source-book completeness unavailable'),
    );
    final row = JpkSourceEntry(
      entryId: 'same',
      postingId: 'posting-1',
      facts: fact,
    );
    final gaps = check(source(count: 2, entries: [row, row]));
    expect(gaps, contains('Missing or duplicate source entry identity'));
    expect(gaps, contains('Missing or duplicate posting identity'));
    expect(
      check(source(), postingDocuments: {'other': 'doc'}),
      contains('Posting source links mismatch'),
    );
    expect(
      check(source(), postingDocuments: {'posting-1': 'other-doc'}),
      contains('Posting document source mismatch'),
    );
  });
  test('workspace, principal and query provenance are all bound', () {
    for (final other in [
      ('other-workspace', 'principal', 'issuer-and-period'),
      ('workspace', 'other-principal', 'issuer-and-period'),
      ('workspace', 'principal', 'other-query'),
      ('', 'principal', 'issuer-and-period'),
    ]) {
      final provenance = ReadProvenance.snapshot(
        sourceRevision: 'revision-1',
        target: other.$1,
        principal: other.$2,
        queryFingerprint: other.$3,
      );
      expect(
        check(source(provenance: provenance)),
        contains('Source snapshot mismatch or unavailable'),
      );
    }
  });
}
