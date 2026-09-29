// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1818 — one shell at a time.
//
// StatefulShellRoute owns ONE GlobalKey for its navigation shell (and one
// per branch navigator). When the shell is replaced as a whole (the
// session ends and /auth takes the screen) the Navigator keeps the old
// shell mounted beneath the incoming page until that page has finished
// arriving. A session that comes back inside that window builds a second
// shell while the first is still there, and the framework refuses two
// widgets on one GlobalKey.
//
// So a shell that mounts while another is still up waits: the old one
// steps aside first, and the new one builds a frame later, once the old
// shell's state is gone. It starts FRESH, as it would have after an
// ordinary sign-out — never with the tabs and open pages of the session
// that ended, which may have been somebody else's. Without an older shell
// (every ordinary entry) the child builds at once.
import 'package:flutter/material.dart';

class ShellSlot extends StatefulWidget {
  const ShellSlot({super.key, required this.child});

  final Widget child;

  @override
  State<ShellSlot> createState() => _ShellSlotState();
}

class _ShellSlotState extends State<ShellSlot> {
  /// The slot currently building the shell.
  static _ShellSlotState? _holder;

  bool _holding = false;

  @override
  void initState() {
    super.initState();
    final previous = _holder;
    _holder = this;
    if (previous == null || !previous.mounted) {
      _holding = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previous.mounted) previous._release();
      // The frame that release schedules unmounts the old shell; claiming
      // after it keeps the keyed state from being carried over.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_holder, this)) {
          setState(() => _holding = true);
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _release() => setState(() => _holding = false);

  @override
  void dispose() {
    if (identical(_holder, this)) _holder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _holding
      ? widget.child
      : ColoredBox(color: Theme.of(context).colorScheme.surface);
}
