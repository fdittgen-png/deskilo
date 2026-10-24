// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 C2c -- creating a workspace on a host the person chose among the
// enrolled installations of their personal home. The choice is checked
// again when it is used (a fresh read of the enrolments and the device's
// own connection), and the creation then runs on that host's pinned
// client: never on the personal home in its place. Success, each typed
// refusal, and the recovery through connecting.
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_host.dart';
import 'package:deskilo/features/workspace/providers/workspace_host_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/workspace_hosts_fixture.dart';

void main() {
  late WireHost home, one, three;
  late HostsWorld world;
  late FakeWorkspaceHosts enrolled;
  late ProviderContainer container;

  setUp(() async {
    home = WireHost('home');
    one = WireHost('one');
    three = WireHost('three');
    world = HostsWorld([home, one, three]);
    await world.open();
    await world.connect(one);
    enrolled = FakeWorkspaceHosts(WorkspaceHosts(
      hereHosts: false,
      hosts: [one.enrolled(), three.enrolled()],
    ));
    container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => Stream.value('home-user')),
        authStateProvider.overrideWith((ref) => Stream.value('home-user')),
        contextClientsProvider.overrideWithValue(ContextClients(world.root)),
        connectedInstallationsProvider.overrideWithValue(world.pool),
        workspaceHostRepositoryProvider.overrideWithValue(enrolled),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await world.close();
    });
  });

  Future<HostReadiness> prepare(String id) =>
      container.read(createOnHostProvider).prepare(id);

  Future<String?> create() async => (await container
          .read(workspaceStartProvider)
          .create(
            name: 'Atelier',
            countryCode: 'FR',
            currencyCode: 'EUR',
            timezone: 'Europe/Paris',
            requestId: 'request-1',
          ))
      .workspaceId;

  bool sentCreation(WireHost h) =>
      h.calls.contains('/rest/v1/rpc/create_workspace_once');

  test('an enrolled, accepting host this device is connected to: the '
      'creation runs on its own client, never on the personal home', () async {
    final readiness = await prepare(one.installationId);

    expect(readiness, isA<HostReady>());
    final lease = container.read(creationHostProvider);
    expect(lease?.source, one.origin);
    expect(lease?.host.installationId, one.installationId);
    expect(await create(), 'ws-on-one');
    expect(sentCreation(one), isTrue);
    expect(sentCreation(home), isFalse,
        reason: 'the personal home creates nothing in the chosen host\'s place');
    expect(enrolled.reads, 1, reason: 'the choice was read fresh');
  });

  test('with no host chosen, a creation stays on this server', () async {
    expect(container.read(creationHostProvider), isNull);
    expect(await create(), isNotNull);
    expect(sentCreation(home), isTrue);
    expect(sentCreation(one), isFalse);
  });

  group('refused with its reason, nothing held', () {
    Future<void> refused(HostReadiness readiness, HostRefusal reason) async {
      expect(readiness, isA<HostRefused>());
      expect((readiness as HostRefused).reason, reason);
      expect(container.read(creationHostProvider), isNull);
      expect(sentCreation(one), isFalse);
    }

    test('revoked since the list was shown', () async {
      enrolled.answer = WorkspaceHosts(
          hereHosts: false, hosts: [three.enrolled()]);
      await refused(await prepare(one.installationId), HostRefusal.revoked);
    });

    test('closed to new workspaces', () async {
      enrolled.answer = WorkspaceHosts(hereHosts: false, hosts: [
        one.enrolled(state: WorkspaceHostState.notAccepting),
      ]);
      await refused(
          await prepare(one.installationId), HostRefusal.notAccepting);
    });

    test('no identity client verifies the person there', () async {
      enrolled.answer = WorkspaceHosts(hereHosts: false, hosts: [
        one.enrolled(state: WorkspaceHostState.unverified),
      ]);
      await refused(await prepare(one.installationId), HostRefusal.unverified);
    });

    test('the connection at its address is another installation', () async {
      enrolled.answer = WorkspaceHosts(hereHosts: false, hosts: [
        one.enrolled(id: 'inst-enrolled-elsewhere'),
      ]);
      await refused(
          await prepare('inst-enrolled-elsewhere'), HostRefusal.unverified);
    });
  });

  test('recovery: not connected yet asks for the identity sign-in; once '
      'connected the same host is ready', () async {
    final first = await prepare(three.installationId);
    expect(first, isA<HostNeedsConnection>());
    expect(container.read(creationHostProvider), isNull);

    await world.connect(three);
    final second = await prepare(three.installationId);

    expect(second, isA<HostReady>());
    expect(container.read(creationHostProvider)?.source, three.origin);
  });

  test('a connection that ended refuses the creation with its typed end; '
      'the personal home never takes it over', () async {
    await prepare(one.installationId);
    await world.pool.disconnect(one.origin);

    await expectLater(create(), throwsA(isA<ConnectionFailure>()));
    expect(sentCreation(home), isFalse);
    expect(sentCreation(one), isFalse);
  });

  test('a newer choice replaces the older one; clearing gives it back',
      () async {
    await world.connect(three);
    await prepare(one.installationId);
    final first = container.read(creationHostProvider)!;
    await prepare(three.installationId);

    expect(container.read(creationHostProvider)?.source, three.origin);
    expect(first.pin.isLive, isFalse, reason: 'the older lease was released');
    container.read(creationHostProvider.notifier).clear();
    expect(container.read(creationHostProvider), isNull);
  });
}
