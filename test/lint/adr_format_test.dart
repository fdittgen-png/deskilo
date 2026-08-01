// SPDX-License-Identifier: 0BSD
//
// Docs-parity lint: decision records keep the shape that makes them
// citable.
//
// ADRs are the project's long-term memory — code references them by
// number ("ADR 0003 forbids…"), CI scripts quote them, the wiki links
// them. That only works while the numbering is contiguous, the number in
// the title matches the filename, and a superseded record points at its
// successor. Sparkilo enforces its record format by test; this is the
// same idea sized to this repo's ten records.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = Directory('docs/decisions')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('ADR numbering is contiguous from 0001, no gaps or duplicates', () {
    final numbers = <int>[];
    for (final f in files) {
      final name = f.path.split('/').last;
      final m = RegExp(r'^(\d{4})-[a-z0-9-]+\.md$').firstMatch(name);
      expect(m, isNotNull,
          reason: '$name is not NNNN-kebab-case-slug.md');
      numbers.add(int.parse(m!.group(1)!));
    }
    expect(
      numbers,
      List.generate(numbers.length, (i) => i + 1),
      reason: 'ADR numbers must run 0001..${numbers.length} without gaps — '
          'a gap reads as a decision that was deleted rather than '
          'superseded, and nothing may be deleted.',
    );
  });

  test('every ADR has a matching title and a Status/Date line', () {
    for (final f in files) {
      final name = f.path.split('/').last;
      final number = name.substring(0, 4);
      final lines = f.readAsLinesSync();

      expect(
        lines.first,
        startsWith('# ADR $number — '),
        reason: '$name: first line must be "# ADR $number — <title>" so '
            'the number in citations matches the file it names.',
      );

      final status = lines.firstWhere(
        (l) => l.startsWith('**Status:**'),
        orElse: () => '',
      );
      expect(status, isNotEmpty,
          reason: '$name: no "**Status:**" line.');
      expect(
        status,
        matches(RegExp(r'\*\*Status:\*\* (accepted|superseded|proposed)')),
        reason: '$name: status must be accepted, superseded or proposed — '
            'got "$status".',
      );
      expect(
        status,
        matches(RegExp(r'\*\*Date:\*\* \d{4}-\d{2}-\d{2}')),
        reason: '$name: the Status line must carry "**Date:** YYYY-MM-DD".',
      );

      // A superseded record must point forward — a dead end here means a
      // reader stops at the WRONG decision and acts on it.
      if (status.contains('superseded')) {
        final link = RegExp(r'\]\((\d{4}-[a-z0-9-]+\.md)\)').firstMatch(status);
        expect(link, isNotNull,
            reason: '$name: superseded, but the Status line has no '
                '(NNNN-slug.md) link to the superseding record.');
        expect(
          File('docs/decisions/${link!.group(1)}').existsSync(),
          isTrue,
          reason: '$name: supersession link points at a record that does '
              'not exist: ${link.group(1)}',
        );
      }
    }
  });
}
