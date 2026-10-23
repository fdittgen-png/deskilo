// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C1 -- the composition root's half of the app-switcher cover: it
// decides which display frame is on screen (who is signed in at the
// personal home, whether the route on top is Me or a space, which
// workspace on which host) and feeds it to core's controller. Core knows
// nothing of sessions, workspaces or routes; only the frame's epoch
// reaches the native cover.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/backend/context_client_providers.dart';
import '../core/privacy/switcher_cover.dart';
import '../core/session/session_source.dart';
import '../features/workspace/domain/workspace.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'route_classes.dart';

/// The frame the app shows for these inputs.
///
/// - The session not known yet: [DisplayFrame.unknown] -- protected and
///   never acknowledged.
/// - The session failed, or nobody is signed in: the personal sign-in or
///   error screen, settled -- it is acknowledged at once and never waits
///   for a workspace host.
/// - A Me route: the personal frame of that principal; a workspace that
///   cannot be reached does not hold it covered.
/// - A space route: that workspace on that host, settled only once the
///   workspace is resolved (data or its error) -- a reload may still be
///   drawing the previous one.
@visibleForTesting
DisplayFrame displayFrameOf({
  required AsyncValue<String?> session,
  required AsyncValue<Workspace?> workspace,
  required String? hostSource,
  required String path,
}) {
  if (session.hasError) {
    return const DisplayFrame(personal: null, role: DisplaySourceRole.personal);
  }
  if (!session.hasValue || session.isLoading) {
    return const DisplayFrame.unknown();
  }
  final principal = session.value;
  if (principal == null) {
    return const DisplayFrame(
      personal: null,
      role: DisplaySourceRole.personal,
      signedOut: true,
    );
  }
  // The same split as the layer chrome: a route that needs no membership
  // is the person's own; anything else (unknown included) is a space's.
  final me = switch (classifyRoute(path)) {
    RouteClass.publicEntry ||
    RouteClass.nativeAccount ||
    RouteClass.operator => true,
    RouteClass.workspace || RouteClass.unknown => false,
  };
  if (me) {
    return DisplayFrame(personal: principal, role: DisplaySourceRole.personal);
  }
  final settled = workspace.hasError || !workspace.isLoading;
  final id = workspace.hasError ? null : workspace.value?.id;
  return DisplayFrame(
    personal: principal,
    role: DisplaySourceRole.workspace,
    target: '${hostSource ?? 'home'}|${id ?? ''}',
    settled: settled,
  );
}

/// Feeds the app-switcher cover from the composition root; renders its
/// child untouched.
class SwitcherCoverHost extends ConsumerStatefulWidget {
  const SwitcherCoverHost({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SwitcherCoverHost> createState() => _SwitcherCoverHostState();
}

class _SwitcherCoverHostState extends ConsumerState<SwitcherCoverHost> {
  late final SwitcherCoverController _controller = SwitcherCoverController(
    ref.read(switcherCoverProvider),
  );
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => unawaited(_controller.resumed()),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    widget.router.routeInformationProvider.addListener(_routed);
  }

  @override
  void didUpdateWidget(SwitcherCoverHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routeInformationProvider.removeListener(_routed);
      widget.router.routeInformationProvider.addListener(_routed);
    }
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_routed);
    _lifecycle.dispose();
    super.dispose();
  }

  void _routed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final frame = displayFrameOf(
      session: ref.watch(sessionStateProvider),
      workspace: ref.watch(currentWorkspaceProvider),
      hostSource: ref.watch(selectedWorkspaceHostProvider)?.source,
      path: widget.router.routeInformationProvider.value.uri.path,
    );
    unawaited(_controller.show(frame));
    return widget.child;
  }
}
