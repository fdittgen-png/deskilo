// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../domain/member_note.dart';

/// Read-check blue (0105) — a fixed hue for both themes: the receipt
/// must read as "blue" everywhere, including on the orange brand
/// palette (same as the calendar's "others" markers).
const Color noteReadBlue = Color(0xFF42A5F5);

/// The delivery/read check on a note I sent (0105): grey = delivered,
/// blue = the DIRECT recipient read it. A broadcast has many readers
/// and no single read state — it stays grey. One widget, so the inbox
/// row and the conversation bubble can never drift apart.
class NoteCheck extends StatelessWidget {
  const NoteCheck({super.key, required this.note, this.unreadColor});

  final MemberNote note;

  /// The delivered-not-read tint — a bubble on `primaryContainer`
  /// passes its muted on-color so the check stays visible (contrast).
  final Color? unreadColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(
      Icons.done,
      key: ValueKey('note-check-${note.id}'),
      size: 14,
      color: note.readAt != null
          ? noteReadBlue
          : unreadColor ?? theme.colorScheme.onSurfaceVariant,
    );
  }
}
