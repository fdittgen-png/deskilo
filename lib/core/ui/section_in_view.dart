// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3072 / #3068 — which section of a long form the reader is in, for the
// section index (SectionJumpBar) to mark. One rule for every form with an
// index, so the pill that is marked means the same on each of them.
import 'package:flutter/widgets.dart';

/// How far below the top edge of the scroll area a section still counts as
/// the one in view.
const double _threshold = 56;

/// The id of the section the reader is in after [note], from the sections'
/// [targets] in page order: the last one whose top has reached the top of
/// the scroll area, and the last section once the end of the form is
/// reached (the final sections cannot scroll to the top). Null when
/// [note] says nothing new (not a scroll update, or a nested scrollable).
String? sectionInView(
  ScrollNotification note,
  Map<String, GlobalKey> targets,
) {
  if (note.depth != 0 || note is! ScrollUpdateNotification) return null;
  final box = note.context?.findRenderObject();
  if (box is! RenderBox || targets.isEmpty) return null;
  if (note.metrics.extentAfter == 0) return targets.keys.last;
  final top = box.localToGlobal(Offset.zero).dy;
  String? current;
  for (final entry in targets.entries) {
    final section = entry.value.currentContext?.findRenderObject();
    if (section is! RenderBox || !section.attached) continue;
    if (section.localToGlobal(Offset.zero).dy <= top + _threshold) {
      current = entry.key;
    }
  }
  return current;
}
