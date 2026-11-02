// SPDX-License-Identifier: AGPL-3.0-or-later
// #3235 — a stale tab hint must reach guarded consent, not a live inner route.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/demo_visit.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/demo/demo_reload_marker.dart';
import 'package:deskilo/core/demo/demo_reload_marker_provider.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_entry_screen.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/kiosk/providers/kiosk_mode.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

class _Tab implements DemoReloadMarkerStorage {
  String? value = 'demo-visit-v1';
  @override
  String? read() => value;
  @override
  void write(String value) => this.value = value;
  @override
  void clear() => value = null;
}

class _LockedKiosk extends KioskMode {
  @override
  KioskModeDecision build() => KioskModeDecision.accepted;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a cold inner route opens guarded consent, then fresh Demo', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final tab = _Tab();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(outer.read(routerProvider).state.uri.path, '/demo');
    expect(find.byType(DemoEntryScreen), findsOneWidget);
    expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
    expect(outer.read(demoEntryProvider), isFalse);
    expect(outer.read(demoVisitProvider), isNull);
    await tester.tap(find.byKey(const Key('demo-entry-start')));
    await _settle(tester);
    expect(outer.read(demoEntryProvider), isTrue);
    expect(find.byType(DemoWorkspace), findsOneWidget);
    expect(outer.read(demoVisitProvider)?.route, isNull);
    await tester.tap(find.byKey(DemoControls.leaveKey));
    await _settle(tester);
    expect(tab.value, isNull);
    expect(outer.read(demoEntryProvider), isFalse);
  });

  testWidgets('a stale marker cannot override a disabled Demo', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final tab = _Tab();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            workspace: FakeWorkspaceRepository.withWorkspace(
              featureFlags: {'demoMode': false},
            ),
          ),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(outer.read(demoEntryProvider), isFalse);
    expect(find.byKey(const Key('demo-entry-start')), findsNothing);
    expect(find.byType(DemoWorkspace), findsNothing);
  });

  testWidgets('unresolved authentication cannot start a public Demo', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final auth = StreamController<String?>.broadcast();
    addTearDown(auth.close);
    final tab = _Tab();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(),
          authStateProvider.overrideWith((ref) => auth.stream),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(find.byKey(const Key('demo-entry-start')), findsNothing);
    expect(outer.read(demoEntryProvider), isFalse);
    auth.add('user-1');
    await _settle(tester);
    expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
    expect(outer.read(demoEntryProvider), isFalse);
  });

  testWidgets('cancelling recovered consent clears the tab hint', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final tab = _Tab();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(tab.value, isNull);
    expect(outer.read(demoEntryProvider), isFalse);
    expect(outer.read(routerProvider).state.uri.path, '/demo');
  });

  testWidgets('a reload creates a fresh fixture and does not restore origin', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final tab = _Tab();
    Widget app() => ProviderScope(
      overrides: [
        ...standardTestOverrides(),
        demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
      ],
      child: const DeskiloRoot(),
    );
    await tester.pumpWidget(app());
    await _settle(tester);
    await tester.tap(find.byKey(const Key('demo-entry-start')));
    await _settle(tester);
    var outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    await outer
        .read(demoSessionControllerProvider)
        .fixture
        .floorPlan
        .createLevel('ws-1', 'Temporary Demo level', 9);
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
    await tester.pumpWidget(app());
    await _settle(tester);
    outer = ProviderScope.containerOf(tester.element(find.byType(DeskiloRoot)));
    expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
    expect(outer.read(demoVisitProvider), isNull);
    await tester.tap(find.byKey(const Key('demo-entry-start')));
    await _settle(tester);
    final levels = await outer
        .read(demoSessionControllerProvider)
        .fixture
        .floorPlan
        .fetchLevels('ws-1');
    expect(
      levels.map((level) => level.name),
      isNot(contains('Temporary Demo level')),
    );
    expect(outer.read(demoVisitProvider)?.route, isNull);
  });

  testWidgets(
    'explicit Demo URL retains its validated destination and consent',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/demo?space=pezenas&persona=owner&to=%2Ffeatures';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final tab = _Tab();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...standardTestOverrides(),
            demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
          ],
          child: const DeskiloRoot(),
        ),
      );
      await _settle(tester);
      final outer = ProviderScope.containerOf(
        tester.element(find.byType(DeskiloRoot)),
      );
      expect(
        outer.read(routerProvider).state.uri.queryParameters['to'],
        '/features',
      );
      expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
      expect(outer.read(demoEntryProvider), isFalse);
    },
  );

  testWidgets('late feature denial prevents a consent already in progress', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final features = Completer<Set<WorkspaceFeature>>();
    final tab = _Tab();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(),
          enabledFeaturesProvider.overrideWith((ref) => features.future),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-entry-start')));
    await tester.pump();
    features.complete(<WorkspaceFeature>{});
    await _settle(tester);
    expect(outer.read(demoEntryProvider), isFalse);
    expect(find.byType(DemoWorkspace), findsNothing);
  });

  testWidgets('a stale marker uses only the current account on a new visit', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final tab = _Tab();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..myMember = const Member(
        id: 'member-current',
        workspaceId: 'ws-1',
        userId: 'user-current',
        isAdmin: true,
        isOwner: true,
        status: MemberStatus.active,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            auth: FakeAuthRepository(userId: 'user-current'),
            workspace: workspace,
          ),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(outer.read(demoVisitProvider), isNull);
    await tester.tap(find.byKey(const Key('demo-entry-start')));
    await _settle(tester);
    expect(outer.read(demoVisitProvider)?.identity.userId, 'user-current');
    expect(outer.read(demoVisitProvider)?.route, isNull);
  });

  testWidgets('a stale marker cannot escape a locked kiosk', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final tab = _Tab();
    final workspace =
        FakeWorkspaceRepository.withWorkspace(featureFlags: {'kioskMode': true})
          ..myMember = const Member(
            id: 'member-1',
            workspaceId: 'ws-1',
            userId: 'user-1',
            isAdmin: false,
            isOwner: false,
            isKiosk: true,
            status: MemberStatus.active,
          );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(workspace: workspace),
          kioskModeProvider.overrideWith(_LockedKiosk.new),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(outer.read(routerProvider).state.uri.path, '/kiosk');
    expect(outer.read(demoEntryProvider), isFalse);
    expect(find.byType(DemoWorkspace), findsNothing);
  });

  testWidgets('unresolved then locked kiosk membership never starts Demo', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/features';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final member = Completer<Member?>();
    final tab = _Tab();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            workspace: FakeWorkspaceRepository.withWorkspace(
              featureFlags: {'kioskMode': true},
            ),
          ),
          myMemberProvider.overrideWith((ref) => member.future),
          kioskModeProvider.overrideWith(_LockedKiosk.new),
          demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(tab)),
        ],
        child: const DeskiloRoot(),
      ),
    );
    await _settle(tester);
    final outer = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloRoot)),
    );
    expect(find.byKey(const Key('demo-entry-start')), findsNothing);
    expect(outer.read(demoEntryProvider), isFalse);
    member.complete(
      const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        isKiosk: true,
        status: MemberStatus.active,
      ),
    );
    await _settle(tester);
    expect(outer.read(demoEntryProvider), isFalse);
    expect(find.byType(DemoWorkspace), findsNothing);
  });
}
