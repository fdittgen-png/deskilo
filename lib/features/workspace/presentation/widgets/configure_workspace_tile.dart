// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/configure_workspace.dart';
import '../../providers/workspace_providers.dart';
import 'setup_resume_banner.dart';

/// #3282 — Settings' "Manage workspace" opens with the same door the menu
/// has: Configure workspace, to the page this reader may configure.
class ConfigureWorkspaceTile extends ConsumerWidget {
  const ConfigureWorkspaceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final route = configureWorkspaceRoute(
      permissions: ref.watch(myPermissionsProvider),
      features: ref.watch(enabledFeaturesProvider).value ?? const {}, // empty-ok: unread features offer no plan door, never a refused one
      setupOpen: setupGuideOpenFor(ref, workspace?.id),
    );
    if (route == null) return const SizedBox.shrink();
    return ListTile(
      key: const ValueKey('settings-configure-workspace'),
      leading: const Icon(Icons.tune_outlined),
      title: Text(context.l10n.configureWorkspaceTitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
