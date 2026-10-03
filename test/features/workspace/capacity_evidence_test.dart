// SPDX-License-Identifier: AGPL-3.0-or-later
// Period meaning and freshness remain visible in every locale at narrow
// width and large text; missing data never acquires a capacity balance.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/presentation/widgets/capacity_evidence.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SeatCapacityKpi fixture(
  DateTime from,
  DateTime to, {
  Set<KpiQuality> quality = const {},
}) => SeatCapacityKpi(
  from: from,
  to: to,
  physicalSeatHours: 100,
  offeredSeatHours: 80,
  reservedSeatHours: 20,
  reservedOutsideOfferedSeatHours: 0,
  overlappingSeatHours: 0,
  seats: 10,
  roomsWithoutSeats: 0,
  offeredRoomHours: 0,
  reservedRoomHours: 0,
  quality: quality,
  reasons: const [],
  computedAt: DateTime.utc(2026, 10, 3, 12),
);

Future<void> show(
  WidgetTester tester,
  SeatCapacityKpi kpi, {
  String locale = 'en',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: SingleChildScrollView(child: CapacityEvidence(kpi: kpi)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'past, current and future are distinguished without claiming attendance',
    (tester) async {
      WorkspaceTime.install('Europe/Paris');
      addTearDown(WorkspaceTime.reset);
      final periods = [
        (DateTime.utc(2026, 9), DateTime.utc(2026, 10), 'Past period'),
        (DateTime.utc(2026, 10), DateTime.utc(2026, 11), 'Current period'),
        (DateTime.utc(2026, 11), DateTime.utc(2026, 12), 'Future period'),
      ];
      for (final (from, to, label) in periods) {
        await show(tester, fixture(from, to));
        expect(find.textContaining(label), findsOneWidget);
        expect(find.textContaining('not actual attendance'), findsOneWidget);
        expect(
          find.textContaining('60.0 unreserved seat-hours'),
          findsOneWidget,
        );
        expect(find.textContaining('20.0 blocked seat-hours'), findsOneWidget);
        expect(find.textContaining('14:00'), findsOneWidget);
      }
      await show(
        tester,
        fixture(
          periods.first.$1,
          periods.first.$2,
          quality: {KpiQuality.unavailable},
        ),
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.textContaining('unreserved seat-hours'), findsNothing);
    },
  );

  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$locale at 360px and 200% text keeps the evidence readable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await show(
        tester,
        fixture(
          DateTime.utc(2026, 10),
          DateTime.utc(2026, 11),
          quality: {KpiQuality.partial, KpiQuality.stale},
        ),
        locale: locale,
      );
      expect(
        find.byKey(const ValueKey('capacity-data-quality')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('capacity-computed-at')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
