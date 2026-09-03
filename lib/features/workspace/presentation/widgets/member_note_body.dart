// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import 'note_record_open.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
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
  const MemberNoteBody({
    super.key,
    required this.body,
    this.style,
    this.linkColor,
  });

  final String body;
  final TextStyle? style;

  /// Link color override — a bubble on `primaryContainer` must carry
  /// its on-color, not the theme primary (contrast, field report).
  /// Bold + underline keep the links distinguishable either way.
  final Color? linkColor;

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
    final linkInk = linkColor ?? theme.colorScheme.primary;
    final linkStyle = base?.copyWith(
      color: linkInk,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: linkInk,
    );

    // Each link is a REAL widget (field report): TextSpan tap
    // recognizers are hit-tested by character position, which the
    // WidgetSpan icons distort — taps landed on nothing. An InkWell
    // hit-tests like any widget and gives touch feedback for free.
    InlineSpan link({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) =>
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.smAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(icon,
                      size: 15, color: theme.colorScheme.primary),
                ),
                Text(label, style: linkStyle),
              ],
            ),
          ),
        );

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
            // #842 — an alert, a validation trail, or the financial
            // document the message is about.
            NoteRecordRef(:final kind, :final id, :final label) => link(
                icon: noteRecordIcon(kind),
                label: label,
                onTap: () =>
                    openRecordById(context, ref, kind: kind, id: id),
              ),
            // #798 — a LEADING quote is rendered as a block by the
            // bubble and never reaches here. One left mid-sentence
            // still has to read as something: the words it quotes.
            NoteQuoteRef(:final preview) =>
              TextSpan(text: '«$preview»', style: base),
          },
      ]),
    );
  }
}
