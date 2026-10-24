// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 C2c -- Create under My spaces: the person chooses where the space
// lives. This server (when it hosts spaces) and every enrolled host are
// listed with their state; only an available one can be chosen. A chosen
// host is checked again: revoked since it was shown is refused with its
// reason and nothing opens; ready answers the onboarding on that host. A
// list that cannot be read says so, still offers this server, and Try
// again recovers.
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/ui/app_sheet.dart';
import 'package:deskilo/features/me/presentation/create_host_sheet.dart';
import 'package:deskilo/features/workspace/domain/workspace_host.dart';
import 'package:deskilo/features/workspace/providers/workspace_host_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/real_async.dart';
import '../../helpers/workspace_hosts_fixture.dart';

void main() {
  late WireHost home, one, two;
  late HostsWorld world;
  late FakeWorkspaceHosts enrolled;
  String? popped;
  var closed = false;

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      home = WireHost('home');
      one = WireHost('one');
      two = WireHost('two');
      world = HostsWorld([home, one, two]);
      await world.open();
      await world.connect(one);
    });
    addTearDown(() => tester.runAsync(world.close));
    popped = null;
    closed = false;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open'),
            onPressed: () async {
              popped = await showAppSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const CreateHostSheet(),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [
        sessionStateProvider.overrideWith((ref) => Stream.value('home-user')),
        contextClientsProvider.overrideWithValue(ContextClients(world.root)),
        connectedInstallationsProvider.overrideWithValue(world.pool),
        workspaceHostRepositoryProvider.overrideWithValue(enrolled),
      ],
    );
    await tester.tap(key('open'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String id) async {
    await tester.tap(key('create-host-$id'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    enrolled = FakeWorkspaceHosts(WorkspaceHosts(hereHosts: true, hosts: [
      WireHost('one').enrolled(),
      WireHost('two').enrolled(state: WorkspaceHostState.notAccepting),
      WireHost('six').enrolled(state: WorkspaceHostState.unverified),
    ]));
  });

  testWidgets('this server and each enrolled host, with its state; only an '
      'available host can be chosen', (tester) async {
    await open(tester);

    expect(key('create-host-here'), findsOneWidget);
    expect(find.text('one.example'), findsOneWidget);
    expect(find.text('Accepts new spaces'), findsOneWidget);
    expect(find.text('Not accepting new spaces'), findsOneWidget);
    expect(find.text('Your identity cannot be verified there'), findsOneWidget);
    expect(tester.widget<ListTile>(key('create-host-inst-one')).enabled, isTrue);
    expect(tester.widget<ListTile>(key('create-host-inst-two')).enabled, isFalse);
    expect(tester.widget<ListTile>(key('create-host-inst-six')).enabled, isFalse);

    await tester.tap(key('create-host-here'));
    await tester.pumpAndSettle();
    expect(popped, '/onboarding');
  });

  testWidgets('a ready host answers the onboarding on that host', (tester) async {
    await open(tester);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(CreateHostSheet)));
    // The host's own server answers over real I/O.
    await tester.runAsync(() async {
      await tester.tap(key('create-host-inst-one'));
      await untilReal(() => container.read(creationHostProvider) != null,
          what: 'the host check');
    });
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(popped, '/onboarding?host=inst-one');
  });

  testWidgets('revoked since it was shown: refused with its reason, nothing '
      'opens', (tester) async {
    await open(tester);
    enrolled.answer = const WorkspaceHosts(hereHosts: true, hosts: []);
    await choose(tester, 'inst-one');

    expect(closed, isFalse);
    expect(key('create-host-refused'), findsOneWidget);
    expect(find.text('No longer offered by your personal home'), findsOneWidget);
  });

  testWidgets('a list that cannot be read says so, still offers this '
      'server, and Try again recovers', (tester) async {
    enrolled.failure = Exception('offline');
    await open(tester);

    expect(key('create-host-unavailable'), findsOneWidget);
    expect(key('create-host-here'), findsOneWidget);
    expect(find.text('one.example'), findsNothing);

    enrolled.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(key('create-host-unavailable'), findsNothing);
    expect(find.text('one.example'), findsOneWidget);
  });
}
