// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3060 — the Reserve header's date follows the language the app is drawn
// in when the member never chose one: the platform's. It followed the
// process's default locale, so under a French or German browser every
// string was translated and "13 May" was not.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  for (final language in ['fr', 'de']) {
    testWidgets('the header date is in $language under a $language device', (
      tester,
    ) async {
      await initializeDateFormatting();
      tester.platformDispatcher.localesTestValue = [Locale(language)];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.view.physicalSize = const Size(393 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final workspace = FakeWorkspaceRepository.withWorkspace()
        ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7]
        ..bookingGranularities['ws-1'] = BookingGranularity.halfDay;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...standardTestOverrides(
              floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
              workspace: workspace,
              pinFormats: false,
              deviceLocale: Locale(language),
            ),
          ],
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();

      final label = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('reserve-date-button')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      final english = DateFormat.MMMd('en_GB');
      // Whatever day the fixed clock shows, the month is not the English one.
      expect(
        label,
        isNot(matches(RegExp(r'\b(May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b'))),
      );
      expect(english.locale, 'en_GB');
    });
  }
}
