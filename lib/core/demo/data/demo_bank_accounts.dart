// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- the Demo's bank accounts, in memory beside its statements: the account the Demo's notification files are
// of (the IBAN they name), so its statements are imported into it; the reconciliation report's account is under a
// name no account carries, so the Demo shows a name to attach. The same rules as the server's (0988): every name an
// account is known by is its own, and an account known by a name takes on the statements under it.
import '../../../features/money/domain/bank/bank_account.dart';
import 'bank_statement_repository.dart';

/// The one account store of a space's statements.
final _stores = Expando<FakeBankAccountRepository>('demo bank accounts');
FakeBankAccountRepository demoBankAccountsOf(FakeBankStatementRepository bank) => _stores[bank] ??= FakeBankAccountRepository(bank);

/// The IBAN the Demo's statements name.
const demoBankIban = 'CH9300762011623852957';

class FakeBankAccountRepository implements BankAccountRepository {
  FakeBankAccountRepository(this._bank) {
    final of = _bank.statements.where((s) => bankAccountKey(s.account) == demoBankIban);
    if (of.isNotEmpty) {
      _accounts['demo-bank-account-1'] =
          BankAccount(id: 'demo-bank-account-1', name: 'Postfinance', iban: demoBankIban, currency: of.first.currency);
    }
  }

  final FakeBankStatementRepository _bank;
  final _accounts = <String, BankAccount>{};
  var _next = 2;

  @override
  Future<List<BankAccount>> accounts(String workspaceId) async =>
      [..._accounts.values]..sort((a, b) => a.archived == b.archived ? a.name.compareTo(b.name) : (a.archived ? 1 : -1));

  @override
  Future<({String id, int attached})> save(String workspaceId, BankAccount account) async {
    if (account.name.trim().isEmpty || account.name.trim().length > 64) throw const BankAccountRefused(BankAccountRefusal.name);
    final iban = bankAccountKey(account.iban);
    if (iban.isNotEmpty && !RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$').hasMatch(iban)) {
      throw const BankAccountRefused(BankAccountRefusal.iban);
    }
    final id = account.id.isEmpty ? 'demo-bank-account-${_next++}' : account.id;
    final saved = BankAccount(
      id: id,
      name: account.name.trim(),
      iban: iban,
      identifiers: account.identifiers,
      aliases: account.aliases,
      currency: account.currency,
      bookAccountId: account.bookAccountId,
      archived: account.archived,
    );
    for (final other in _accounts.values) {
      if (other.id == id || other.archived) continue;
      final taken = saved.keys.intersection(other.keys);
      if (taken.isNotEmpty) throw BankAccountRefused(BankAccountRefusal.taken, name: taken.first);
    }
    final before = (await unattached(workspaceId)).fold<int>(0, (n, u) => n + u.statements);
    _accounts[id] = saved;
    final after = (await unattached(workspaceId)).fold<int>(0, (n, u) => n + u.statements);
    return (id: id, attached: before - after);
  }

  @override
  Future<bool> archive(String workspaceId, String accountId) async {
    final a = _accounts[accountId];
    if (a == null || a.archived) return false;
    _accounts[accountId] = BankAccount(
      id: a.id,
      name: a.name,
      iban: a.iban,
      identifiers: a.identifiers,
      aliases: a.aliases,
      currency: a.currency,
      bookAccountId: a.bookAccountId,
      archived: true,
    );
    return true;
  }

  @override
  Future<List<UnattachedBankName>> unattached(String workspaceId) async {
    final counts = <(String, String), int>{};
    for (final s in _bank.statements) {
      final known = _accounts.values.any((a) => !a.archived && a.currency == s.currency && a.knownBy(s.account));
      if (!known) counts.update((s.account, s.currency), (n) => n + 1, ifAbsent: () => 1);
    }
    return [
      for (final e in counts.entries) UnattachedBankName(name: e.key.$1, currency: e.key.$2, statements: e.value),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }
}
