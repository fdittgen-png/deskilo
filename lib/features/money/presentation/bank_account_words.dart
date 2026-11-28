// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- what a refusal of a bank account, or of an import into one, says.
import '../../../l10n/app_localizations.dart';
import '../domain/bank/bank_account.dart';

/// The words for [refused]; [account] is the account the import or the edit was about, when there is one.
String bankAccountRefusalText(AppLocalizations l10n, BankAccountRefused refused, {BankAccount? account}) =>
    switch (refused.reason) {
      BankAccountRefusal.none => l10n.bankAccountRefusedNone,
      BankAccountRefusal.otherAccount => l10n.bankAccountRefusedOther(refused.name, account?.name ?? ''),
      BankAccountRefusal.currency => account == null
          ? l10n.bankAccountRefusedCurrencyKept
          : l10n.bankAccountRefusedCurrency(account.name, account.currency),
      BankAccountRefusal.name => l10n.bankAccountRefusedName,
      BankAccountRefusal.iban => l10n.bankAccountRefusedIban,
      BankAccountRefusal.taken => l10n.bankAccountRefusedTaken(refused.name),
      BankAccountRefusal.bookAccount => l10n.bankAccountRefusedBookAccount,
      BankAccountRefusal.other => l10n.bankImportFailed,
    };
