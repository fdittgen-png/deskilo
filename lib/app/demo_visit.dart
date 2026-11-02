// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3235 — a signed-in person's visit to the demonstration, and the way back.
//
// The demo runs in its OWN root container (demo_workspace.dart); the live
// account, client and router stay in the container above it and are not
// touched. What has to survive a visit is therefore small: who started it,
// from which of their own screens, in which workspace. That is [DemoOrigin].
//
// **The return target is captured when the visit starts, never read from
// the live router when it ends**, and it is restored only for the account,
// installation and workspace that started it. A different account, a
// sign-out, or a workspace the person no longer has leaves the origin
// dropped and the router's own guards decide where the person lands. No
// credential is stored: an expired login is not resurrected, it is asked
// about again by the same guards as any other route.
import 'dart:async';

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/backend/backend_settings.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/workspace/providers/active_workspace_providers.dart';
import 'route_classes.dart' show kDefaultHome;
import 'router.dart';

part 'demo_visit.g.dart';

/// How long the visit waits to learn the active workspace.
const Duration _kWorkspaceWait = Duration(seconds: 5);

/// Who a visit belongs to.
@immutable
class DemoIdentity {
  const DemoIdentity({
    required this.userId,
    required this.installation,
    required this.workspaceId,
  });

  final String userId;
  final String installation;
  final String? workspaceId;

  @override
  bool operator ==(Object other) =>
      other is DemoIdentity &&
      other.userId == userId &&
      other.installation == installation &&
      other.workspaceId == workspaceId;

  @override
  int get hashCode => Object.hash(userId, installation, workspaceId);
}

/// What a visit remembers: whose it is and the screen it started from.
@immutable
class DemoOrigin {
  const DemoOrigin({required this.identity, this.route});

  final DemoIdentity identity;

  /// The internal route the visit started from; null when it started from
  /// a link with no caller, in which case the person returns to home.
  final String? route;
}

@Riverpod(keepAlive: true)
class DemoVisit extends _$DemoVisit {
  @override
  DemoOrigin? build() {
    // An origin belongs to the account that started the visit. Another
    // account, or none, must never be taken back into it.
    ref.listen(authStateProvider, (_, next) {
      // A reading in progress or a failed one is not a different person.
      final owner = state?.identity.userId;
      if (owner != null && next.hasValue && next.value != owner) state = null;
    });
    return null;
  }

  /// Who is signed in now, or null when nobody is.
  Future<DemoIdentity?> identity() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return null;
    // Empty is the default installation, as no saved backend means.
    final installation =
        (await ref.read(backendSettingsStoreProvider).read())?.url ?? '';
    String? workspace;
    try {
      workspace = await ref
          .read(activeWorkspaceIdProvider.future)
          .timeout(_kWorkspaceWait);
    } on Object {
      // A workspace that cannot be read in time is no workspace to come back
      // to: the visit then returns home rather than waiting on it.
    }
    return DemoIdentity(
      userId: user,
      installation: installation,
      workspaceId: workspace,
    );
  }

  /// The live screen the person is on, as a route to come back to; null
  /// on the demo entry itself, which is not a place to return to.
  String? currentRoute() {
    final uri = ref.read(routerProvider).routeInformationProvider.value.uri;
    final path = uri.path;
    if (path == '/demo' || path == '/auth') return null;
    return uri.toString();
  }

  /// Starts a visit. A second start while one is open changes nothing: the
  /// first return target stands.
  bool begin(DemoOrigin origin) {
    if (state != null) return false;
    state = origin;
    return true;
  }

  /// Drops a visit that did not start after all.
  void cancel() => state = null;

  /// Ends the visit and takes the person back: to the screen they started
  /// from when it is still theirs, to home otherwise.
  ///
  /// The live tree is mounted again by the entry flag; the router is asked
  /// to move only after that frame, because a location set while it is not
  /// mounted is replaced by the one it was mounted at.
  Future<void> finish() async {
    final origin = state;
    state = null;
    await WidgetsBinding.instance.endOfFrame;
    final now = origin == null ? null : await identity();
    final restore = origin != null && now != null && origin.identity == now;
    ref
        .read(routerProvider)
        .go(restore ? origin.route ?? kDefaultHome : kDefaultHome);
  }
}
