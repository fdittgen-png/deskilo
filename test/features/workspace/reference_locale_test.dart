// SPDX-License-Identifier: 0BSD
//
// #1179 — a message reference is written ONCE, in the workspace's
// language.
//
// The `[res:<id>|<label>]` grammar bakes a human label into the message
// body and never re-renders it. That is deliberate — it is what lets a
// since-deleted reservation still read as text, and what keeps a busy
// conversation from doing a lookup per reference — and it has one
// consequence the app got wrong: whatever language the label is written
// in, every reader of that conversation gets it, for ever.
//
// It used to be the SENDER'S DEVICE language, which is nobody's
// agreement. An English-speaking workspace was shown "31 août" because
// the person who happened to send the message held a French phone.
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/features/workspace/presentation/reference_locale.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Pezenas Cowork',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'GOODCODE22',
);

/// Pump one probe widget on a device set to [device], in a workspace
/// whose language is [workspaceLocale], and read back what a reference
/// composed there would be baked in.
Future<(String?, AppLocalizations?)> probe(
  WidgetTester tester, {
  required String device,
  required String workspaceLocale,
}) async {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] =
      _workspace.copyWith(defaultLocale: workspaceLocale);
  String? locale;
  AppLocalizations? strings;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: repo),
      child: MaterialApp(
        locale: Locale(device),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            // The composer is opened long after the workspace loaded;
            // this probe has to wait for it too, and the helpers read
            // rather than watch.
            ref.watch(currentWorkspaceProvider);
            locale = referenceLocale(ref, context);
            strings = referenceL10n(ref, context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (locale, strings);
}

void main() {
  testWidgets('the workspace language wins over the sender\'s phone',
      (tester) async {
    final (locale, strings) =
        await probe(tester, device: 'fr', workspaceLocale: 'en');
    expect(locale, 'en',
        reason: 'the date in the frozen label is the workspace\'s');
    expect(strings?.noteRefPayment, 'Payment',
        reason: 'so is the translated noun beside it');
  });

  testWidgets('and the other way round — nothing about this favours '
      'English', (tester) async {
    final (locale, strings) =
        await probe(tester, device: 'en', workspaceLocale: 'fr');
    expect(locale, 'fr');
    expect(strings?.noteRefPayment, isNot('Payment'));
  });

  testWidgets('a workspace that never chose one falls back to the '
      'sender', (tester) async {
    final (locale, strings) =
        await probe(tester, device: 'de', workspaceLocale: '');
    expect(locale, startsWith('de'),
        reason: 'the old behaviour, for the one case with nothing better');
    expect(strings?.localeName, 'de');
  });

  testWidgets('a language the app does not ship reads in the sender\'s',
      (tester) async {
    final (_, strings) =
        await probe(tester, device: 'en', workspaceLocale: 'pt');
    expect(strings?.noteRefPayment, 'Payment',
        reason: 'lookupAppLocalizations throws on an unsupported locale — '
            'a workspace language the app never shipped must not take '
            'the composer down with it');
  });
}
