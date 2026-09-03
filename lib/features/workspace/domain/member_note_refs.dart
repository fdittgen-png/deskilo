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
///   `[quote:<id>|<preview>]`        — the message being replied to
///   `[ref:<kind>:<id>|<label>]`     — #842, kind ∈ alert|validation|
///                                     invoice|payment|refund
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

/// #798 — the message this one replies to, the WhatsApp gesture: swipe a
/// bubble right and the reply carries a quote of it.
///
/// A reference rather than a column, for the same reason the other two
/// are: the [preview] is BAKED IN, so a quote still reads as what was
/// said even after the original is deleted — and deleting an unread
/// message is a gesture away in this same widget. Tapping resolves live
/// and scrolls to the original when it is still in the thread.
class NoteQuoteRef extends NoteSegment {
  const NoteQuoteRef({required this.id, required this.preview});
  final String id;
  final String preview;
}

/// #842 — what else a message can point at: an alert, the validation
/// trail of one, and the financial documents people actually argue
/// about. Every one of them opens the thing it names.
enum NoteRecordKind {
  /// An event in the alerts feed.
  alert,

  /// The same event, opened on its decision trail (#841) instead.
  validation,
  invoice,
  payment,

  /// A credit note — a refund is one, so it opens as an invoice does.
  refund;

  static NoteRecordKind? fromWire(String wire) =>
      NoteRecordKind.values.where((k) => k.name == wire).firstOrNull;
}

/// A reference to an alert, a validation or a financial document.
class NoteRecordRef extends NoteSegment {
  const NoteRecordRef({
    required this.kind,
    required this.id,
    required this.label,
  });
  final NoteRecordKind kind;
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
    r'\[(?:res:(?<rid>[A-Za-z0-9-]{4,})'
    r'|quote:(?<qid>[A-Za-z0-9-]{4,})'
    r'|space:(?<kind>seat|desk|office|level):(?<sid>[A-Za-z0-9-]{4,})'
    r'|ref:(?<rkind>alert|validation|invoice|payment|refund)'
    r':(?<recid>[A-Za-z0-9-]{4,}))'
    r'\|(?<label>[^\]]+)\]');

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
    final qid = match.namedGroup('qid');
    final rkind = match.namedGroup('rkind');
    if (rid != null) {
      segments.add(NoteReservationRef(id: rid, label: label));
    } else if (qid != null) {
      segments.add(NoteQuoteRef(id: qid, preview: label));
    } else if (rkind != null) {
      segments.add(NoteRecordRef(
        kind: NoteRecordKind.fromWire(rkind)!,
        id: match.namedGroup('recid')!,
        label: label,
      ));
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
          NoteRecordRef(:final label) => label,
          NoteQuoteRef(:final preview) => preview,
        },
    ].join();

/// The 64-character list preview (field request): the notification
/// list shows only the beginning; opening the message shows it all.
///
/// A LEADING quote is dropped (#798): the inbox row must show what this
/// message says, not a rerun of the one it answers — which is also what
/// every chat app shows in its list.
String notePreview(String body, {int max = 64}) {
  final segments = parseNoteBody(body);
  final withoutQuote =
      segments.isNotEmpty && segments.first is NoteQuoteRef
          ? segments.skip(1)
          : segments;
  final plain = [
    for (final segment in withoutQuote)
      switch (segment) {
        NoteText(:final text) => text,
        NoteReservationRef(:final label) => label,
        NoteSpaceRef(:final label) => label,
        NoteRecordRef(:final label) => label,
        NoteQuoteRef(:final preview) => preview,
      },
  ].join().replaceAll('\n', ' ').trim();
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

/// Splits a leading `[quote:…]` off [body].
///
/// The quote is rendered as a BLOCK above the message rather than inline
/// with it, so the bubble needs the two halves apart. A quote anywhere
/// else in the body is left where it is and renders inline.
({NoteQuoteRef? quote, String rest}) splitLeadingQuote(String body) {
  final segments = parseNoteBody(body);
  if (segments.isEmpty || segments.first is! NoteQuoteRef) {
    return (quote: null, rest: body);
  }
  final quote = segments.first as NoteQuoteRef;
  final token = quoteTokenRaw(quote.id, quote.preview);
  final rest = body.startsWith(token) ? body.substring(token.length) : body;
  return (quote: quote, rest: rest.trimLeft());
}

/// The token exactly as it appears in a body, with no preview trimming —
/// used to cut a parsed quote back out of the text it came from.
String quoteTokenRaw(String id, String preview) => '[quote:$id|$preview]';

/// Builds a quote token for the composer. The preview is trimmed to one
/// line so a quoted paragraph does not swallow the reply.
String quoteToken(String id, String preview) {
  final oneLine = _safeLabel(preview.replaceAll('\n', ' '));
  return '[quote:$id|${oneLine.length <= 80 ? oneLine : '${oneLine.substring(0, 79)}…'}]';
}

/// Builds a space token for the composer.
String spaceToken(SpaceKind kind, String id, String label) =>
    '[space:${kind.name}:$id|${_safeLabel(label)}]';

/// Builds an alert / validation / financial-document token (#842).
String recordToken(NoteRecordKind kind, String id, String label) =>
    '[ref:${kind.name}:$id|${_safeLabel(label)}]';

String _safeLabel(String label) => label.replaceAll(']', ')').trim();
