// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#2211): the people I blocked are listed in Me with their names,
// and Unblock is the way back — it calls the server and the list follows.
import 'package:deskilo/features/me/presentation/blocked_people_card.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('blocked people are listed and can be unblocked', (tester) async {
    final messenger = FakeMessengerRepository()..blocked['u-ana'] = 'Ana';
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(messenger: messenger),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: BlockedPeopleCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Blocked people'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('me-blocked-people')));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unblock-u-ana')));
    await tester.pumpAndSettle();
    expect(messenger.blocked, isEmpty);
    expect(find.text('Ana'), findsNothing);
    expect(find.text('You have not blocked anyone.'), findsOneWidget);
  });
}
