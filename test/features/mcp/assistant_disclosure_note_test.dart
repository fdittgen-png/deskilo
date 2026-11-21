// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4205 -- what connecting an assistant discloses is said before the
// authorization, on the screens the person already uses: its answers are
// processed by the assistant's provider under its own terms, self-hosting does
// not make that local, revoking stops future requests without recalling what
// was received, and the privacy notice opens from the note. The note asks for
// nothing and grants nothing: it has no checkbox and no action of its own.
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/features/mcp/presentation/assistant_disclosure_note.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets('the note says who processes what, what self-hosting does not '
      'change and what revoking does not undo, in the reader\'s language', (
    tester,
  ) async {
    final en = AppLocalizationsEn();
    await pumpApp(
      tester,
      const Scaffold(body: AssistantDisclosureNote()),
      overrides: standardTestOverrides(),
    );
    expect(find.text(en.assistantFlowsBody), findsOneWidget);
    for (final phrase in [
      'processed by the company that provides it',
      'self-hosting Deskilo does not make that processing local',
      'does not delete what the assistant already received',
    ]) {
      expect(en.assistantFlowsBody, contains(phrase));
    }
    expect(find.byType(Checkbox), findsNothing, reason: 'it asks no consent');

    await pumpApp(
      tester,
      const Scaffold(body: AssistantDisclosureNote()),
      overrides: standardTestOverrides(),
      locale: const Locale('fr'),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsFr().assistantFlowsBody), findsOneWidget);
  });

  testWidgets('the privacy notice opens from the note and nothing else '
      'happens', (tester) async {
    final opened = <Uri>[];
    await pumpApp(
      tester,
      const Scaffold(body: AssistantDisclosureNote()),
      overrides: [
        ...standardTestOverrides(),
        linkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('assistant-disclosure-link')));
    await tester.pump();
    expect(opened, [Uri.parse(kPrivacyPolicyPageUrl)]);
  });
}
