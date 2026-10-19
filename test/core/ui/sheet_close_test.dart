// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A sheet that fills the screen has no scrim to tap: every form sheet and the
// booking sheet carry their own way out, and leaving by it chooses, saves and
// sends nothing.
import 'package:deskilo/core/ui/app_sheet.dart';
import 'package:deskilo/core/ui/form_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(WidgetBuilder sheet, void Function(Object?) onClosed) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        key: const ValueKey('open'),
        onPressed: () async => onClosed(
          await showAppSheet<Object>(
            context: context,
            isScrollControlled: true,
            builder: sheet,
          ),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets('a form sheet closes by its own button and answers nothing', (tester) async {
    var closed = false;
    Object? answer = 'unset';
    await tester.pumpWidget(_app(
      (_) => const SheetShell(title: 'A form', children: [Text('a field')]),
      (a) {
        closed = true;
        answer = a;
      },
    ));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.text('A form'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('A form'), findsNothing);
    expect(closed, isTrue);
    expect(answer, isNull);
  });

  testWidgets('the booking sheet closes by its own button without booking', (tester) async {
    Object? answer = 'unset';
    await tester.pumpWidget(_app(
      (_) => BookingSheet(
        seatName: '23',
        start: DateTime(2026, 10, 19, 8),
        initialEnd: DateTime(2026, 10, 19, 17),
        cap: null,
        capped: false,
        timezone: 'Europe/Paris',
        resourceContext: const ['Space', '2nd floor'],
      ),
      (a) => answer = a,
    ));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-sheet-close')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsNothing);
    expect(answer, isNull);
  });
}
