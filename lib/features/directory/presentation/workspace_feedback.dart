// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — a workspace in the directory carries a heart and a 0-5 star
// rating like any resource. Only a workspace of THIS installation has
// them: another server's workspace has no feedback here, so it shows none.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reservations/domain/place_feedback.dart';
import '../../reservations/presentation/widgets/place_feedback_bar.dart';
import '../../reservations/providers/place_feedback_providers.dart';
import '../domain/public_workspace.dart';

class WorkspaceFeedback extends ConsumerWidget {
  const WorkspaceFeedback({super.key, required this.workspace, this.full = false});

  final PublicWorkspace workspace;

  /// The full heart-and-stars bar (the detail page) or the compact chip (a card).
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(directorySourceIsLocalProvider)(workspace.source)) {
      return const SizedBox.shrink();
    }
    return full
        ? PlaceFeedbackBar(kind: PlaceKind.workspace, id: workspace.id)
        : PlaceFeedbackChip(
            kind: PlaceKind.workspace, id: workspace.id, title: workspace.name);
  }
}
