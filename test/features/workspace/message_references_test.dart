// SPDX-License-Identifier: 0BSD
//
// #842 — a message can point at an alert, at the validation trail behind
// one, and at the financial documents people argue about. And every
// picker filters: both original ones were flat lists of everything,
// which is fine with four members and unusable with forty.
import 'package:deskilo/features/workspace/domain/member_note_refs.dart';
import 'package:deskilo/features/workspace/presentation/widgets/ref_picker_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<RefCandidate> _many(int count) => [
      for (var i = 0; i < count; i++)
        refCandidate(
          id: 'c$i',
          label: i.isEven ? 'Seat A$i' : 'Desk B$i',
          detail: 'level ${i % 3}',
          icon: Icons.chair_outlined,
        ),
    ];

Future<String?> _openPicker(
  WidgetTester tester,
  List<RefCandidate> candidates,
) async {
  String? picked;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              picked = await showRefPicker(
                context,
                title: 'Which one?',
                candidates: candidates,
                keyPrefix: 'pick',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  group('the token grammar', () {
    test('every new kind round-trips through the parser', () {
      for (final kind in NoteRecordKind.values) {
        final body = 'see ${recordToken(kind, 'abc-123', 'The thing')} please';
        final segments = parseNoteBody(body);
        final ref = segments.whereType<NoteRecordRef>().single;
        expect(ref.kind, kind);
        expect(ref.id, 'abc-123');
        expect(ref.label, 'The thing');
        expect(notePlainText(body), 'see The thing please');
      }
    });

    test('a reference reads as its label in the list preview', () {
      final body = '${recordToken(NoteRecordKind.invoice, 'inv-9', 'INV-42')} '
          'is wrong';
      expect(notePreview(body), 'INV-42 is wrong');
    });

    test('a label carrying a closing bracket cannot break the token', () {
      final body = recordToken(NoteRecordKind.alert, 'evt-1', 'a]b');
      expect(parseNoteBody(body).whereType<NoteRecordRef>().single.label,
          'a)b');
    });

    test('an unknown kind stays plain text rather than losing the words',
        () {
      const body = 'see [ref:teapot:abc-123|The thing] please';
      expect(parseNoteBody(body).whereType<NoteRecordRef>(), isEmpty);
      expect(notePlainText(body), body);
    });

    test('the older reservation and space tokens are untouched', () {
      final body = '${reservationToken('res-1', 'Mine')} and '
          '${recordToken(NoteRecordKind.payment, '2026-03', 'March')}';
      final segments = parseNoteBody(body);
      expect(segments.whereType<NoteReservationRef>().single.id, 'res-1');
      expect(segments.whereType<NoteRecordRef>().single.id, '2026-03');
    });
  });

  group('the picker filters', () {
    testWidgets('a short list shows no filter at all', (tester) async {
      await _openPicker(tester, _many(4));
      expect(find.byKey(const Key('pick-filter')), findsNothing);
      expect(find.byKey(const Key('pick-c0')), findsOneWidget);
    });

    testWidgets('a long list filters as you type and says how much of it '
        'you are seeing', (tester) async {
      await _openPicker(tester, _many(20));
      expect(find.byKey(const Key('pick-filter')), findsOneWidget);
      expect(find.text('20 of 20'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pick-filter')), 'desk');
      await tester.pumpAndSettle();
      expect(find.text('10 of 20'), findsOneWidget);
      expect(find.byKey(const Key('pick-c0')), findsNothing);
      expect(find.byKey(const Key('pick-c1')), findsOneWidget);
    });

    testWidgets('every word must match, in any order', (tester) async {
      await _openPicker(tester, _many(20));
      await tester.enterText(
          find.byKey(const Key('pick-filter')), 'b7 desk');
      await tester.pumpAndSettle();
      expect(find.text('1 of 20'), findsOneWidget);
      expect(find.byKey(const Key('pick-c7')), findsOneWidget);
    });

    testWidgets('a filter that matches nothing says so, and is not an '
        'empty list', (tester) async {
      await _openPicker(tester, _many(20));
      await tester.enterText(
          find.byKey(const Key('pick-filter')), 'nothing here');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pick-empty')), findsOneWidget);
    });

    testWidgets('the detail line is searchable too', (tester) async {
      await _openPicker(tester, _many(20));
      await tester.enterText(find.byKey(const Key('pick-filter')), 'level 2');
      await tester.pumpAndSettle();
      // Every third candidate sits on level 2.
      expect(find.text('7 of 20'), findsOneWidget);
    });
  });
}
