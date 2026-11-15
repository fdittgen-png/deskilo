// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The composer's one attach menu (#821): the references a message can carry,
// folded into a single button beside the field. Lifted out of the composer so
// the thread's two layouts (a row under the field on a phone, one row with
// the field at desk width, #4060) draw the same menu.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/member_note_refs.dart';
import 'note_record_open.dart';

/// The attach button and its menu. Each entry keeps its own key
/// (`member-note-ref-…`, `member-note-mention`).
class ComposerAttachMenu extends StatelessWidget {
  const ComposerAttachMenu({
    required this.kinds,
    required this.labelOf,
    required this.withMention,
    required this.onReservation,
    required this.onSpace,
    required this.onMention,
    required this.onRecord,
    super.key,
  });

  /// The record kinds the menu offers, after the reservation and the space.
  final List<NoteRecordKind> kinds;
  final String Function(NoteRecordKind kind) labelOf;

  /// Whether a mention is offered (there is someone to mention).
  final bool withMention;
  final VoidCallback onReservation;
  final VoidCallback onSpace;
  final VoidCallback onMention;
  final ValueChanged<NoteRecordKind> onRecord;

  PopupMenuItem<String> _item(
    String key,
    String value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    key: ValueKey(key),
    value: value,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      key: const ValueKey('composer-attach'),
      tooltip: l10n.composerAttach,
      icon: const Icon(Icons.add_circle_outline),
      onSelected: (value) => switch (value) {
        'reservation' => onReservation(),
        'space' => onSpace(),
        'mention' => onMention(),
        // #842 — the four new kinds share one picker.
        _ => onRecord(NoteRecordKind.values.byName(value)),
      },
      itemBuilder: (context) => [
        _item(
          'member-note-ref-reservation',
          'reservation',
          Icons.event_available_outlined,
          l10n.noteRefReservation,
        ),
        _item(
          'member-note-ref-space',
          'space',
          Icons.chair_outlined,
          l10n.noteRefSpace,
        ),
        for (final kind in kinds)
          _item(
            'member-note-ref-${kind.name}',
            kind.name,
            noteRecordIcon(kind),
            labelOf(kind),
          ),
        if (withMention)
          _item(
            'member-note-mention',
            'mention',
            Icons.alternate_email,
            l10n.composerMention,
          ),
      ],
    );
  }
}
