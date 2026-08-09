// SPDX-License-Identifier: 0BSD
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reservations/domain/space_code.dart';
import '../../../reservations/presentation/widgets/reference_open.dart';
import '../../domain/member_note_refs.dart';

/// Renders a member note's FULL body (#523): plain text — emojis are
/// just text and render as such — with the `[res:…]` / `[space:…]`
/// reference tokens shown as tappable links. Tapping a reservation
/// link opens that reservation's detail sheet; tapping a space link
/// opens the space's booking sheet, ready to discuss (and book) a
/// future reservation of the seat, table, room or level.
class MemberNoteBody extends ConsumerWidget {
  const MemberNoteBody({super.key, required this.body, this.style});

  final String body;
  final TextStyle? style;

  IconData _spaceIcon(SpaceKind kind) => switch (kind) {
        SpaceKind.seat => Icons.chair_outlined,
        SpaceKind.desk => Icons.table_restaurant_outlined,
        SpaceKind.office => Icons.meeting_room_outlined,
        SpaceKind.level => Icons.layers_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium;
    final linkStyle = base?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    InlineSpan link({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) =>
        TextSpan(children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child:
                  Icon(icon, size: 15, color: theme.colorScheme.primary),
            ),
          ),
          TextSpan(
            text: label,
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = onTap,
          ),
        ]);

    return Text.rich(
      TextSpan(children: [
        for (final segment in parseNoteBody(body))
          switch (segment) {
            NoteText(:final text) => TextSpan(text: text, style: base),
            NoteReservationRef(:final id, :final label) => link(
                icon: Icons.event_available_outlined,
                label: label,
                onTap: () => openReservationById(context, ref, id),
              ),
            NoteSpaceRef(:final kind, :final id, :final label) => link(
                icon: _spaceIcon(kind),
                label: label,
                onTap: () =>
                    openSpaceById(context, ref, kind: kind, id: id),
              ),
          },
      ]),
    );
  }
}
