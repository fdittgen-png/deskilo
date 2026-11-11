// SPDX-License-Identifier: AGPL-3.0-or-later
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

  // #3281: the one Company field says it is the account-wide value.
  testWidgets('Company says it is the account-wide value', (tester) async {
    await pumpForm(tester, managed: false);
    expect(find.text('Company (optional)'), findsOneWidget);
    expect(
      find.text('Applies to your whole account, not to one workspace.'),
      findsOneWidget,
    );
    await pumpForm(tester, managed: true);
    expect(find.textContaining('whole account'), findsNothing);
  });
}
