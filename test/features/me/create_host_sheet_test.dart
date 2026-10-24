// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 C2c -- Create under My spaces: the person chooses where the space
// lives. This server (when it hosts spaces) and every enrolled host are
// listed with their state; only an available one can be chosen. A chosen
// host is checked again: revoked since it was shown is refused with its
// reason and nothing opens; ready answers the onboarding on that host. A
// list that cannot be read says so, still offers this server, and Try
// again recovers.
//
// #2554 CREATE-SPLIT -- a personal home that hosts no space never offers
// itself: the space is created only on the chosen host, and with no host
// enrolled nothing opens at all (the database refuses a workspace there
// too: pgTAP 262, SQLSTATE DKR01).
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
import 'package:go_router/go_router.dart';

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
  group('CREATE-SPLIT', () {
    testWidgets('CREATE-SPLIT: a personal home that hosts no space does not '
        'offer itself; the space is created on the chosen host', (tester) async {
      enrolled.answer = WorkspaceHosts(hereHosts: false, hosts: [
        WireHost('one').enrolled(),
      ]);
      await open(tester);
      expect(key('create-host-here'), findsNothing);
      expect(key('create-host-none'), findsNothing);

      final container = ProviderScope.containerOf(
          tester.element(find.byType(CreateHostSheet)));
      await tester.runAsync(() async {
        await tester.tap(key('create-host-inst-one'));
        await untilReal(() => container.read(creationHostProvider) != null,
            what: 'the host check');
      });
      await tester.pumpAndSettle();
      expect(popped, '/onboarding?host=inst-one',
          reason: 'the onboarding runs on W, never on the personal home');
      expect(container.read(creationHostProvider)?.host.installationId,
          'inst-one');
    });

    /// Create as My spaces starts it, on a router whose onboarding is a
    /// page of its own.
    Future<GoRouter> start(WidgetTester tester) async {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) {
              // Read before Create, as My spaces has it by then.
              ref.watch(workspaceHostsProvider);
              return Scaffold(
                body: TextButton(
                  key: const ValueKey('create'),
                  onPressed: () => CreateHostSheet.start(context, ref),
                  child: const Text('create'),
                ),
              );
            },
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(
            body: SizedBox(key: ValueKey('onboarding-page')),
          ),
        ),
      ]);
      await pumpApp(
        tester,
        null,
        router: router,
        overrides: [
          sessionStateProvider.overrideWith((ref) => Stream.value('home-user')),
          workspaceHostRepositoryProvider.overrideWithValue(enrolled),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(key('create'));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('CREATE-SPLIT: a personal home with no host enrolled opens no '
        'onboarding and says there is nowhere to create', (tester) async {
      enrolled.answer = const WorkspaceHosts(hereHosts: false, hosts: []);
      final router = await start(tester);

      expect(key('onboarding-page'), findsNothing);
      expect(router.state.uri.path, '/');
      expect(key('create-host-none'), findsOneWidget);
      expect(
          find.text('No server accepts new spaces for your personal home yet. '
              'Nothing was created.'),
          findsOneWidget);
      expect(key('create-host-here'), findsNothing);
    });

    testWidgets('CREATE-SPLIT: a server that hosts spaces, with no host '
        'enrolled, goes straight to its own onboarding', (tester) async {
      enrolled.answer = WorkspaceHosts.localOnly;
      final router = await start(tester);

      expect(router.state.uri.path, '/onboarding');
      expect(key('onboarding-page'), findsOneWidget);
      expect(key('create-host-none'), findsNothing);
    });
  });
}
