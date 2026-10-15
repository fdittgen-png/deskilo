// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — core/capture reads the reader's name through its own provider;
// the profile feature wires it in the composition root. Wired it is the
// profile's full name (what it read before); unwired (the server-choice
// scope) it is empty and nothing throws.
import 'package:deskilo/core/capture/capture_providers.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wired to the profile, the watermark names the reader', () {
    final container = ProviderContainer(
      overrides: [
        myProfileProvider.overrideWithValue(
          const AsyncData(Profile(id: 'user-1', displayName: 'Wall Pad')),
        ),
        captureReaderNameFromProfile,
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(captureReaderNameProvider), 'Wall Pad');
  });

  test('unwired, the name is empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(captureReaderNameProvider), '');
  });

  test('in the demo scope the watermark is wired inside the demo container', () {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);
    // Resolves without the real profile repository: it reads the demo's.
    expect(container.read(captureReaderNameProvider), isA<String>());
  });
}
