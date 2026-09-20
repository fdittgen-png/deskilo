// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1514 — the seam is CLOSED, and this is what keeps it closed.
//
// Filming mode substitutes invented people at the data seam (ADR 0032).
// Adding a screen cannot leak, because a screen reads a provider and the
// provider has already been through the seam. Adding a PROVIDER could —
// a new one that fetches people straight from a repository would render
// the real thing and nothing would say so.
//
// So the reads that carry people are enumerated here, and every file in
// `lib/` that performs one must either go through the seam or be named
// below with the reason it does not. A new call site in a file that does
// neither fails this test, which is the difference between this and the
// mechanism it replaces: the blur's correctness depended on a dozen
// providers remembering something, and nothing checked.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository reads that answer with a person.
const Map<String, String> _personalReads = {
  'fetchMemberNames': 'member id → display name, for every map and grid',
  'fetchMyProfile': 'my own name, address, telephone number and identity',
  'fetchProfiles': 'the directory: names, status lines, numbers, photos',
  'fetchAvatarBytes': 'a photograph identifies as well as a name',
  'managedIdentityOf': 'the whole contact block of a managed member',
  'fetchMembers': 'the addressee line and the managed identity on a row',
  'fetchMyMember': 'the same two, on my own row',
};

/// A file has been through the seam when it names it. The seam is a
/// handful of pure functions, so naming one is naming the thing.
const List<String> _seamMarkers = [
  'recordingName',
  'recordingIdentity',
  'recordingProfile',
  'recordingPrivacyProvider',
  '_recordingOn',
];

/// Files that read a person and deliberately do NOT substitute.
///
/// Each one is a deliberate answer, not an oversight. Both of these
/// write a FILE rather than a frame, and an export taken while filming
/// mode is on must carry the truth: an accounting export or a data
/// portability answer made of invented people would be a data bug
/// wearing a privacy feature.
const Map<String, String> _exempt = {
  'lib/features/workspace/presentation/excel_export.dart':
      'writes a spreadsheet, not a frame — an export must be true',
};

Iterable<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.endsWith('.g.dart'))
    .where((f) => !f.path.endsWith('.freezed.dart'))
    // The in-memory repositories ARE the reads; they implement them.
    .where((f) => !f.path.startsWith('lib/core/demo/data/'))
    // And the Supabase implementations, for the same reason.
    .where((f) => !f.path.contains('/data/supabase_'))
    .where((f) => !f.path.contains('/domain/'));

void main() {
  test('every read that answers with a person goes through the recording '
      'seam (#1514)', () {
    final unguarded = <String>[];
    for (final file in _sources()) {
      final path = file.path;
      final text = file.readAsStringSync();
      final reads = [
        for (final entry in _personalReads.entries)
          if (text.contains('.${entry.key}(')) entry.key,
      ];
      if (reads.isEmpty) continue;
      if (_exempt.containsKey(path)) continue;
      if (_seamMarkers.any(text.contains)) continue;
      unguarded.add('$path: ${reads.join(', ')}');
    }
    expect(
      unguarded,
      isEmpty,
      reason: 'these read a person from a repository without passing the '
          'result through lib/core/privacy/recording_privacy.dart. While '
          'filming mode is on they would render somebody real. Either '
          'substitute (recordingName / recordingIdentity / '
          'recordingProfile), or add the file to _exempt with the reason '
          'a recording may carry the truth there:\n${unguarded.join('\n')}',
    );
  });

  test('the exemptions still exist and still read a person', () {
    for (final entry in _exempt.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue,
          reason: '${entry.key} is exempt but gone — delete the exemption');
      final text = file.readAsStringSync();
      expect(
        _personalReads.keys.any((r) => text.contains('.$r(')),
        isTrue,
        reason: '${entry.key} no longer reads a person: an exemption that '
            'cannot fire is a gate nothing can trip',
      );
    }
  });

  test('the rule is capable of failing', () {
    // The check applied to a file that reads a person and names no seam.
    const sample = 'final names = await repo.fetchMemberNames(id);';
    final reads = [
      for (final read in _personalReads.keys)
        if (sample.contains('.$read(')) read,
    ];
    expect(reads, isNotEmpty);
    expect(_seamMarkers.any(sample.contains), isFalse);
  });

  test('the seam itself is where the ADR says it is', () {
    expect(File('lib/core/privacy/recording_privacy.dart').existsSync(), isTrue);
    expect(
      File('docs/decisions/0032-recording-privacy-substitutes-people-at-the-'
              'data-seam.md')
          .existsSync(),
      isTrue,
    );
  });
}
