// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/workspace.dart';
import '../../domain/workspace_branding.dart';
import '../../providers/workspace_providers.dart';

/// The same workspace mark in the chooser and inside the workspace.
class WorkspaceAvatar extends ConsumerWidget {
  const WorkspaceAvatar({super.key, required this.workspace, this.radius = 20});
  final Workspace workspace;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(workspaceEmblemOfProvider(workspace.id)).value;
    final symbol = WorkspaceSymbol.of(workspace.branding);
    final letters = symbol?.text ??
        (workspace.name.isEmpty
            ? '?'
            : workspace.name.characters.first.toUpperCase());
    final fallback = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            letters,
            key: const ValueKey('workspace-avatar-letters'),
            style: symbol == null
                ? null
                : Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: symbol == null ? null : Color(symbol.argb),
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
