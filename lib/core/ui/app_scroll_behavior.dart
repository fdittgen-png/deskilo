// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'mouse_presence.dart';

/// #3611 — how every list of the app scrolls under a mouse.
///
/// Two promises, and only these two:
///
/// * With a mouse, a vertical list shows its scrollbar at rest. A wheel
///   gives no hint of how long a page is; a thumb that is always there
///   does, and it can be grabbed. Touch keeps the platform's own
///   behaviour: no bar at rest on a phone.
/// * A mouse never drags a page. A press-and-move over text selects it,
///   it does not pan the page. Only a strip, a canvas or an explicit
///   handle opts in to mouse dragging, through [MouseDragStrip].
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) {
      return super.buildScrollbar(context, child, details);
    }
    return _MouseScrollbar(
      details: details,
      platform: super.buildScrollbar(context, child, details),
      child: child,
    );
  }
}

/// The scrollbar a vertical list wears: the platform's own while touch
/// is the pointer, an always-visible one while a mouse is.
class _MouseScrollbar extends StatefulWidget {
  const _MouseScrollbar({
    required this.details,
    required this.platform,
    required this.child,
  });

  final ScrollableDetails details;

  /// What the platform builds without a mouse (the bare list on a phone,
  /// a scrollbar on hover on a desktop).
  final Widget platform;
  final Widget child;

  @override
  State<_MouseScrollbar> createState() => _MouseScrollbarState();
}

class _MouseScrollbarState extends State<_MouseScrollbar> {
  /// The list keeps its state (scroll offset, the rows already built)
  /// when a mouse is plugged in or taken away mid-session.
  final GlobalKey _list = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final controller = widget.details.controller;
    return MousePresence(
      builder: (context, mouse, _) {
        final kept = KeyedSubtree(key: _list, child: widget.child);
        // A controller shared by several lists has no single position to
        // draw a thumb for; such a list keeps the platform's behaviour.
        final single = controller != null && controller.positions.length == 1;
        if (mouse && single) {
          return Scrollbar(
            controller: controller,
            thumbVisibility: true,
            child: kept,
          );
        }
        final platform = widget.platform;
        return platform is Scrollbar
            ? Scrollbar(controller: platform.controller, child: kept)
            : kept;
      },
    );
  }
}

/// #3611 — a sideways strip (chips, a timeline, a canvas) that a mouse
/// may drag as well as scroll. Everything else keeps the app's rule: a
/// mouse selects, it does not pan.
class MouseDragStrip extends StatelessWidget {
  const MouseDragStrip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: child,
    );
  }
}
