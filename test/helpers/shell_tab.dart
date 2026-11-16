// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4098 -- the bottom bar's tab named [label], whether the bar draws its
// labels or (when they would not fit whole) the tab as its icon alone: found
// by the destination it carries, so a test taps the tab at any window width.
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter_test/flutter_test.dart';

Finder shellTab(String label) => find.byWidgetPredicate(
  (widget) => widget is ShellBarTab && widget.destination.label == label,
);
