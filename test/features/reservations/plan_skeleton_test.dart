// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3068 — the invariant: while the plan loads, Reserve shows a still
// skeleton of it, never a spinner and never an animation.
import 'package:deskilo/features/reservations/presentation/widgets/plan_skeleton.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the loading plan is a still skeleton, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PlanSkeleton()),
      ),
    );
    expect(find.byKey(const ValueKey('reserve-plan-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
