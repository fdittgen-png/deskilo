// SPDX-License-Identifier: 0BSD
//
// #1177 — the form's hints are written in the person of their SUBJECT.
// The same widget serves my own profile and a managed member's, and
// "printed before your name" is wrong on the second one.
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/presentation/widgets/personal_info_form.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpForm(WidgetTester tester, {required bool managed}) =>
    tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PersonalInfoForm(
            initial: const PersonalInfo(),
            managed: managed,
            onSave: (_) async {},
          ),
        ),
      ),
    ));

void main() {
  testWidgets('my own profile speaks to me', (tester) async {
    await pumpForm(tester, managed: false);
    expect(find.textContaining('before your name'), findsOneWidget);
    expect(find.textContaining('before their name'), findsNothing);
  });

  testWidgets('a managed profile speaks about somebody else', (tester) async {
    await pumpForm(tester, managed: true);
    expect(find.textContaining('before their name'), findsOneWidget);
    expect(find.textContaining('before your name'), findsNothing);
  });
}
