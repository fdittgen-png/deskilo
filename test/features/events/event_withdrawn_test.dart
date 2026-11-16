// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4140 — a payment declaration its declarer took back is ended as
// `withdrawn` (0800): the app reads that status as itself, never as an
// unknown one, and the event's row names it in five languages.
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/widgets/events_filter_bar.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the status a taken-back declaration ends in is read as itself', () {
    expect(EventStatus.fromDb('withdrawn'), EventStatus.withdrawn);
    expect(EventStatus.fromDb('pending'), EventStatus.pending);
  });

  for (final (locale, word) in [
    (const Locale('en'), 'Taken back'),
    (const Locale('fr'), 'Retiré'),
    (const Locale('de'), 'Zurückgenommen'),
    (const Locale('es'), 'Retirado'),
    (const Locale('it'), 'Ritirato'),
  ]) {
    testWidgets('a taken-back declaration names its status in $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  eventOutcomeMark(context, EventStatus.withdrawn)!,
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel(word), findsOneWidget);
      expect(find.byTooltip(word), findsOneWidget);
      semantics.dispose();
    });
  }
}
