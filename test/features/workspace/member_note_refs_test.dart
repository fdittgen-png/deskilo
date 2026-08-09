// SPDX-License-Identifier: 0BSD
//
// Note reference grammar (#523): `[res:<id>|<label>]` and
// `[space:<kind>:<id>|<label>]` tokens inside a member note's body.
// The parser, the plain-text reading and the 64-char list preview.
import 'package:deskilo/features/reservations/domain/space_code.dart';
import 'package:deskilo/features/workspace/domain/member_note_refs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('note reference grammar (#523)', () {
    test('parses text, reservation and space tokens in order', () {
      final segments = parseNoteBody(
          'See [res:res-link-1|A1 · May 14] or take [space:seat:seat-4|A1]!');
      expect(segments, hasLength(5));
      expect((segments[0] as NoteText).text, 'See ');
      final res = segments[1] as NoteReservationRef;
      expect(res.id, 'res-link-1');
      expect(res.label, 'A1 · May 14');
      expect((segments[2] as NoteText).text, ' or take ');
      final space = segments[3] as NoteSpaceRef;
      expect(space.kind, SpaceKind.seat);
      expect(space.id, 'seat-4');
      expect(space.label, 'A1');
      expect((segments[4] as NoteText).text, '!');
    });

    test('a malformed token stays visible as plain text', () {
      // Too-short id, unknown kind, missing label — none may eat text.
      for (final body in [
        '[res:x|gone]',
        '[space:room:seat-4|X]',
        '[res:res-link-1]',
      ]) {
        final segments = parseNoteBody(body);
        expect(segments, hasLength(1), reason: body);
        expect((segments.single as NoteText).text, body);
      }
    });

    test('notePlainText reads tokens as their labels', () {
      expect(
        notePlainText('Lamp on 😀 [res:res-link-1|A1 · May 14] ok'),
        'Lamp on 😀 A1 · May 14 ok',
      );
    });

    test('notePreview keeps short bodies whole, flattens newlines', () {
      expect(notePreview('Hi\nthere'), 'Hi there');
      expect(notePreview('x' * 64), 'x' * 64);
    });

    test('notePreview cuts at 64 with an ellipsis', () {
      expect(notePreview('x' * 80), '${'x' * 64}…');
    });

    test('notePreview never splits an emoji surrogate pair', () {
      final preview = notePreview('${'x' * 63}😀y');
      expect(preview, '${'x' * 63}…');
    });

    test('token builders strip ] from labels', () {
      expect(reservationToken('res-link-1', 'A1 [win]'),
          '[res:res-link-1|A1 [win)]');
      expect(spaceToken(SpaceKind.level, 'level-1', 'Top]'),
          '[space:level:level-1|Top)]');
      // And what they build parses back.
      expect(parseNoteBody(spaceToken(SpaceKind.desk, 'desk-3', 'Window'))
          .single, isA<NoteSpaceRef>());
    });
  });
}
