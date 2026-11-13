// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1375 / #1376 — the widget that IS the Demo environment.
//
// It mounts the Demo scope as its OWN root `ProviderContainer`, not as a
// nested `ProviderScope`. That is not a style choice: an override in a
// nested scope reaches a provider read directly below it and does NOT
// reach a provider that depends on the overridden one, because the
// dependent is hosted by the root container, where nothing was
// overridden. `myWorkspacesProvider` proved it — inside a nested scope it
// answered from the live container and returned nothing. A separate root
// container has no such seam: everything read below is hosted in it, so
// every provider in the tree resolves to the fixture.
//
// The container is rebuilt whenever [DemoSession.scopeKey] changes — a
// reset (#1375) or a persona switch (#1376) — which is what disposes
// every screen that read the old fixture or the old identity. The session
// controller stays in the OUTER container: one inside would be disposed
// by the very reset it was asked to perform.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/demo_visit.dart';
import '../../../app/router.dart';
import '../../../features/workspace/providers/active_workspace_providers.dart';
import '../../locale/locale_controller.dart';
import '../demo_entry.dart';
import '../demo_link.dart';
import '../demo_reload_marker_provider.dart';
import '../demo_scope.dart';
import '../demo_session.dart';
import 'demo_environment.dart';

// Tests and the Demo's own files have always found these here.
export 'demo_environment.dart';

/// Wraps [child] in the Demo environment.
class DemoWorkspace extends ConsumerStatefulWidget {
  const DemoWorkspace({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DemoWorkspace> createState() => _DemoWorkspaceState();
}

class _DemoWorkspaceState extends ConsumerState<DemoWorkspace> {
  ProviderContainer? _container;
  String? _key;

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  ProviderContainer _containerFor(DemoSession session) {
    final existing = _container;
    if (_key == session.scopeKey && existing != null) return existing;
    existing?.dispose();
    _key = session.scopeKey;
    // #3601 — the Demo opens in the language the app is shown in: a visitor
    // who chose French is not handed a German Demo. A choice made inside the
    // Demo is kept (the store is only filled while it is empty).
    session.fixture.prefs.locale
        .adopt(ref.read(localeControllerProvider).value?.languageCode);
    final container = _container = ProviderContainer(overrides: [
      ...demoOverrides(session.fixture),
      // Only the outer router handles a tab reload; the Demo router must not
      // reinterpret its own entry marker as a cold-start request.
      demoReloadMarkerProvider.overrideWithValue(null),
    ]);
    // #2872 — a link the visitor arrived with applies after this frame:
    // no provider changes while the tree builds.
    if (ref.read(pendingDemoLinkProvider) != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _applyLink(container));
    }
    return container;
  }

  /// #2872 — the space and the screen the visitor's link named, once.
  Future<void> _applyLink(ProviderContainer container) async {
    bool current() => mounted && identical(container, _container);
    if (!current()) return;
    final link = ref.read(pendingDemoLinkProvider.notifier).take();
    if (link == null) return;
    if (link.workspaceId case final id?) {
      // A switch as the space switcher makes it, once the session has
      // resolved its first space: the session's default moves with it, so
      // a later re-resolution (the sign-in settling) does not fall back.
      await container.read(activeWorkspaceIdProvider.future);
      if (!current()) return;
      await container.read(activeWorkspaceIdProvider.notifier).select(id);
    }
    if (!current()) return;
    if (link.to case final to?) container.read(routerProvider).go(to);
  }

  /// Leaves the demonstration space, and forgets the session with it: the
  /// next visitor starts from the canonical dataset, as after a restart.
  ///
  /// #3235 — a signed-in person is taken back to where they started, if
  /// the account, installation and workspace are still the ones that
  /// started the visit; everyone else lands where the router's guards send
  /// them. The live tree below is remounted by the entry flag.
  void _leave() {
    final visit = ref.read(demoVisitProvider.notifier);
    ref.read(demoReloadMarkerProvider)?.clear();
    ref.read(demoEntryProvider.notifier).leave();
    ref.invalidate(demoSessionControllerProvider);
    unawaited(visit.finish());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(demoSessionControllerProvider);
    final controller = ref.read(demoSessionControllerProvider.notifier);
    return UncontrolledProviderScope(
      container: _containerFor(session),
      child: DemoEnvironment(
        persona: session.persona,
        onReset: controller.reset,
        onViewAs: controller.viewAs,
        onLeave: _leave,
        returnsToWorkspace: ref.watch(demoVisitProvider) != null,
        child: widget.child,
      ),
    );
  }
}
