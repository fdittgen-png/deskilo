// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3076 — beside the way back to the setup guide, a step page offers the
// next step still to do (the status's own order, no second list), or "Done"
// when none is left. Taking it drops the page like the way back does, then
// opens the next step over the guide with the bar still carrying it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/setup_status.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import 'setup_return_bar.dart';

class SetupNextStepButton extends ConsumerWidget {
  const SetupNextStepButton({required this.router, this.routeStep, super.key});

  final GoRouter router;

  /// The step whose own page is on top, read from the route; the step the
  /// guide opened is the fallback.
  final String? routeStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final open = routeStep ?? ref.watch(setupOpenStepProvider);
    if (workspaceId == null || open == null) return const SizedBox.shrink();
    final status = ref.watch(workspaceSetupStatusProvider(workspaceId)).value;
    final next = status?.stepAfter(open);
    return FilledButton.tonal(
      key: const ValueKey('setup-next-step'),
      onPressed: () => _go(ref, workspaceId, next),
      child: Text(next == null ? l10n.setupStepDone : l10n.setupStepNext),
    );
  }

  void _go(WidgetRef ref, String workspaceId, SetupStepStatus? next) {
    final pending = ref.read(setupReturnPendingProvider.notifier);
    final opened = ref.read(setupOpenStepProvider.notifier);
    final status = workspaceSetupStatusProvider(workspaceId);
    pending.set(open: next != null);
    opened.set(next?.step);
    router.go('/setup');
    if (next == null) {
      ref.invalidate(status);
      return;
    }
    // The guide's own push was dropped by `go`: this one reads the status
    // again on the way back and lowers the bar, as the guide's does.
    unawaited(
      router.push(next.route).whenComplete(() {
        pending.set(open: false);
        ref.invalidate(status);
      }),
    );
  }
}
