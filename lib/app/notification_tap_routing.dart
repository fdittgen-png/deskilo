// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C2 — a tapped notification opens the record's screen only on the
// workspace its qualified reference names, after that workspace was found
// among the signed-in account's own: on the installation the app is signed
// in to (its workspaces list), or on a connected installation of the same
// account (verified and selected through its own pinned client). Signed
// out, another account, an unknown or unreachable source, a malformed
// reference: the neutral landing, which shows nothing of anybody's
// workspace. The personal context is never reset by a tap.
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/backend/connected_installation_providers.dart';
import '../core/backend/context_client_providers.dart';
import '../core/notifications/notification_taps.dart';
import '../core/push/notification_reference.dart';
import '../core/trace/trace_logger.dart';
import '../features/workspace/providers/connected_space_providers.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'route_classes.dart';
import 'router.dart';

part 'notification_tap_routing.g.dart';

/// Resolves a tap and acts on the answer: selects the named workspace when
/// it is not the one open, then goes to the record's screen — or to the
/// neutral landing.
@visibleForTesting
class NotificationTapOpener {
  NotificationTapOpener({
    required this.facts,
    required this.selectLocal,
    required this.go,
  });

  /// The signed-in account's facts; null while nobody is signed in.
  final Future<TapFacts?> Function() facts;

  /// Selects a workspace of the installation the app is signed in to, for
  /// this session only (a tap does not change the saved default).
  final void Function(String workspaceId) selectLocal;

  final void Function(String location) go;

  Future<TapDestination> open(Map<String, String> data) async {
    final destination = await resolveNotificationTap(data, facts);
    switch (destination) {
      case OpenInWorkspace(:final reference, :final location, :final source):
        // A connected workspace was selected by its verification already.
        if (source == null) selectLocal(reference.workspaceId);
        go(location);
      case NeutralLanding(:final reason):
        TraceLogger.instance.log(TraceLevel.info, 'push',
            'notification tap: neutral landing (${reason.name})');
        go(kMeHome);
    }
    return destination;
  }
}

/// The signed-in account's facts, read when a tap arrives.
Future<TapFacts?> _facts(Ref ref) async {
  final personal = await ref.read(personalContextProvider.future);
  if (personal == null) return null;
  return TapFacts(
    homeInstallationId: personal.homeInstallationId,
    homeWorkspaceIds: () async => {
      for (final w in await ref.read(myWorkspacesProvider.future)) w.id,
    },
    connectedSourceOf: (installationId) async {
      final connected = await ref.read(connectedInstallationsProvider).list();
      return connected
          .where((c) => c.installationId == installationId)
          .firstOrNull
          ?.endpoint
          .url;
    },
    // Entering reads the workspace through that installation's own pinned
    // client and session, and selects it only when it is there.
    verifyConnected: (source, workspaceId) async =>
        await ref
            .read(connectedSpaceEntryProvider.notifier)
            .enter(source, workspaceId) !=
        null,
  );
}

/// Takes every tap, from the moment the app is composed (a launch tap
/// waited in the inbox until now).
@Riverpod(keepAlive: true)
void notificationTapRouting(Ref ref) {
  final taps = ref.watch(notificationTapsProvider);
  final opener = NotificationTapOpener(
    facts: () => _facts(ref),
    selectLocal: (workspaceId) {
      final current = ref.read(activeWorkspaceIdProvider).value;
      final connected = ref.read(selectedWorkspaceHostProvider);
      if (current == workspaceId && connected == null) return;
      ref.read(activeWorkspaceIdProvider.notifier).activate(workspaceId);
    },
    go: (location) => ref.read(routerProvider).go(location),
  );
  taps.listen((tap) => unawaited(opener.open(tap.data)));
  ref.onDispose(taps.cancel);
}
