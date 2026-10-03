// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/workspace.dart';
import '../../providers/workspace_providers.dart';

/// The same workspace mark in the chooser and inside the workspace.
class WorkspaceAvatar extends ConsumerWidget {
  const WorkspaceAvatar({super.key, required this.workspace, this.radius = 20});
  final Workspace workspace;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(workspaceEmblemOfProvider(workspace.id)).value;
    final fallback = Center(
      child: Text(
        workspace.name.isEmpty
            ? '?'
            : workspace.name.characters.first.toUpperCase(),
      ),
    );
    return CircleAvatar(
      radius: radius,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: bytes == null || bytes.isEmpty
              ? fallback
              : Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  cacheWidth:
                      (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
