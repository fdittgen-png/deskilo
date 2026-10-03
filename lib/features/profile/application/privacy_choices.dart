// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 — the person's privacy choices: acknowledging a space's notice
// (a statement that it was read, not consent) and turning optional push
// delivery off or on for this device.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_opt_out.dart';
import '../../../core/push/push_providers.dart';
import '../providers/profile_providers.dart';

Future<void> acknowledgeSpaceNotice(
  WidgetRef ref,
  String workspaceId,
  String version,
) async {
  await ref
      .read(profileRepositoryProvider)
      .acknowledgeWorkspaceNotice(workspaceId, version);
  ref.invalidate(privacyNoticesProvider);
}

/// Off: the server forgets this device first, then the choice is stored,
/// so nothing registers again on the next start. On: the push pipeline
/// starts again by itself.
Future<void> setPushOnThisDevice(WidgetRef ref, {required bool on}) async {
  if (!on) {
    await ref.read(pushBootstrapProvider).value?.optOut();
  }
  await ref.read(pushOptedOutProvider.notifier).set(!on);
}
