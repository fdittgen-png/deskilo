// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — "My spaces" from every linked server, in the one list, the
// server only as a quiet subtitle. A server that does not answer is said
// to be missing, never silently dropped.
//
// #2562 -- opening a space that lives on another server enters it through
// that installation's own pinned client (ConnectedSpaceEntry); a refusal is
// said and changes nothing. The entry itself is proved in
// test/features/workspace/connected_space_entry_test.dart.
//
// #2562 C1b -- a space whose server's sign-in ended offers "Continue with
// Deskilo": that server's own sign-in, adopted into the pool (proved in
// test/core/backend/secondary_federation_test.dart and
// identity_adoption_test.dart), then the space is entered once more.
import 'dart:async';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/federation_authority.dart';
import 'package:deskilo/core/backend/federation_handoff.dart';
import 'package:deskilo/core/backend/secondary_federation.dart';
import 'package:deskilo/features/me/domain/linked_me_repository.dart';
import 'package:deskilo/features/me/domain/my_spaces.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/connected_space_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  test('every linked server is asked at once; one that fails is said, the '
      'others answer in their order', () async {
    final gated = _GatedSpaces();
    final container = ProviderContainer(
      overrides: [
        linkedMeRepositoryProvider.overrideWithValue(gated),
        connectedSourcesProvider.overrideWith(
          (ref) async => [_linked(_other), _linked(_down)],
        ),
      ],
    );
    addTearDown(container.dispose);
    final listener = container.listen(linkedServerSpacesProvider, (_, _) {});
    addTearDown(listener.close);

    final read = container.read(linkedServerSpacesProvider.future);
    await pumpEventQueue();
    expect(gated.asked, [_other, _down],
        reason: 'the second server is asked before the first one answers');

    gated.answers[_down]!.completeError(StateError('down'));
    gated.answers[_other]!.complete(const [
      LinkedSpace(id: 'remote-1', name: 'COWORKONTI'),
    ]);
    final servers = await read;
    expect([for (final s in servers) s.source], [_other, _down]);
    expect(servers.first.spaces.single.id, 'remote-1');
    expect(servers.last.unavailable, isTrue);
  });

  testWidgets('linked environments share one workspace heading', (
    tester,
  ) async {
    final linked = FakeLinkedMeRepository()
      ..linkedSpaces[_other] = const [
        LinkedSpace(
          id: 'dev',
          name: 'COWORKONTI',
          pairId: 'pair',
        ),
        LinkedSpace(
          id: 'prod',
          name: 'COWORKONTI',
          pairId: 'pair',
          environment: WorkspaceEnvironment.production,
        ),
      ];
    final router = await pumpMeApp(
      tester,
      linkedMe: linked,
      connectedSources: [_linked(_other)],
    );
    await goTo(tester, router, '/me');
    expect(find.text('COWORKONTI'), findsOneWidget);
    expect(find.text('Test space'), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const ValueKey('linked-space-coworkonti.example-prod')),
      matching: find.text('Open workspace')), findsOneWidget);
    expect(tester.getCenter(find.byKey(const ValueKey('linked-space-coworkonti.example-prod'))).dy,
      tester.getCenter(find.byKey(const ValueKey('linked-space-coworkonti.example-dev'))).dy);
    await tester.tap(
      find.byKey(const ValueKey('linked-space-coworkonti.example-prod')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('linked-space-open')), findsOneWidget);
  });

  testWidgets('spaces on a linked server join the list, named by host', (
    tester,
  ) async {
    final linked = FakeLinkedMeRepository()
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
      linkedMe: linked,
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

  testWidgets('opening one enters it through its own installation', (
    tester,
  ) async {
    final entry = _Entry();
    final router = await _openLinked(tester, entry);
    expect(find.text('Open on coworkonti.example'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('linked-space-open')));
    await tester.pumpAndSettle();
    expect(entry.calls, [(_other, 'remote-1')]);
    expect(router.state.uri.path, isNot('/server'));
    expect(router.state.uri.path, isNot('/me'), reason: 'the space opened');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refused entry says why and keeps the person where they are', (
    tester,
  ) async {
    final entry = _Entry()
      ..failure = ConnectionFailure(
        _other,
        ConnectionFailureReason.expired,
      );
    final router = await _openLinked(tester, entry);
    await tester.tap(find.byKey(const ValueKey('linked-space-open')));
    await tester.pumpAndSettle();
    expect(entry.calls, [(_other, 'remote-1')]);
    expect(router.state.uri.path, '/me');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(router.state.uri.path, isNot('/server'));
  });

  testWidgets('an ended sign-in there: continue with the identity, then the '
      'space is entered', (tester) async {
    final entry = _Entry()
      ..failure = ConnectionFailure(_other, ConnectionFailureReason.expired)
      ..failOnce = true;
    final connector = _Connector(SecondaryConnectStatus.connected);
    final router = await _openLinked(tester, entry, connector: connector);
    await tester.tap(find.byKey(const ValueKey('linked-space-open')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    await tester.tap(
      find.byKey(const ValueKey('linked-space-continue-identity')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('identity-connect-continue')));
    await tester.pumpAndSettle();
    expect(connector.begun.single.target.url, _other);
    expect(connector.begun.single.workspaceId, 'remote-1');
    expect(connector.begun.single.action, SecondaryConnectAction.enter);
    expect(entry.calls, [(_other, 'remote-1'), (_other, 'remote-1')]);
    expect(router.state.uri.path, isNot('/me'), reason: 'the space opened');
  });

  testWidgets('the identity sign-in refused: said in the sheet, nothing is '
      'entered, the person stays', (tester) async {
    final entry = _Entry()
      ..failure = ConnectionFailure(_other, ConnectionFailureReason.expired);
    final connector = _Connector(SecondaryConnectStatus.failed);
    final router = await _openLinked(tester, entry, connector: connector);
    await tester.tap(find.byKey(const ValueKey('linked-space-open')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('linked-space-continue-identity')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('identity-connect-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('identity-connect-message')),
        findsOneWidget);
    expect(entry.calls, [(_other, 'remote-1')], reason: 'not entered again');
    expect(router.state.uri.path, '/me');
  });

  testWidgets('an unreachable server offers no sign-in, only the reason', (
    tester,
  ) async {
    final entry = _Entry()
      ..failure = ConnectionFailure(_other, ConnectionFailureReason.unavailable);
    await _openLinked(tester, entry);
    await tester.tap(find.byKey(const ValueKey('linked-space-open')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.byKey(const ValueKey('linked-space-continue-identity')),
      findsNothing,
    );
  });
}

/// Answers the identity flow with [outcome] once the browser "returns".
class _Connector implements IdentityConnector {
  _Connector(this.outcome);
  final SecondaryConnectStatus outcome;
  final begun = <SecondaryConnectIntent>[];
  final _events = StreamController<SecondaryConnectEvent>.broadcast();

  @override
  Future<IdentityConnectReadiness> assess(BackendEndpoint target) async =>
      IdentityConnectReadiness(
        target: target,
        authority: const FederationAuthority(
          '00000000-0000-4000-8000-000000002562',
          'https://home.example/auth/v1',
        ),
        identity: const CanonicalIdentity(
          'https://home.example/auth/v1',
          'home-user',
        ),
      );

  @override
  Future<String> begin(SecondaryConnectIntent intent) async {
    begun.add(intent);
    // After the sheet knows its flow, like a real browser return.
    unawaited(Future<void>.delayed(Duration.zero, () {
      _events.add(SecondaryConnectEvent(
        'flow-1',
        intent,
        outcome,
        failure: outcome == SecondaryConnectStatus.failed
            ? FederationFailure.expired
            : null,
      ));
    }));
    return 'flow-1';
  }

  @override
  Future<void> cancel(String flow) async {}

  @override
  Stream<SecondaryConnectEvent> get events => _events.stream;
}

/// Holds every server's answer until the test releases it, and records the
/// order the servers were asked in.
class _GatedSpaces implements LinkedMeRepository {
  final asked = <String>[];
  final answers = <String, Completer<List<LinkedSpace>>>{};

  @override
  Future<List<LinkedSpace>> spaces(String source) {
    asked.add(source);
    return (answers[source] = Completer<List<LinkedSpace>>()).future;
  }

  @override
  Future<MyVisibility> visibility(String source) =>
      Future.value(MyVisibility.defaults);

  @override
  Future<void> setVisibility(
    String source,
    VisibilityField field,
    FieldAudience audience,
  ) => Future.value();
}

/// What the fake entry was asked, and how it answers.
class _Entry {
  final calls = <(String, String)>[];
  ConnectionFailure? failure;

  /// Only the first entry fails (the sign-in is then renewed).
  bool failOnce = false;
}

class _FakeEntry extends ConnectedSpaceEntry {
  _FakeEntry(this._entry);
  final _Entry _entry;

  @override
  void build() {}

  @override
  Future<Workspace?> enter(String source, String workspaceId) async {
    _entry.calls.add((source, workspaceId));
    if (_entry.failure case final f?) {
      if (_entry.failOnce) _entry.failure = null;
      throw f;
    }
    return Workspace(
      id: workspaceId,
      name: 'COWORKONTI',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'x',
    );
  }
}

Future<GoRouter> _openLinked(
  WidgetTester tester,
  _Entry entry, {
  IdentityConnector? connector,
}) async {
  final linked = FakeLinkedMeRepository()
    ..linkedSpaces[_other] = const [
      LinkedSpace(id: 'remote-1', name: 'COWORKONTI'),
    ];
  final router = await pumpMeApp(
    tester,
    linkedMe: linked,
    connectedSources: [_linked(_other)],
    identityConnector: connector,
    extraOverrides: [connectedSpaceEntryProvider.overrideWith(() => _FakeEntry(entry))],
  );
  await goTo(tester, router, '/me');
  await tapIn(
    tester,
    'me-home-list',
    find.byKey(const ValueKey('linked-space-coworkonti.example-remote-1')),
  );
  return router;
}
