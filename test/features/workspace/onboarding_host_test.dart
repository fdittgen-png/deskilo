// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 C2c -- the onboarding on a chosen host. Reached without the host
// held, it creates nothing anywhere and leads back to choosing; with the
// host held it names the host and offers only creating (no Join of this
// server). The onboarding of this server lets go of a host held earlier,
// so a creation there can never run on the chosen host by accident.
import 'package:deskilo/features/workspace/domain/workspace_host.dart';
import 'package:deskilo/features/workspace/presentation/screens/onboarding_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/onboarding_host_gate.dart';
import 'package:deskilo/features/workspace/providers/workspace_host_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/workspace_hosts_fixture.dart';

void main() {
  late HostsWorld world;
  late WireHost one;

  Finder key(String k) => find.byKey(ValueKey(k));

  /// As the route builds it: another host is another state.
  Widget route(String? host) => OnboardingHostGate(
        key: ValueKey('onboarding:${host ?? ''}'),
        host: host,
        builder: (label) => OnboardingScreen(hostLabel: label),
      );

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen) async {
    await tester.runAsync(() async {
      one = WireHost('one');
      world = HostsWorld([WireHost('home'), one]);
      await world.open();
      await world.connect(one);
    });
    addTearDown(() => tester.runAsync(world.close));
    await pumpApp(
      tester,
      screen,
      size: const Size(800, 1200),
      overrides: [
        ...standardTestOverrides(
            workspace: FakeWorkspaceRepository(),
            connectedInstallations: world.pool,
            workspaceHosts: FakeWorkspaceHosts(
                WorkspaceHosts(hereHosts: true, hosts: [one.enrolled()]))),
      ],
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(OnboardingHostGate)));
  }

  Future<void> hold(WidgetTester tester, ProviderContainer container) async {
    await tester.runAsync(() =>
        container.read(createOnHostProvider).prepare(one.installationId));
    await tester.pump();
  }

  testWidgets('reached without the host held: nothing to create, back to '
      'choosing', (tester) async {
    await pump(tester, route('inst-one'));

    expect(key('onboarding-host-lost'), findsOneWidget);
    expect(key('onboarding-name'), findsNothing);
    expect(key('onboarding-create'), findsNothing);
  });

  testWidgets('the host held: it is named, and only creating is offered',
      (tester) async {
    final container = await pump(tester, route('inst-one'));
    await hold(tester, container);

    expect(key('onboarding-host-lost'), findsNothing);
    expect(key('onboarding-host'), findsOneWidget);
    expect(find.text('This space will be created on one.example.'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing,
        reason: 'joining is this server\'s, not the chosen host\'s');
    expect(key('onboarding-name'), findsOneWidget);
  });

  testWidgets('leaving for this server\'s onboarding lets go of the host',
      (tester) async {
    final screen = ValueNotifier<Widget>(
        route('inst-one'));
    addTearDown(screen.dispose);
    final container = await pump(tester, ValueListenableBuilder<Widget>(
        valueListenable: screen, builder: (_, s, _) => s));
    await hold(tester, container);
    final lease = container.read(creationHostProvider)!;

    screen.value = route(null);
    await tester.pump();
    await tester.pump();

    expect(container.read(creationHostProvider), isNull);
    expect(lease.pin.isLive, isFalse);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget,
        reason: 'this server offers joining again');
  });
}
