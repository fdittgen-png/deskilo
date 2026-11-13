// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 — the text of a record can be selected and copied with a mouse.
//
// Wrap a record's pane or page body (a column of facts, a detail sheet),
// never a lazily built list: a SelectionArea over a lazy sliver list throws
// when the list is torn down (Flutter's selection keep-alive). While no
// mouse is connected the child is returned untouched, so a phone keeps its
// long-press behaviour; a drag with a mouse selects text and never pans a
// page (app_scroll_behavior.dart), and a tap on a button still taps.
import 'package:flutter/material.dart';

import '../mouse_presence.dart';

class DeskSelection extends StatelessWidget {
  const DeskSelection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MousePresence(
    builder: (context, mouse, _) => mouse ? SelectionArea(child: child) : child,
  );
}
