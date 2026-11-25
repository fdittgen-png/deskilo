// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 -- the counter's receipts' route: it reads the open business and hands it to the screen, so the money feature
// does not import the workspace for it.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/money/presentation/counter_receipts_screen.dart';
import '../../features/workspace/providers/workspace_providers.dart';

class CounterReceiptsRoute extends ConsumerWidget {
  const CounterReceiptsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CounterReceiptsScreen(workspaceId: ref.watch(currentWorkspaceProvider).value?.id);
}
