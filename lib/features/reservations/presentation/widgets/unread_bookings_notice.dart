// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/unreadable_rows_notice.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';

/// #3884 -- the one line on every screen that draws the workspace's
/// bookings (the plan, the calendars, the kiosk wall, the drill-through):
/// bookings with a status this version does not know are not drawn, so a
/// place may look free that is not -- the server still decides a booking.
/// Nothing when none were left out.
class UnreadBookingsNotice extends ConsumerWidget {
  const UnreadBookingsNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return workspace == null
        ? const SizedBox.shrink()
        : UnreadableRowsNotice.area(reservationsArea(workspace.id));
  }
}
