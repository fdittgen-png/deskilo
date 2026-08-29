// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'calendar_hub_screen.dart';
import 'calendar_screen.dart';

/// The Calendar branch (#718): the hub while `calendarHub` is on, the
/// classic reservations calendar when the owner turned it off. Picked
/// per build, so flipping the feature swaps the screen in place — the
/// shell keeps the branch alive and a const screen could not follow.
class CalendarBranch extends ConsumerWidget {
  const CalendarBranch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.calendarHub);
    return hub ? const CalendarHubScreen() : const CalendarScreen();
  }
}
