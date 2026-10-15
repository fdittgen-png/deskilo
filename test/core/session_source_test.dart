// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — core reads the session through SessionSource. Wired to the auth
// repository it answers exactly what the repository answers (the demo's
// fake included); unwired (the server-choice scope) it is signed out and
// nothing throws.
import 'package:deskilo/core/demo/data/auth_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wired to auth, core sees the repository\'s user and stream', () async {
    final auth = FakeAuthRepository.signedIn();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionSourceFromAuth,
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(sessionStateProvider, (_, _) {})
      ..listen(authStateProvider, (_, _) {});
    expect(container.read(sessionSourceProvider).currentUserId, 'user-1');
    expect(container.read(sessionSourceProvider), same(auth));
    expect(await container.read(sessionStateProvider.future), 'user-1');
    expect(
      await container.read(authStateProvider.future),
      await container.read(sessionStateProvider.future),
    );
  });

  test('unwired, the session is signed out and reading it does not throw',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(sessionStateProvider, (_, _) {});
    expect(container.read(sessionSourceProvider).currentUserId, isNull);
    expect(await container.read(sessionStateProvider.future), isNull);
  });

  test('in the demo scope core sees the demo session, not the real one', () {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);
    expect(container.read(sessionSourceProvider), same(fixture.auth));
  });
}
