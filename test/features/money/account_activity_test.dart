// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: history shows every owned workspace and original currency; retry,
// pagination and logout must not lose records or expose another account's view.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/features/money/providers/account_activity_providers.dart';
import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/presentation/screens/account_activity_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

AccountActivity entry(int number, {String currency = 'EUR'}) => AccountActivity(
  id: '$number',
  workspaceId: 'workspace-$number',
  workspaceName: 'Office $number',
  occurredAt: DateTime.utc(2026, 9, 28).subtract(Duration(minutes: number)),
  reference: 'INV-$number',
  description: 'Desk use',
  currency: currency,
  status: 'issued',
  amountCents: 1200,
);

Future<void> showHistory(
  WidgetTester tester,
  FakeAccountActivityRepository repo,
  FakeAuthRepository auth,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(auth: auth, accountActivity: repo),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountActivityScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'foreign invoices remain visible when home and another server are offline',
    (tester) async {
      final auth = FakeAuthRepository.signedIn();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...standardTestOverrides(
              auth: auth,
              accountActivity: FakeAccountActivityRepository()
                ..unavailable = true,
              connectedSources: [
                for (final host in ['one', 'two'])
                  ConnectedInstallation(
                    endpoint: BackendEndpoint(
                      'https://$host.example',
                      'sb_publishable_fixture',
                    ),
                    account: host,
                    installationId: host,
                  ),
              ],
            ),
            connectedAccountActivityProvider(
              'https://one.example',
              AccountActivityKind.invoices,
            ).overrideWith((ref) async => [entry(99, currency: 'USD')]),
            connectedAccountActivityProvider(
              'https://two.example',
              AccountActivityKind.invoices,
            ).overrideWith((ref) async => throw StateError('offline')),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountActivityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Office 99'), findsOneWidget);
      expect(find.text('one.example'), findsOneWidget);
      expect(find.text('two.example'), findsOneWidget);
      expect(
        find.textContaining('This overview is incomplete.'),
        findsOneWidget,
      );
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Office 99'), findsNothing);
    },
  );

  testWidgets('payment preference is saved from the personal history screen', (
    tester,
  ) async {
    final preferences = FakePersonalPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          personalPreferences: preferences,
        ),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountActivityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AccountActivityKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Stripe').last);
    await tester.pumpAndSettle();
    expect(preferences.defaults['payment_provider'], 'stripe');
  });

  testWidgets('own workspaces retain currency and logout hides all history', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedIn();
    final repo = FakeAccountActivityRepository()
      ..records[AccountActivityKind.invoices] = [
        entry(1),
        entry(2, currency: 'USD'),
      ];
    await showHistory(tester, repo, auth);
    expect(find.text('Office 1'), findsOneWidget);
    expect(find.text('Office 2'), findsOneWidget);
    expect(find.textContaining('€'), findsOneWidget);
    expect(find.textContaining(r'$'), findsOneWidget);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Office 1'), findsNothing);
  });

  testWidgets('failure shows retry instead of an empty financial history', (
    tester,
  ) async {
    final repo = FakeAccountActivityRepository()..unavailable = true;
    await showHistory(tester, repo, FakeAuthRepository.signedIn());
    expect(find.text('No records to display.'), findsNothing);
    repo.unavailable = false;
    repo.records[AccountActivityKind.invoices] = [entry(7)];
    await tester.tap(
      find.text('Could not load your financial history. Tap to retry.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Office 7'), findsOneWidget);
  });

  test(
    'cursor includes every row with stable ordering and no duplicate boundary',
    () async {
      final repo = FakeAccountActivityRepository()
        ..records[AccountActivityKind.invoices] = [
          for (var i = 0; i < 51; i++) entry(i),
        ];
      final first = await repo.list(AccountActivityKind.invoices);
      final second = await repo.list(
        AccountActivityKind.invoices,
        before: first.last.cursor,
      );
      expect(first, hasLength(50));
      expect(second.single.id, '50');
    },
  );
}
