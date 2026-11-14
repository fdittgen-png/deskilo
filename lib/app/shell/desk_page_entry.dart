// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3946 — Tab enters a page at its first stop. A page that scrolls builds
// its content lazily: once Tab has walked it to the bottom, its first
// controls are no longer built, and a focus coming back from the top bar
// would land on the first one that still is (an early field, not the first
// stop). So a page entered from outside is first scrolled to its start.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The key of the page area (desk_scaffold.dart).
const deskPageKey = ValueKey('desk-page');

/// Scrolls the page area of [desk] to its start and calls [again] once its
/// first stops are built again. Returns false (and does nothing) when the
/// keyboard is already in the page, or when nothing in it is scrolled.
bool deskPageToStart(BuildContext desk, VoidCallback again) {
  final page = _pageElement(desk);
  final focus = FocusManager.instance.primaryFocus?.context;
  if (page == null || focus == null || !focus.mounted) return false;
  var inPage = false;
  focus.visitAncestorElements((e) {
    if (identical(e, page)) inPage = true;
    return !inPage;
  });
  if (inPage) return false;
  final scrolled = <ScrollPosition>[];
  void collect(Element e) {
    if (e is StatefulElement && e.state is ScrollableState) {
      final position = (e.state as ScrollableState).position;
      if (position.axis == Axis.vertical &&
          position.pixels > position.minScrollExtent) {
        scrolled.add(position);
      }
      return;
    }
    e.visitChildren(collect);
  }

  page.visitChildren(collect);
  if (scrolled.isEmpty) return false;
  for (final position in scrolled) {
    position.jumpTo(position.minScrollExtent);
  }
  SchedulerBinding.instance.addPostFrameCallback((_) => again());
  SchedulerBinding.instance.scheduleFrame();
  return true;
}

Element? _pageElement(BuildContext desk) {
  Element? found;
  void walk(Element e) {
    if (found != null) return;
    if (e.widget.key == deskPageKey) {
      found = e;
      return;
    }
    e.visitChildren(walk);
  }

  (desk as Element).visitChildren(walk);
  return found;
}
