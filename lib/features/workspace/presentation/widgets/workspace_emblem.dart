// SPDX-License-Identifier: 0BSD
//
// #1289 — the space's own mark, shown beneath the product's.
//
// Where it appears is a product decision, written down here and in the
// guides rather than sprinkled: the drawer header and the workspace
// switcher, always; nowhere else. Not the app bar of every screen —
// that is where this kind of feature goes to die — and not the boot
// splash, whose own comment says boot must not wait on a logo.
//
// Absent, still loading, too slow, undecodable: the app renders exactly
// as it did before emblems existed. That is the first test, not an
// afterthought.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/workspace_providers.dart';

class WorkspaceEmblem extends ConsumerWidget {
  const WorkspaceEmblem({super.key, this.height = 28, this.workspaceId});

  /// The drawn height; the width follows the image's aspect.
  final double height;

  /// Which space's emblem; the active one when null.
  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = workspaceId == null
        ? ref.watch(workspaceEmblemProvider).value
        : ref.watch(workspaceEmblemOfProvider(workspaceId!)).value;
    if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Image.memory(
        bytes,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        // A stored image that will not decode is not an error a member
        // can act on: the space simply shows no emblem.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
        semanticLabel: '',
      ),
    );
  }
}
