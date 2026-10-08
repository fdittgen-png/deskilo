// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2216 — a mention names WHO: `[at:<id>|<name>]` parses to the person,
// reads as `@name` wherever the body is shown as text, and survives a
// name with a `]` in it. Picking someone in the composer writes that
// token when mentions are on, and the plain `@name` when they are off.
import 'package:deskilo/features/workspace/domain/member_note_refs.dart';
import 'package:deskilo/features/workspace/presentation/widgets/member_note_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ana = '0b8e3c1a-1111-4c2b-9a77-5d0e1f2a3b4c';

void main() {
  test('a mention parses to the person and reads as @name', () {
    final body = 'see ${mentionToken(_ana, 'Ana Lima')} at noon';
    final mention = parseNoteBody(body).whereType<NoteMention>().single;
    expect(mention.id, _ana);
    expect(mention.name, 'Ana Lima');
    expect(notePlainText(body), 'see @Ana Lima at noon');
    expect(notePreview(body), 'see @Ana Lima at noon');
    expect(mentionedIds(body), {_ana});
  });

  test('a bracket in a name cannot break the token', () {
    final token = mentionToken(_ana, 'Ana ]Lima');
    expect(parseNoteBody(token).single, isA<NoteMention>());
  });

  Future<String> pick(WidgetTester tester, {required bool tokens}) async {
    String? sent;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MemberNoteComposer(
              autofocus: false,
              referencesAllowed: false,
              mentionCandidates: const [(id: _ana, name: 'Ana')],
              mentionTokens: tokens,
              onSend: (body) async {
                sent = body;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('member-note-mention')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mention-Ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();
    return sent!;
  }

  testWidgets('picking someone writes a mention of them', (tester) async {
    expect(
      (await pick(tester, tokens: true)).trim(),
      mentionToken(_ana, 'Ana'),
    );
  });

  testWidgets('with mentions off it stays the plain @name', (tester) async {
    expect((await pick(tester, tokens: false)).trim(), '@Ana');
  });
}
