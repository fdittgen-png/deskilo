// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3489 -- the doctor panel words its footer, the stuck-accounts title and
// the held phrase from the catalogue, in the member's language.
import 'package:deskilo/core/instance/instance_bundle_asset.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/features/profile/presentation/widgets/instance_doctor_panel.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  List<DoctorFinding> findings,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        instanceDoctorRunnerProvider.overrideWithValue((api, ref) async => findings),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InstanceDoctorPanel(api: FakeSupabaseManagement(), projectRef: 'abc'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('instance-doctor-run')));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final words = lookupAppLocalizations(locale);
    testWidgets('the footer, the plural title and the held phrase in ${locale.languageCode}',
        (tester) async {
      await _pump(tester, locale, [
        const DoctorFinding(
          DoctorLevel.alarm,
          '2 accounts cannot get in',
          'detail',
          count: 2,
          words: DoctorWords.stuckAccounts,
        ),
        const DoctorFinding(
          DoctorLevel.warn,
          'Installation roles not declared',
          'behaves as combined — 1 workspace, 2 members.',
          words: DoctorWords.installationHeld,
          facts: [1, 2],
        ),
      ]);
      expect(find.text(words.instanceDoctorStuckTitle(2)), findsOneWidget);
      expect(find.text(words.instanceDoctorNeedsHuman(2)), findsOneWidget);
      expect(
        find.textContaining(words.instanceDoctorHeld(1, 2)),
        findsOneWidget,
      );
    });

    testWidgets('a clean run says everything is healthy in ${locale.languageCode}',
        (tester) async {
      await _pump(tester, locale, const [
        DoctorFinding(DoctorLevel.ok, 'Site URL', 'matches'),
      ]);
      expect(find.text(words.instanceDoctorAllHealthy), findsOneWidget);
    });
  }
}
