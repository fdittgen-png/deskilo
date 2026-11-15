// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4072 -- registering a directory server is an operator's action: Discover's
// bar keeps the list/map switch and carries no icon for it; the action is
// behind "Advanced" with its full label and still opens the same dialog.
import 'package:deskilo/core/backend/personal_home_providers.dart';
import 'package:deskilo/core/backend/reference_backend.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/presentation/directory_link_dialog.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(WidgetTester tester, {bool signedIn = true}) async {
  final directory = FakeDirectoryRepository();
  await pumpApp(
    tester,
    const DirectoryScreen(),
    size: const Size(390, 1600),
    overrides: [
      ...standardTestOverrides(
        auth: signedIn ? FakeAuthRepository.signedIn() : FakeAuthRepository(),
        directory: directory,
      ),
      personalEndpointProvider.overrideWithValue(referenceEndpoint),
      directoryHomeProvider.overrideWith((ref) async => referenceEndpoint),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  final en = AppLocalizationsEn();

  testWidgets('the bar has no register-server icon; Advanced holds the action '
      'with its full label', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.add_business_outlined), findsNothing);
    expect(_key('directory-portal-register-directory'), findsNothing);
    expect(find.byTooltip(en.settingsSectionAdvanced), findsOneWidget);

    await tester.tap(_key('directory-advanced'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.portalRegisterDirectory), findsOneWidget);
    expect(_key('directory-portal-register-directory'), findsOneWidget);
  });

  testWidgets('choosing it opens the directory server dialog', (tester) async {
    await _pump(tester);
    await tester.tap(_key('directory-advanced'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(en.portalRegisterDirectory));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(DirectoryLinkDialog), findsOneWidget);
  });

  testWidgets('signed out, the bar offers no Advanced menu', (tester) async {
    await _pump(tester, signedIn: false);
    expect(_key('directory-advanced'), findsNothing);
  });
}
