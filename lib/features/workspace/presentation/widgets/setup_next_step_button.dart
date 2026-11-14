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
import '../../../../l10n/dictionary_labels.dart';
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
      onPressed: status == null ? null : () => _go(ref, workspaceId, next),
      child: Text(
        next == null
            ? l10n.setupOverviewTitle
            : l10n.setupNextNamed(l10n.setupStepTitle(next.step)),
      ),
    );
  }

  void _go(WidgetRef ref, String workspaceId, SetupStepStatus? next) {
    final status = workspaceSetupStatusProvider(workspaceId);
    final route = next?.route;
    // #3629 — a step's page is an address under the guide: going there
    // keeps the guide under it, in one move the step's way out is asked
    // for. A step done on a screen of its own still opens over the guide.
    if (route == null || route.startsWith('/setup/')) {
      ref.read(setupReturnPendingProvider.notifier).set(open: false);
      ref.read(setupOpenStepProvider.notifier).set(next?.step);
      router.go(route ?? '/setup');
      ref.invalidate(status);
      return;
    }
    final pending = ref.read(setupReturnPendingProvider.notifier)
      ..set(open: true);
    ref.read(setupOpenStepProvider.notifier).set(next!.step);
    router.go('/setup');
    // The guide's own push was dropped by `go`: this one reads the status
    // again on the way back and lowers the bar, as the guide's does.
    unawaited(
      router.push(route).whenComplete(() {
        pending.set(open: false);
        ref.invalidate(status);
      }),
    );
  }
}
