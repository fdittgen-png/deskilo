// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- what is done to a business's bank accounts: one saved (made or changed), one archived, and a name earlier
// statements were imported under added to an account's names, so its statements are of that account.
import '../domain/bank/bank_records.dart';

class BankAccountCommands {
  const BankAccountCommands(this._repository);

  final BankAccountRepository _repository;

  /// Saves [account]; answers how many statements it took on (names now its own).
  Future<int> save(String workspaceId, BankAccount account) async =>
      (await _repository.save(workspaceId, account)).attached;

  Future<bool> archive(String workspaceId, String accountId) => _repository.archive(workspaceId, accountId);

  /// [account], known by one more [name]; answers how many statements it took on.
  Future<int> addName(String workspaceId, BankAccount account, String name) => save(
    workspaceId,
    BankAccount(
      id: account.id,
      name: account.name,
      iban: account.iban,
      identifiers: account.identifiers,
      aliases: [...account.aliases, name],
      currency: account.currency,
      bookAccountId: account.bookAccountId,
    ),
  );
}
