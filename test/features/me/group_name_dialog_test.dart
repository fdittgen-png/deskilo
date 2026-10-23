// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The dialog that names one of my groups owns its text controller and
// disposes it when it closes, whichever way it closes; it pops the name
// typed, or null when cancelled.
import 'package:deskilo/features/me/presentation/group_name_dialog.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Opens the dialog over a bare app; the record keeps the dialog's answer
/// a future of its own until the test closes it.
Future<({Future<String?> answer})> _open(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  final answer = showDialog<String>(
    context: context,
    builder: (_) => const GroupNameDialog(initial: 'Travel'),
  );
  await tester.pumpAndSettle();
  return (answer: answer);
}

void main() {
  LeakTesting.enable();
  LeakTracking.warnForUnsupportedPlatforms = false;

  testWidgets('save pops the name typed and leaves no controller behind', (
    tester,
  ) async {
    final (:answer) = await _open(tester);
    expect(find.text('Travel'), findsOneWidget, reason: 'the current name');
    await tester.enterText(
      find.byKey(const ValueKey('me-group-name-field')),
      'Trips',
    );
    await tester.tap(find.byKey(const ValueKey('me-group-save')));
    await tester.pumpAndSettle();
    expect(await answer, 'Trips');
  }, experimentalLeakTesting: LeakTesting.settings.withTrackedAll());

  testWidgets('cancel pops nothing and leaves no controller behind', (
    tester,
  ) async {
    final (:answer) = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('me-group-cancel')));
    await tester.pumpAndSettle();
    expect(await answer, isNull);
  }, experimentalLeakTesting: LeakTesting.settings.withTrackedAll());
}
