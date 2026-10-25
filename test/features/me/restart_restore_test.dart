// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 CACHE-NAV — a process restart restores the personal destination
// separately from the last place in a workspace. The app is pumped, used,
// torn down and pumped again over the same device stores: a start opens the
// personal destination left, or the workspace place left when that space is
// still the one entered, on the same installation, listed and with an
// active membership; otherwise the personal destination. A record is read
// only for the account that wrote it, and a corrupted one restores nothing.
import 'package:deskilo/app/resume_places.dart';
import 'package:deskilo/core/storage/resume_place_store.dart';
import 'package:deskilo/features/me/domain/resume_places.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _issuer = 'https://test.local/auth/v1';
const _home = 'inst-test';
const _ws1 = '$kTestInstallationId:ws-1';

Future<GoRouter> _start(
  WidgetTester tester, {
  required InMemoryResumePlaceStore store,
  required FakeWorkspaceRepository workspace,
  FakeAuthRepository? auth,
}) async {
  // A restart: the previous process's tree, and its container, are gone.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  return pumpMeApp(
    tester,
    workspace: workspace,
    auth: auth ?? FakeAuthRepository.signedIn(),
    resumePlaces: store,
    extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
  );
}

String _at(GoRouter router) => router.state.uri.toString();

String _record({
  String subject = 'user-1',
  String? personal = '/me/messages',
  WorkspaceResume? workspace,
}) {
  final places = ResumePlaces(
    issuer: _issuer,
    subject: subject,
    home: _home,
    personal: personal,
  );
  return (workspace == null ? places : places.atWorkspace(workspace)).encode();
}

const _calendar = WorkspaceResume(
  installation: kTestInstallationId,
  network: _ws1,
  location: '/calendar',
);

/// ws-1, where the person was, after their membership there ended.
FakeWorkspaceRepository _ended() {
  final repo = twoSpaces();
  repo.myMember = repo.myMember.copyWith(status: MemberStatus.exited);
  return repo;
}

void main() {
  testWidgets('restart restores the personal destination left', (tester) async {
    final store = InMemoryResumePlaceStore();
    final workspace = twoSpaces();
    var router = await _start(tester, store: store, workspace: workspace);
    expect(_at(router), '/reserve', reason: 'nothing kept yet: the default');
    await goTo(tester, router, '/me/data?view=reservations');

    router = await _start(tester, store: store, workspace: workspace);
    expect(_at(router), '/me/data?view=reservations');
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart restores the workspace place while that space can '
      'still be entered, and Me still returns to the personal destination', (
    tester,
  ) async {
    final store = InMemoryResumePlaceStore();
    final workspace = twoSpaces();
    var router = await _start(tester, store: store, workspace: workspace);
    await goTo(tester, router, '/me/messages');
    await goTo(tester, router, '/calendar');
    final kept = ResumePlaces.decode(store.values['user-1']);
    expect(
      kept?.workspace,
      _calendar,
      reason: 'the space is named by installation and network reference',
    );
    expect(kept?.personal, '/me/messages');

    router = await _start(tester, store: store, workspace: workspace);
    expect(_at(router), '/calendar');

    await goTo(tester, router, '/me');
    expect(
      _at(router),
      '/me/messages',
      reason: 'the personal destination is kept apart from the space',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a space that can no longer be entered gives the personal '
      'destination', (tester) async {
    final cases = <String, (String, FakeWorkspaceRepository)>{
      'membership ended': (_record(workspace: _calendar), _ended()),
      'same local id on another installation': (
        _record(
          workspace: const WorkspaceResume(
            installation: 'other-installation',
            network: 'other-installation:ws-1',
            location: '/calendar',
          ),
        ),
        twoSpaces(),
      ),
      'no longer listed': (
        _record(
          workspace: const WorkspaceResume(
            installation: kTestInstallationId,
            network: '$kTestInstallationId:ws-9',
            location: '/calendar',
          ),
        ),
        twoSpaces(),
      ),
    };
    for (final MapEntry(key: name, value: (record, workspace))
        in cases.entries) {
      final store = InMemoryResumePlaceStore({'user-1': record});
      final router = await _start(tester, store: store, workspace: workspace);
      expect(_at(router), '/me/messages', reason: name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('another account restores nothing of the previous one\'s', (
    tester,
  ) async {
    final store = InMemoryResumePlaceStore();
    final workspace = twoSpaces();
    var router = await _start(tester, store: store, workspace: workspace);
    await goTo(tester, router, '/me/messages');
    expect(store.values['user-1'], isNotNull);
    // Even copied under the second account's key, the record names its
    // owner and is not read for anyone else.
    store.values['user-2'] = store.values['user-1']!;

    router = await _start(
      tester,
      store: store,
      workspace: workspace,
      auth: FakeAuthRepository(userId: 'user-2'),
    );
    expect(_at(router), '/reserve');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a corrupted record gives the default start', (tester) async {
    final corrupted = {
      'not JSON': '{"v":1,',
      'another version': _record().replaceFirst('"v":1', '"v":99'),
      'a workspace location in the personal slot': _record(
        personal: '/calendar',
      ),
      'a link off the app': _record(personal: 'https://example.com/me'),
      'a workspace named by a bare id': _record(
        workspace: const WorkspaceResume(
          installation: kTestInstallationId,
          network: 'ws-1',
          location: '/calendar',
        ),
      ),
    };
    for (final MapEntry(key: name, value: record) in corrupted.entries) {
      final store = InMemoryResumePlaceStore({'user-1': record});
      final router = await _start(tester, store: store, workspace: twoSpaces());
      expect(_at(router), '/reserve', reason: name);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(container.read(startPlaceProvider), StartPlace.none, reason: name);
    }
    expect(tester.takeException(), isNull);
  });
}
