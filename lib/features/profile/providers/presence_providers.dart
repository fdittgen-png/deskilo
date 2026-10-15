// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/presence/presence_heartbeat.dart';
import '../../auth/providers/auth_providers.dart';
import 'profile_providers.dart';

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
        heartbeat.setForeground(foreground: state == AppLifecycleState.resumed),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    heartbeat.dispose();
  });

  // Null before the first lifecycle transition means "just launched",
  // i.e. foregrounded — PresenceHeartbeat already defaults to that.
  final initial = WidgetsBinding.instance.lifecycleState;
  if (initial != null) {
    heartbeat.setForeground(foreground: initial == AppLifecycleState.resumed);
  }
  heartbeat.setSignedIn(signedIn: true);
}
