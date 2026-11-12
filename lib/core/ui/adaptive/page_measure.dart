// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3604 (desk F3) — the three measures as widgets. The frame applies the one
// a route declares (lib/app/page_frame.dart); inside a page they may hold a
// part of it (a form section in a work page). Each measures the room it is
// given, not the window, and tells the page that room (MediaQuery), so a page
// lays itself out in what it actually has.
import 'package:flutter/widgets.dart';

import 'page_measures.dart';
import 'window_class.dart';

export 'page_measures.dart';

/// [child] centred in at most [maxWidth] of the room given, less [gutter] on
/// each side; the child measures that width.
class _Measure extends StatelessWidget {
  const _Measure({
    required this.maxWidth,
    required this.child,
    this.gutter = _noGutter,
  });

  final double maxWidth;
  final double Function(double room) gutter;
  final Widget child;

  static double _noGutter(double room) => 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final media = MediaQuery.of(context);
      final room = box.maxWidth.isFinite ? box.maxWidth : media.size.width;
      final height = box.maxHeight.isFinite ? box.maxHeight : media.size.height;
      final side = gutter(room);
      final width = (room - 2 * side).clamp(0.0, maxWidth);
      return Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, height)),
            child: child,
          ),
        ),
      );
    },
  );
}

/// A column to read, [kReadingColumnWidth] at most.
class ReadingColumn extends StatelessWidget {
  const ReadingColumn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _Measure(maxWidth: kReadingColumnWidth, child: child);
}

/// A column to fill in, [kFormColumnWidth] at most.
class FormColumn extends StatelessWidget {
  const FormColumn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _Measure(maxWidth: kFormColumnWidth, child: child);
}

/// The whole room, with a gutter from the expanded window class, at most
/// [kWorkAreaMaxWidth].
class WorkArea extends StatelessWidget {
  const WorkArea({required this.child, super.key});

  final Widget child;

  /// The gutter for [room]: none below the expanded class.
  static double gutterFor(double room) => switch (WindowClass.ofWidth(room)) {
    WindowClass.compact || WindowClass.medium => 0,
    WindowClass.expanded => kWorkAreaGutterExpanded,
    WindowClass.large || WindowClass.extraLarge => kWorkAreaGutterLarge,
  };

  @override
  Widget build(BuildContext context) =>
      _Measure(maxWidth: kWorkAreaMaxWidth, gutter: gutterFor, child: child);
}
