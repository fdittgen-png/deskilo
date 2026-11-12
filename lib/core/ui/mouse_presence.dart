// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// #3611 — whether a mouse is the pointer right now.
///
/// The desk shows what a mouse needs (a scrollbar at rest, arrows on a
/// strip, a row's ⋯ on hover) only while a mouse is connected: a phone
/// in the hand never sees them, a tablet with a mouse plugged in does.
/// The answer follows the device, so it rebuilds when one is connected
/// or removed.
class MousePresence extends StatefulWidget {
  const MousePresence({super.key, required this.builder});

  /// Builds with `true` while at least one mouse is connected.
  final ValueWidgetBuilder<bool> builder;

  /// The current answer, for a caller that only reads it once.
  static bool get connected =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  @override
  State<MousePresence> createState() => _MousePresenceState();
}

class _MousePresenceState extends State<MousePresence> {
  late bool _mouse = MousePresence.connected;

  @override
  void initState() {
    super.initState();
    RendererBinding.instance.mouseTracker.addListener(_changed);
  }

  @override
  void dispose() {
    RendererBinding.instance.mouseTracker.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // The tracker can report from inside a frame; the rebuild waits for
    // the frame to end rather than marking a tree that is being built.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
    } else {
      _sync();
    }
  }

  void _sync() {
    if (!mounted) return;
    final mouse = MousePresence.connected;
    if (mouse != _mouse) setState(() => _mouse = mouse);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _mouse, null);
}
