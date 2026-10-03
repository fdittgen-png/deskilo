// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — "My spaces" from every linked server, in the one list, the
// server only as a quiet subtitle. A server that does not answer is said
// to be missing, never silently dropped.
//
// Opening a space that lives on another server is the existing Server
// switch, prefilled with that server: every space screen reads through
// the one client the app started with, so switching the active backend
// still restarts the session (the gap #1823 leaves open, stated in its
// PR). This pins that the path is offered, honestly, and carries the
// right server.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/features/me/domain/my_spaces.dart';
import 'package:deskilo/features/profile/presentation/screens/backend_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _other = 'https://coworkonti.example';
const _down = 'https://down.example';

ConnectedInstallation _linked(String url) => ConnectedInstallation(
  endpoint: BackendEndpoint(url, 'sb_publishable_other'),
  account: 'remote-user',
  installationId: 'inst-$url',
);

void main() {
  testWidgets('linked environments share one workspace heading', (
    tester,
  ) async {
    final me = FakeMeRepository()
      ..linkedSpaces[_other] = const [
        LinkedSpace(
          id: 'dev',
          name: 'COWORKONTI',
          pairId: 'pair',
          environment: 'dev',
        ),
        LinkedSpace(
          id: 'prod',
          name: 'COWORKONTI',
          pairId: 'pair',
          environment: 'prod',
        ),
      ];
    final router = await pumpMeApp(
      tester,
      me: me,
      connectedSources: [_linked(_other)],
    );
    await goTo(tester, router, '/me');
    expect(find.text('COWORKONTI'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);
    expect(find.text('PROD'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('linked-space-coworkonti.example-prod')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('linked-space-open')), findsOneWidget);
  });

  testWidgets('spaces on a linked server join the list, named by host', (
    tester,
  ) async {
    final me = FakeMeRepository()
      ..linkedSpaces[_other] = const [
        LinkedSpace(id: 'remote-1', name: 'COWORKONTI'),
        LinkedSpace(
          id: 'remote-2',
          name: 'Atelier',
          standing: MySpaceStanding.pending,
        ),
      ]
      ..unavailable.add(_down);
    final router = await pumpMeApp(
      tester,
      me: me,
      connectedSources: [_linked(_other), _linked(_down)],
    );
    await goTo(tester, router, '/me');

    expect(find.text('Test Space'), findsOneWidget, reason: 'this server');
    expect(find.text('COWORKONTI'), findsOneWidget);
    expect(find.text('coworkonti.example'), findsOneWidget);
    expect(
      find.text('Waiting for approval · coworkonti.example'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('linked-unavailable-down.example')),
      findsOneWidget,
    );
  });

  testWidgets('opening one offers the switch to its server, prefilled', (
    tester,
  ) async {
    final me = FakeMeRepository()
      ..linkedSpaces[_other] = const [
        LinkedSpace(id: 'remote-1', name: 'COWORKONTI'),
      ];
    final router = await pumpMeApp(
      tester,
      me: me,
      connectedSources: [_linked(_other)],
    );
    await goTo(tester, router, '/me');

    await tapIn(
      tester,
      'me-home-list',
      find.byKey(const ValueKey('linked-space-coworkonti.example-remote-1')),
    );
    expect(find.text('Open on coworkonti.example'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('linked-space-open')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/server');
    final screen = tester.widget<BackendScreen>(find.byType(BackendScreen));
    expect(screen.candidate?.endpoint.url, _other);
    expect(screen.candidate?.endpoint.key, 'sb_publishable_other');
  });
}
