// SPDX-License-Identifier: 0BSD
//
// THE F-DROID SUBMISSION IS FROZEN.
//
// Owner's instruction, 2026-09-04: while MR !47409 is under review,
// nothing about the submission changes except what F-Droid themselves
// ask for in order to validate and publish the app. No version bumps,
// no proactive tidying, no "while we are in here". The recipe is worked
// on again only once DesKilo is actually published on F-Droid.
//
// The reason is not tidiness. A reviewer reads a moving target as an
// unfinished one; every push restarts a pipeline that takes a quarter of
// an hour; and this MR spent four days red over two bytes of a linker
// note nothing reads. It verifies now. Leave it alone.
//
// This test is the mechanism, not a reminder: the file is pinned, so ANY
// edit turns the suite red. That is deliberate. To make a change F-Droid
// HAS asked for, update the pin in the SAME commit and name the request
// in the message — the pin moving in review is what makes the exception
// visible instead of silent.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The recipe as submitted at v1.0.2.
///
/// PIN MOVED 2026-09-13, on the owner's instruction to update the
/// F-Droid dossier with the changes of that day — the same authority
/// that froze it on 2026-09-04, which is the only kind that lifts it.
/// The freeze otherwise stands: nothing here changes for tidiness.
///
/// What changed: three build entries for 1.0.2 (codes 31/32/33) beside
/// the 1.0.1 ones, and CurrentVersion/CurrentVersionCode to match —
/// `fdroid lint` refuses a CurrentVersionCode below the oldest build
/// entry, and `checkupdates` computes both from pubspec, so the three
/// move together or two jobs go red.
///
/// PIN MOVED AGAIN 2026-09-13: the three 1.0.2 entries carried the
/// 1.0.1 commit as a placeholder, because the tag did not exist when
/// they were written. `v1.0.2` is now
/// 1247360719f0ca23741a9adf24c60ab958a77d86, its three APKs are
/// published on that release, and run 34809486977 built arm64 twice at
/// that commit and compared 497 entries identical — which is the whole
/// point of a verified build. A recipe that names the wrong commit
/// cannot reproduce anything.
const _frozenBytes = 9974;
const _frozenHash = '0xfd476c0e585ea1fc';

/// FNV-1a, 64-bit. Hand-rolled because `crypto` is not a direct
/// dependency of this package and adding one to detect an edited YAML
/// file would be a poor trade.
String _fingerprint(List<int> bytes) {
  var hash = BigInt.parse('0xcbf29ce484222325');
  final prime = BigInt.parse('0x100000001b3');
  final mask = BigInt.parse('0xFFFFFFFFFFFFFFFF');
  for (final byte in bytes) {
    hash = (hash ^ BigInt.from(byte)) * prime & mask;
  }
  return '0x${hash.toRadixString(16).padLeft(16, '0')}';
}

void main() {
  test('the F-Droid recipe is frozen until the app is published there', () {
    final file = File('fdroid/de.deskilo.app.yml');
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();

    const explain = '\n\n'
        'fdroid/de.deskilo.app.yml changed while the submission is FROZEN.\n\n'
        'Until DesKilo is published on F-Droid, this file changes only for\n'
        'something F-Droid asked for: a reviewer comment, or a specific edit\n'
        'one of their jobs demands. Not a version bump, not tidying, not a\n'
        'drive-by.\n\n'
        'If this IS such a change, update _frozenBytes and _frozenHash in the\n'
        'SAME commit and name the F-Droid request in the commit message.\n'
        'Otherwise revert the file.\n';

    expect(bytes.length, _frozenBytes, reason: explain);
    expect(_fingerprint(bytes), _frozenHash, reason: explain);
  });
}
