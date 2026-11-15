// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4054 — where an open booking stands at the desk: beside the calendar
// when the window holds the calendar's least width ([listMin]: a week's
// seven readable days) and the narrowest pane; otherwise a page over the
// calendar, which stays under it as it was (its week, its filters, its
// scroll), offstage and out of the keyboard's reach until the page closes.
import 'package:flutter/material.dart';

import '../../core/storage/pane_width_store.dart';
import '../../core/ui/kit/list_detail_scaffold.dart';

class DeskBookingStage extends StatelessWidget {
  const DeskBookingStage({
    required this.listMin,
    required this.paneStore,
    required this.selected,
    required this.onClose,
    required this.list,
    required this.pane,
    super.key,
  });

  /// The least width the calendar keeps beside a booking.
  final double listMin;
  final PaneWidthStore paneStore;

  /// The booking open, if any.
  final String? selected;
  final VoidCallback onClose;
  final Widget list;
  final Widget Function(String id) pane;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final open = selected;
      final asPage =
          open != null &&
          box.maxWidth - listMin - ListDetailMetrics.grip <
              ListDetailMetrics.paneMin;
      // Expanded: the calendar under a page is offstage and gives the stack
      // no size of its own.
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: asPage,
            child: ExcludeFocus(
              excluding: asPage,
              child: ListDetailScaffold(
                id: 'calendar',
                paneStore: paneStore,
                listMin: listMin,
                list: list,
                selected: asPage ? null : open,
                onClose: onClose,
                detail: (context, id) => pane(id),
              ),
            ),
          ),
          if (asPage)
            Positioned.fill(
              key: const ValueKey('desk-booking-page'),
              child: pane(open),
            ),
        ],
      );
    },
  );
}
