// SPDX-License-Identifier: 0BSD
import '../../reservations/domain/space_code.dart';

/// Reference tokens inside a member note's body (field request): a
/// message can point at a RESERVATION (or check-in) and at a SPACE —
/// seat, desk, office or level — to discuss a future booking. The
/// token bakes a human label in, so rendering never needs a lookup and
/// a since-deleted target still reads as text; tapping resolves LIVE
/// (stale targets report, like a stale QR card).
///
/// Grammar, inside the plain ≤500-char body:
///   `[res:<id>|<label>]`            — a reservation / check-in
///   `[space:<kind>:<id>|<label>]`   — kind ∈ seat|desk|office|level
///
/// Labels may not contain `]` (the composer strips it); everything
/// else — emojis included — passes through untouched.
sealed class NoteSegment {
  const NoteSegment();
}

/// Plain text between references.
class NoteText extends NoteSegment {
  const NoteText(this.text);
  final String text;
}

/// A reservation / check-in reference.
class NoteReservationRef extends NoteSegment {
  const NoteReservationRef({required this.id, required this.label});
  final String id;
  final String label;
}

/// A space reference — the subject of a future booking.
class NoteSpaceRef extends NoteSegment {
  const NoteSpaceRef({
    required this.kind,
    required this.id,
    required this.label,
  });
  final SpaceKind kind;
  final String id;
  final String label;
}

final _refPattern = RegExp(
    r'\[(?:res:(?<rid>[A-Za-z0-9-]{4,})|space:(?<kind>seat|desk|office|level):(?<sid>[A-Za-z0-9-]{4,}))\|(?<label>[^\]]+)\]');

/// Splits [body] into text and reference segments. A token that does
/// not parse stays visible as plain text — a message never loses
/// content to a malformed reference.
List<NoteSegment> parseNoteBody(String body) {
  final segments = <NoteSegment>[];
  var cursor = 0;
  for (final match in _refPattern.allMatches(body)) {
    if (match.start > cursor) {
      segments.add(NoteText(body.substring(cursor, match.start)));
    }
    final label = match.namedGroup('label')!;
    final rid = match.namedGroup('rid');
    if (rid != null) {
      segments.add(NoteReservationRef(id: rid, label: label));
    } else {
      segments.add(NoteSpaceRef(
        kind: SpaceKind.values.byName(match.namedGroup('kind')!),
        id: match.namedGroup('sid')!,
        label: label,
      ));
    }
    cursor = match.end;
  }
  if (cursor < body.length) segments.add(NoteText(body.substring(cursor)));
  return segments;
}

/// The body as the reader would say it out loud: tokens replaced by
/// their labels. This is what lists, push payload builders and
/// accessibility read.
String notePlainText(String body) => [
      for (final segment in parseNoteBody(body))
        switch (segment) {
          NoteText(:final text) => text,
          NoteReservationRef(:final label) => label,
          NoteSpaceRef(:final label) => label,
        },
    ].join();

/// The 64-character list preview (field request): the notification
/// list shows only the beginning; opening the message shows it all.
String notePreview(String body, {int max = 64}) {
  final plain = notePlainText(body).replaceAll('\n', ' ');
  if (plain.length <= max) return plain;
  // Never split a surrogate pair — emojis are first-class here.
  var cut = max;
  final codeUnit = plain.codeUnitAt(cut - 1);
  if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) cut -= 1;
  return '${plain.substring(0, cut)}…';
}

/// Builds a reservation token for the composer.
String reservationToken(String id, String label) =>
    '[res:$id|${_safeLabel(label)}]';

/// Builds a space token for the composer.
String spaceToken(SpaceKind kind, String id, String label) =>
    '[space:${kind.name}:$id|${_safeLabel(label)}]';

String _safeLabel(String label) => label.replaceAll(']', ')').trim();
