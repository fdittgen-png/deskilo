// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../task_recorder/presentation/route_classification.dart'
    show taskWizardRoute;
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';

/// The way into the task wizard — recording, guides and tools in one place —
/// from the Me layer's menu and from Me › Me; nothing while the task
/// recorder is off.
class TaskWizardEntry extends ConsumerWidget {
  const TaskWizardEntry({
    super.key,
    required this.entryKey,
    this.closesDrawer = false,
    this.chevron = false,
  });

  /// The row's own key, which the recorder and the tests name it by.
  final String entryKey;

  /// Whether opening the wizard first closes the drawer the row sits in.
  final bool closesDrawer;

  /// Whether the row ends with a chevron, as a door to another page does.
  final bool chevron;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.taskRecorder);
    if (!on) return const SizedBox.shrink();
    return ListTile(
      key: ValueKey(entryKey),
      leading: const Icon(Icons.assistant_navigation),
      title: Text(context.l10n.taskWizardTitle),
      trailing: chevron ? const Icon(Icons.chevron_right) : null,
      onTap: () {
        if (closesDrawer) Navigator.of(context).pop();
        unawaited(context.push(taskWizardRoute));
      },
    );
  }
}
