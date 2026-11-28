// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- a bank account of the business (`bank_accounts`, migration 0988): the account a statement is imported into,
// with the names it is known by (its name, its IBAN, other identifiers, aliases), its currency and the ledger account it
// books to. A statement imported under a name no account carries yet is an [UnattachedBankName] until an account is
// known by it. Pure Dart.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:meta/meta.dart';

/// A name as an account is matched by it: upper case, without its spaces (an IBAN in groups of four is the IBAN).
String bankAccountKey(String name) => name.replaceAll(RegExp(r'\s+'), '').toUpperCase();

@immutable
class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    required this.currency,
    this.iban = '',
    this.identifiers = const [],
    this.aliases = const [],
    this.bookAccountId,
    this.archived = false,
  });

  /// A row of `bank_accounts`.
  factory BankAccount.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank_accounts');
    List<String> list(String key) => [for (final v in (r.json[key] as List<Object?>? ?? const [])) if (v is String) v];
    return BankAccount(
      id: r.string('id'),
      name: r.string('name'),
      currency: r.string('currency'),
      iban: r.stringOr('iban'),
      identifiers: list('identifiers'),
      aliases: list('aliases'),
      bookAccountId: r.stringOrNull('book_account_id'),
      archived: r.boolOr('archived', fallback: false),
    );
  }

  final String id;
  final String name;
  final String currency;
  final String iban;
  final List<String> identifiers;
  final List<String> aliases;
  final String? bookAccountId;
  final bool archived;

  /// Every name the account is known by, as keys.
  Set<String> get keys => {
    for (final n in [name, iban, ...identifiers, ...aliases])
      if (bankAccountKey(n).isNotEmpty) bankAccountKey(n),
  };

  /// Whether a statement imported under [name] is of this account.
  bool knownBy(String name) => keys.contains(bankAccountKey(name));
}

/// A name statements were imported under that no account carries yet.
@immutable
class UnattachedBankName {
  const UnattachedBankName({required this.name, required this.currency, required this.statements});

  factory UnattachedBankName.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank_import_names_unattached');
    return UnattachedBankName(name: r.string('name'), currency: r.string('currency'), statements: r.integer('statements'));
  }

  final String name;
  final String currency;
  final int statements;
}

/// Why the server refused an account or an import into one (0988: DKL02 / DKB03 with its reason).
enum BankAccountRefusal { name, iban, currency, taken, bookAccount, none, otherAccount, other }

class BankAccountRefused implements Exception {
  const BankAccountRefused(this.reason, {this.name = ''});

  final BankAccountRefusal reason;

  /// The name another account is known by (taken) or the file names (another account).
  final String name;

  @override
  String toString() => 'BankAccountRefused($reason, $name)';
}

/// The bank accounts of a business, read and written.
abstract interface class BankAccountRepository {
  /// The accounts, active first, by name.
  Future<List<BankAccount>> accounts(String workspaceId);

  /// Creates ([BankAccount.id] empty) or changes an account; answers its id and how many statements it took on.
  Future<({String id, int attached})> save(String workspaceId, BankAccount account);

  /// Archives an account: its statements keep it, it is offered no more.
  Future<bool> archive(String workspaceId, String accountId);

  /// The names statements were imported under that no account carries yet.
  Future<List<UnattachedBankName>> unattached(String workspaceId);
}
