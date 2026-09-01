// SPDX-License-Identifier: 0BSD
//
// #809 — one pinned Flutter version, and everything reads it.
//
// F-Droid's reviewer asked for the version to be pinned in this repo and
// extracted, rather than hard-coded in their recipe. `.flutter-version`
// is that pin: the recipe reads it, and so does the fdroid-foss gate.
//
// The failure this prevents is drift. Eight workflows still carry
// FLUTTER_VERSION of their own; if one is bumped and the pin is not,
// F-Droid keeps building on the old toolchain and the difference shows
// up as a build that works here and not there.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _envPin = RegExp(r'FLUTTER_VERSION:\s*"([0-9.]+)"');

void main() {
  test('.flutter-version is the one pin every workflow agrees with', () {
    final pinFile = File('.flutter-version');
    expect(pinFile.existsSync(), isTrue,
        reason: '.flutter-version is what fdroiddata reads — do not remove it');
    final pin = pinFile.readAsStringSync().trim();
    expect(pin, matches(RegExp(r'^\d+\.\d+\.\d+$')),
        reason: 'a bare version, nothing else: the recipe cats this file');

    final disagreeing = <String>[];
    for (final entity in Directory('.github/workflows').listSync()) {
      if (entity is! File || !entity.path.endsWith('.yml')) continue;
      final source = entity.readAsStringSync();
      for (final match in _envPin.allMatches(source)) {
        if (match.group(1) != pin) {
          disagreeing.add('${entity.path}: ${match.group(1)}');
        }
      }
    }

    expect(
      disagreeing,
      isEmpty,
      reason: 'These workflows pin a different Flutter than .flutter-version '
          '($pin):\n${disagreeing.join('\n')}\n\n'
          'Bump them together — F-Droid builds with the file, so a workflow '
          'that disagrees is a build we never actually test.',
    );
  });

  test('the libre swap is one script, used by everything that swaps', () {
    final script = File('tool/fdroid_foss_swap.sh');
    expect(script.existsSync(), isTrue);
    final source = script.readAsStringSync();
    // The two halves that must stay together: without the lockfile patch
    // --enforce-lockfile fails, and without the guard a Firebase package
    // could survive into a libre build unnoticed.
    expect(source, contains('pubspec.lock'));
    expect(source, contains('_flutterfire_internals'));

    final gate = File('.github/workflows/fdroid-foss.yml').readAsStringSync();
    expect(gate, contains('tool/fdroid_foss_swap.sh'),
        reason: 'our gate must run the same swap F-Droid runs');
    expect(gate, contains('--enforce-lockfile'),
        reason: 'the gate must prove the patched lock still resolves');

    final recipe = File('fdroid/de.deskilo.app.yml').readAsStringSync();
    expect(recipe, contains('tool/fdroid_foss_swap.sh'),
        reason: 'the recipe must run the same swap our gate runs');
    expect(recipe, contains('.flutter-version'),
        reason: 'the recipe must read the pin rather than carry its own');
  });
}
