// SPDX-License-Identifier: MIT
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/profile/providers/profile_providers.dart';
import 'presence_heartbeat.dart';

part 'presence_providers.g.dart';

/// Starts the foreground last-seen heartbeat (#223). Watched once from
/// DeskiloApp, like the push bootstrap is watched from the shell.
///
/// Signed out, the provider builds to nothing — no timer exists at all.
/// Signing in/out rebuilds it (the same authStateProvider gate the
/// workspace providers use); while built, an [AppLifecycleListener]
/// pauses the heartbeat whenever the app leaves the resumed state.
@Riverpod(keepAlive: true)
void presenceBootstrap(Ref ref) {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return;

  final heartbeat = PresenceHeartbeat(
    // Lazy read inside the callback: the repository is only constructed
    // when a beat actually fires, and its failures stay inside the
    // heartbeat's best-effort catch.
    touch: () => ref.read(profileRepositoryProvider).touchLastSeen(),
  );
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) =>
        heartbeat.setForeground(state == AppLifecycleState.resumed),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    heartbeat.dispose();
  });

  // Null before the first lifecycle transition means "just launched",
  // i.e. foregrounded — PresenceHeartbeat already defaults to that.
  final initial = WidgetsBinding.instance.lifecycleState;
  if (initial != null) {
    heartbeat.setForeground(initial == AppLifecycleState.resumed);
  }
  heartbeat.setSignedIn(true);
}
