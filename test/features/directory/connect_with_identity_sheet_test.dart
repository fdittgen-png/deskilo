// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1834 A — the Discover journey on a server this account is not
// connected to: the sheet names the host and what connecting never
// grants, opens that server's sign-in once, listens to its OWN flow only,
// says why when the server cannot take the identity, and a membership
// request made right after connecting is confirmed before it is sent.
import 'dart:async';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/federation_authority.dart';
import 'package:deskilo/core/backend/federation_handoff.dart';
import 'package:deskilo/core/backend/secondary_federation.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../me/me_app.dart';

const _elsewhere = 'https://elsewhere.example';

class _FakeConnector implements IdentityConnector {
  _FakeConnector({this.unsupported});
  final IdentityConnectUnsupported? unsupported;
  final begun = <SecondaryConnectIntent>[];
  final cancelled = <String>[];
  final _events = StreamController<SecondaryConnectEvent>.broadcast();
  var _n = 0;

  void emit(
    String flow,
    SecondaryConnectStatus status, {
    FederationFailure? failure,
  }) {
    _events.add(
      SecondaryConnectEvent(flow, begun.last, status, failure: failure),
    );
  }

  @override
  Future<IdentityConnectReadiness> assess(BackendEndpoint target) async {
    final reason = unsupported;
    if (reason != null) throw IdentityConnectUnavailable(reason);
    return IdentityConnectReadiness(
      target: target,
      authority: const FederationAuthority(
        '00000000-0000-4000-8000-000000001834',
        'https://home.example/auth/v1',
      ),
      identity: const CanonicalIdentity('https://home.example/auth/v1', 'me'),
    );
  }

  @override
  Future<String> begin(SecondaryConnectIntent intent) async {
    begun.add(intent);
    return 'flow-${++_n}';
  }

  @override
  Future<void> cancel(String flow) async => cancelled.add(flow);

  @override
  Stream<SecondaryConnectEvent> get events => _events.stream;
}

PublicWorkspace _page() => const PublicWorkspace('ws-b', _elsewhere, 'key', {
  'name': 'Space B',
  'host_type': 'company',
});

Future<FakeDirectoryRepository> _open(
  WidgetTester tester,
  _FakeConnector connector,
) async {
  final directory = FakeDirectoryRepository()..cards.add(_page());
  await pumpMeApp(
    tester,
    workspace: twoSpaces(serverDefault: null),
    directory: directory,
    identityConnector: connector,
  );
  final navigator = Navigator.of(tester.element(find.byType(Scaffold).first));
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PublicWorkspaceView(workspace: _page()),
    ),
  );
  await tester.pumpAndSettle();
  return directory;
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('asking to join a space on another server opens the identity '
      'sheet: the host, what is never granted, one Continue', (tester) async {
    final connector = _FakeConnector();
    await _open(tester, connector);
    await tester.tap(_key('portal-request-membership'));
    await tester.pumpAndSettle();

    expect(_key('identity-connect-sheet'), findsOneWidget);
    expect(find.text('Connect to elsewhere.example'), findsOneWidget);
    expect(find.textContaining('does not make you a member'), findsOneWidget);
    expect(_key('identity-connect-existing'), findsOneWidget);

    await tester.tap(_key('identity-connect-continue'));
    await tester.pumpAndSettle();
    expect(connector.begun.single.action, SecondaryConnectAction.apply);
    expect(connector.begun.single.workspaceId, 'ws-b');
    expect(connector.begun.single.target.url, _elsewhere);
    expect(_key('identity-connect-waiting'), findsOneWidget);
    expect(_key('identity-connect-cancel'), findsOneWidget);
  });

  testWidgets('connected: the request is confirmed once more before it is '
      'sent, and cancelling sends nothing', (tester) async {
    final connector = _FakeConnector();
    final directory = await _open(tester, connector);
    await tester.tap(_key('portal-request-membership'));
    await tester.pumpAndSettle();
    await tester.tap(_key('identity-connect-continue'));
    await tester.pumpAndSettle();

    // Another flow's answer is not this sheet's.
    connector.emit('flow-other', SecondaryConnectStatus.connected);
    await tester.pumpAndSettle();
    expect(_key('identity-connect-sheet'), findsOneWidget);

    connector.emit('flow-1', SecondaryConnectStatus.connected);
    await tester.pumpAndSettle();
    expect(_key('identity-connect-sheet'), findsNothing);
    expect(_key('identity-connect-confirm-apply'), findsOneWidget);
    expect(
      find.text('Send your membership request to Space B?'),
      findsOneWidget,
    );
    expect(directory.requests, isEmpty, reason: 'connecting sent nothing');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(directory.requests, isEmpty);
  });

  testWidgets('confirming after connecting sends exactly one request', (
    tester,
  ) async {
    final connector = _FakeConnector();
    final directory = await _open(tester, connector);
    await tester.tap(_key('portal-request-membership'));
    await tester.pumpAndSettle();
    await tester.tap(_key('identity-connect-continue'));
    await tester.pumpAndSettle();
    connector.emit('flow-1', SecondaryConnectStatus.connected);
    await tester.pumpAndSettle();
    await tester.tap(_key('identity-connect-send'));
    await tester.pumpAndSettle();
    expect(directory.requests, ['ws-b']);
  });

  testWidgets('somebody else signed in in the browser: said so, nothing '
      'connected, Try again offered', (tester) async {
    final connector = _FakeConnector();
    final directory = await _open(tester, connector);
    await tester.tap(_key('portal-request-membership'));
    await tester.pumpAndSettle();
    await tester.tap(_key('identity-connect-continue'));
    await tester.pumpAndSettle();
    connector.emit(
      'flow-1',
      SecondaryConnectStatus.failed,
      failure: FederationFailure.wrongAccount,
    );
    await tester.pumpAndSettle();
    expect(_key('identity-connect-message'), findsOneWidget);
    expect(find.textContaining('signed in as someone else'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(directory.requests, isEmpty);
  });

  testWidgets(
    'closing the sheet while the browser is open abandons that flow',
    (tester) async {
      final connector = _FakeConnector();
      await _open(tester, connector);
      await tester.tap(_key('portal-request-membership'));
      await tester.pumpAndSettle();
      await tester.tap(_key('identity-connect-continue'));
      await tester.pumpAndSettle();
      await tester.tap(_key('identity-connect-cancel'));
      await tester.pumpAndSettle();
      expect(connector.cancelled, ['flow-1']);
    },
  );

  testWidgets('a server that cannot take the identity says why and still '
      'offers an account the person already has there', (tester) async {
    final connector = _FakeConnector(
      unsupported: IdentityConnectUnsupported.targetWithoutDeskiloSignIn,
    );
    await _open(tester, connector);
    await tester.tap(_key('portal-request-membership'));
    await tester.pumpAndSettle();
    expect(
      _key('identity-connect-unsupported-targetWithoutDeskiloSignIn'),
      findsOneWidget,
    );
    expect(_key('identity-connect-continue'), findsNothing);
    expect(_key('identity-connect-existing'), findsOneWidget);
    expect(connector.begun, isEmpty);
  });
}
