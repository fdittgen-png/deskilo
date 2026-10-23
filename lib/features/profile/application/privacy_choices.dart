// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 — the person's privacy choices: acknowledging a space's notice
// (a statement that it was read, not consent) and turning optional push
// delivery off or on for this device.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_opt_out.dart';
import '../../../core/push/push_providers.dart';
import '../../../core/push/push_status_tile.dart' show allowNotifications;
import '../providers/profile_providers.dart';

Future<void> acknowledgeSpaceNotice(
  WidgetRef ref,
  String workspaceId,
  String version,
) async {
  // #2564 — a space's notice is acknowledged on the host that holds the space.
  await ref
      .read(memberProfileRepositoryProvider)
      .acknowledgeWorkspaceNotice(workspaceId, version);
  ref.invalidate(privacyNoticesProvider);
}

/// Off: the server forgets this device first, then the choice is stored,
/// so nothing registers again on the next start. On: the push pipeline
/// starts again by itself, and — the person's deliberate choice (#2559
/// C2) — the system may ask whether notifications are allowed.
Future<void> setPushOnThisDevice(WidgetRef ref, {required bool on}) async {
  if (!on) {
    await ref.read(pushBootstrapProvider).value?.optOut();
  }
  await ref.read(pushOptedOutProvider.notifier).set(optedOut: !on);
  if (on) await allowNotifications(ref);
}
