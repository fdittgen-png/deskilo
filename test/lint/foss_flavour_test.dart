// SPDX-License-Identifier: 0BSD
//
// #716 — the F-Droid flavour stays buildable and Google-free, and the
// store flavour stays exactly what it was.
//
// F-Droid builds from source and refuses any Google Play Services
// dependency. The app gets there by having ONE door to push —
// `package:deskilo_push` — with two interchangeable keys: the Firebase
// package the stores ship, and a no-transport package F-Droid's recipe
// swaps in by rewriting one pubspec line. These pin what makes that
// swap safe.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app never imports Firebase directly', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('package:firebase_'))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty,
        reason: 'Firebase belongs in packages/deskilo_push only');
  });

  test('the FOSS package carries no Firebase, no Google', () {
    final files = Directory('packages/deskilo_push_foss')
        .listSync(recursive: true)
        .whereType<File>();
    for (final f in files) {
      final text = f.readAsStringSync();
      // Code, not prose: the package may SAY it carries no Firebase.
      expect(text, isNot(contains('package:firebase')), reason: f.path);
      expect(text, isNot(contains('Firebase.')), reason: f.path);
      expect(text, isNot(contains('firebase_')), reason: f.path);
      expect(text, isNot(contains('com.google')), reason: f.path);
      expect(text, isNot(contains('play-services')), reason: f.path);
    }
  });

  test('both packages share the name and the API, byte for byte', () {
    for (final dir in const ['deskilo_push', 'deskilo_push_foss']) {
      expect(
        File('packages/$dir/pubspec.yaml').readAsStringSync(),
        contains('name: deskilo_push\n'),
        reason: 'the swap only works if the name is the same',
      );
    }
    expect(
      File('packages/deskilo_push/lib/src/push_connector.dart')
          .readAsStringSync(),
      File('packages/deskilo_push_foss/lib/src/push_connector.dart')
          .readAsStringSync(),
      reason: 'the interface must be identical in both flavours',
    );
    for (final dir in const ['deskilo_push', 'deskilo_push_foss']) {
      final api = File('packages/$dir/lib/deskilo_push.dart').readAsStringSync();
      expect(api, contains('PushConnector createPushConnector({PushWarn? onWarn})'),
          reason: dir);
      expect(api, contains('const bool kPushTransportAvailable ='), reason: dir);
    }
  });

  test('the F-Droid recipe swaps exactly the line the store build uses', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // Either flavour may be checked out while this runs (the CI job
    // swaps before testing); the LINE must be the one the recipe edits.
    expect(pubspec,
        matches(RegExp(r'\n    path: packages/deskilo_push(_foss)?\n')));
    final recipe = File('fdroid/de.deskilo.app.yml').readAsStringSync();
    expect(recipe, contains('packages/deskilo_push_foss'));
    expect(recipe, contains('flutter build apk --release'));
    expect(recipe, contains('AntiFeatures'));
  });
}
