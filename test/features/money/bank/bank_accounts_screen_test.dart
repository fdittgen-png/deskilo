// SPDX-License-Identifier: AGPL-3.0-or-later
// #4496 — Master data › Bank accounts on a phone and on a desk: the accounts are listed with their IBAN and currency;
// one is added through its sheet, the IBAN in groups of four; a refusal of the server is said under the sheet; the
// names earlier statements were imported under that no account carries are listed, and one is added to an account's
// names, which says how many statements it took on; an account is archived.
import 'package:deskilo/core/bank/bank_account.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/presentation/screens/bank_accounts_screen.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart'
    show bankAccountRepositoryProvider, currentWorkspaceProvider;
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

final _l10n = AppLocalizationsEn();
const _workspace = Workspace(
  id: 'ws-1',
  name: 'Atelier',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

class _Accounts implements BankAccountRepository {
  _Accounts(this.list, this.names);

  final List<BankAccount> list;
  final List<UnattachedBankName> names;
  final saved = <BankAccount>[];
  final archived = <String>[];
  BankAccountRefused? refuse;

  @override
  Future<List<BankAccount>> accounts(String workspaceId) async => list;

  @override
  Future<({String id, int attached})> save(String workspaceId, BankAccount account) async {
    if (refuse case final r?) throw r;
    saved.add(account);
    final attached = names.where((n) => account.knownBy(n.name)).fold<int>(0, (s, n) => s + n.statements);
    return (id: account.id.isEmpty ? 'new' : account.id, attached: attached);
  }

  @override
  Future<bool> archive(String workspaceId, String accountId) async {
    archived.add(accountId);
    return true;
  }

  @override
  Future<List<UnattachedBankName>> unattached(String workspaceId) async => names;
}

const _operating = BankAccount(id: 'a1', name: 'Operating', iban: 'FR7630006000011234567890189', currency: 'EUR');

Future<_Accounts> _pump(
  WidgetTester tester,
  Size size, {
  List<BankAccount> accounts = const [_operating],
  List<UnattachedBankName> names = const [],
}) async {
  final repo = _Accounts([...accounts], [...names]);
  await pumpApp(
    tester,
    const BankAccountsScreen(),
    size: size,
    overrides: [
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      bankAccountRepositoryProvider.overrideWithValue(repo),
      bookChartProvider.overrideWith((ref) async => (accounts: const <BookAccount>[], mappings: const <BookMapping>[])),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the accounts are listed; one is added through its sheet', (tester) async {
        final repo = await _pump(tester, size);
        expect(find.text('Operating'), findsOneWidget);
        expect(find.text('FR7630006000011234567890189 · EUR'), findsOneWidget);

        await _tap(tester, const ValueKey('bank-account-add'));
        await tester.enterText(
          find.descendant(of: find.byKey(const ValueKey('bank-account-name')), matching: find.byType(EditableText)),
          'Savings',
        );
        await tester.enterText(
          find.descendant(of: find.byKey(const ValueKey('bank-account-iban')), matching: find.byType(EditableText)),
          'DE89 3704 0044 0532 0130 00',
        );
        await tester.enterText(
          find.descendant(of: find.byKey(const ValueKey('bank-account-aliases')), matching: find.byType(EditableText)),
          'SPAR\n\n',
        );
        await _tap(tester, const ValueKey('bank-account-save'));
        expect(repo.saved.single.name, 'Savings');
        expect(repo.saved.single.iban, 'DE89 3704 0044 0532 0130 00', reason: 'the server keeps it without its spaces');
        expect(repo.saved.single.aliases, ['SPAR'], reason: 'one name per line, blank lines dropped');
        expect(repo.saved.single.currency, 'EUR', reason: "the business's currency by default");
        expect(find.text(_l10n.bankAccountSaved(0)), findsOneWidget);
      });

      testWidgets("a refusal of the server is said under the sheet's buttons", (tester) async {
        final repo = await _pump(tester, size);
        repo.refuse = const BankAccountRefused(BankAccountRefusal.taken, name: 'OPERATING');
        await _tap(tester, const ValueKey('bank-account-add'));
        await tester.enterText(
          find.descendant(of: find.byKey(const ValueKey('bank-account-name')), matching: find.byType(EditableText)),
          'operating',
        );
        await _tap(tester, const ValueKey('bank-account-save'));
        expect(find.text(_l10n.bankAccountRefusedTaken('OPERATING')), findsOneWidget);
      });

      testWidgets("a name no account carries is listed and added to an account's names", (tester) async {
        final repo = await _pump(
          tester,
          size,
          names: const [UnattachedBankName(name: 'OLD BANK', currency: 'EUR', statements: 2)],
        );
        expect(find.text(_l10n.bankUnattachedRow('OLD BANK', 'EUR', 2)), findsOneWidget);
        await _tap(tester, const ValueKey('bank-unattached-assign-OLD BANK'));
        await _tap(tester, const ValueKey('bank-unattached-to-a1'));
        expect(repo.saved.single.aliases, ['OLD BANK']);
        expect(repo.saved.single.id, 'a1');
        expect(find.text(_l10n.bankAccountSaved(2)), findsOneWidget, reason: 'its statements are now of the account');
      });

      testWidgets('an account no longer used is archived; with none the page says so', (tester) async {
        final repo = await _pump(tester, size);
        await _tap(tester, const ValueKey('bank-account-archive-a1'));
        expect(repo.archived, ['a1']);
      });

      testWidgets('with no account the page says so', (tester) async {
        await _pump(tester, size, accounts: const []);
        expect(find.byKey(const ValueKey('bank-accounts-none')), findsOneWidget);
      });
    });
  }
}
