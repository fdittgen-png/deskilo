// SPDX-License-Identifier: AGPL-3.0-or-later
// #1654: finish in the context that issued the request; a completion is not
// permission to replace a newer account, workspace, installation or task.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/entry_intent.dart';
import '../../../app/entry_intents.dart';
import '../../../app/route_classes.dart';
import '../../../core/backend/backend_settings.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/wizard_navigation.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/workspace_providers.dart';

Future<bool> runOnboardingAction({required BuildContext context,
    required WidgetRef ref, required Future<String?> Function() action,
    WizardNavigationController? navigation,
    // #2869 — a screen opened over the hub when no task was asked for:
    // the creator meets the setup guide, someone joining only the hub.
    String? over}) async {
  var current = true;
  var accepted = false;
  final subscriptions = [
    ref.listenManual(authStateProvider, (before, after) {
      if (before?.hasValue == true && before?.value != after.value) current = false;
    }),
    ref.listenManual(activeBackendProvider, (before, after) {
      if (before?.hasValue == true && before?.value != after.value) current = false;
    }),
    ref.listenManual(activeWorkspaceIdProvider, (before, after) {
      if (before?.hasValue == true && before?.value != after.value) current = false;
    }),
    ref.listenManual(entryIntentsProvider, (before, after) {
      if (before?.id != after?.id) current = false;
    }),
  ];
  try {
    final succeeded = await runGuarded(context, domain: 'workspace',
      message: 'onboarding action failed', action: () async {
        final account = await ref.read(authStateProvider.future);
        if (!context.mounted || !current || account == null) return;
        await ref.read(activeBackendProvider.future);
        if (!context.mounted || !current) return;
        await ref.read(activeWorkspaceIdProvider.future);
        if (!context.mounted || !current) return;
        final String? workspaceId;
        try {
          workspaceId = await action();
        } catch (e, st) {
          if (current) rethrow;
          TraceLogger.instance.warn('workspace', 'superseded onboarding result',
            error: e, stackTrace: st);
          return;
        }
        if (!context.mounted || !current || workspaceId == null) return;
        accepted = true;
        final intent = ref.read(entryIntentsProvider);
        final explicitTask = intent != null &&
            intent.purpose != EntryPurpose.defaultEntry &&
            intent.destination != null &&
            Uri.parse(intent.destination!).path != '/onboarding';
        if (!explicitTask) {
          // The result selects this session's destination, not the account's
          // saved default. Synchronous activation leaves no delayed selection
          // write that could race another account or workspace switch.
          subscriptions[2].close();
          ref.read(activeWorkspaceIdProvider.notifier).activate(workspaceId);
          subscriptions.add(ref.listenManual<AsyncValue<String?>>(activeWorkspaceIdProvider, (before, after) {
            if (before?.value != after.value) current = false;
          }));
        }
        navigation?.completed = true;
        ref.invalidate(myWorkspacesProvider);
        await _settle(ref);
        if (!context.mounted || !current) return;
        // An explicit destination wins; otherwise enter the existing hub.
        // Popping can race router refreshes and can leave a direct visit here.
        _enter(context, explicitTask ? intent.destination! : null, over: over);
      });
    // A superseded completion must not put failure feedback on the new context.
    return !current || (succeeded && accepted);
  } finally {
    for (final subscription in subscriptions) { subscription.close(); }
  }
}

/// #2869 — the new space's list, my membership in it and its features, so
/// the destination's guard reads my rights there instead of the gap while
/// they load (the setup guide asks for manageConfiguration).
Future<void> _settle(WidgetRef ref) async {
  await ref.read(myWorkspacesProvider.future);
  await ref.read(myMemberProvider.future);
  await ref.read(enabledFeaturesProvider.future);
}

/// Goes to [destination], else to the hub with [over] opened on top of it,
/// so its back arrow returns to the hub.
void _enter(BuildContext context, String? destination, {String? over}) {
  final router = GoRouter.of(context)..go(destination ?? kDefaultHome);
  if (destination != null || over == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(router.push<void>(over));
  });
}
