// SPDX-License-Identifier: 0BSD
//
// #920 — the letter's logo.
//
// The shipped positioned layouts ask for an image called `logo`, because
// a default cannot know what the owner called theirs. Nobody uploads a
// file named exactly that: it is "coworking-logo-1-jpg", or whatever the
// phone produced. So the letter printed without the mark while the
// banded template — which references the real name — showed it, and the
// owner saw their logo in the preview and not on the PDF.
//
// `logo` is therefore a ROLE the library fills, not a file name.
import 'dart:typed_data';

import 'package:deskilo/features/money/presentation/report_layout_actions.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget holding a ref, with the library [names] and the bytes
/// each name resolves to.
Future<WidgetRef> _ref(
  WidgetTester tester, {
  required List<String> names,
  required Map<String, Uint8List> bytes,
}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportImagesProvider.overrideWith((ref) async => names),
        reportImageBytesProvider.overrideWith(
          (ref, name) async => bytes[name],
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
  return captured;
}

final _png = Uint8List.fromList([1, 2, 3]);

void main() {
  testWidgets('a name that exists resolves to itself, as it always did',
      (tester) async {
    final ref = await _ref(tester,
        names: const ['header-band', 'stamp'],
        bytes: {'stamp': _png});
    expect(await layoutImage(ref, 'stamp'), _png);
  });

  testWidgets('#920 — "logo" finds the image whose name SAYS logo',
      (tester) async {
    final ref = await _ref(tester,
        names: const ['coworking-logo-1-jpg', 'stamp'],
        bytes: {'coworking-logo-1-jpg': _png});
    expect(await layoutImage(ref, 'logo'), _png,
        reason: 'the shipped layout asks for the role, not the file name');
  });

  testWidgets('#920 — and when the library holds exactly ONE image, that '
      'is the workspace mark whatever it is called', (tester) async {
    final ref = await _ref(tester,
        names: const ['entete-asso'], bytes: {'entete-asso': _png});
    expect(await layoutImage(ref, 'logo'), _png);
  });

  testWidgets('#920 — with several images and none named logo, nothing is '
      'guessed: a wrong mark on a letter is worse than none',
      (tester) async {
    final ref = await _ref(tester,
        names: const ['entete-asso', 'signature-scan'],
        bytes: {'entete-asso': _png, 'signature-scan': _png});
    expect(await layoutImage(ref, 'logo'), isNull);
  });

  testWidgets('#920 — the fallback is for the logo ROLE alone; any other '
      'name a design writes means that picture', (tester) async {
    final ref = await _ref(tester,
        names: const ['coworking-logo-1-jpg'],
        bytes: {'coworking-logo-1-jpg': _png});
    expect(await layoutImage(ref, 'banner'), isNull);
  });

  testWidgets('an empty library resolves nothing', (tester) async {
    final ref = await _ref(tester, names: const [], bytes: const {});
    expect(await layoutImage(ref, 'logo'), isNull);
  });
}
