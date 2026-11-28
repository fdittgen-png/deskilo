// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- the bank accounts on the server: the rows of `bank_accounts` the person may read, and the functions of 0987
// that write them. A refusal comes back as its reason (BankAccountRefused); anything else is the read's failure.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/data/app_failure_from.dart';
import '../../../core/data/paged_fetch.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/bank/bank_records.dart';

/// The reason of a refusal of 0987, or null when it is none of its own.
BankAccountRefused? bankAccountRefusalOf(Object error) {
  final failure = appFailureFrom(error);
  if (failure is! Refusal || (failure.code != DkCode.dkl02 && failure.code != DkCode.dkb03)) return null;
  var reason = '', name = '';
  final details = failure.details;
  if (details != null) {
    try {
      final r = JsonReader.orEmpty(jsonDecode(details), context: 'bank account refusal');
      reason = r.stringOr('reason');
      name = r.stringOr('name');
    } on Object catch (e, st) {
      TraceLogger.instance.log(
        TraceLevel.info,
        'money',
        'a bank account refusal without its reason',
        error: e,
        stackTrace: st,
      );
    }
  }
  final kind = switch (reason) {
    'name' => BankAccountRefusal.name,
    'iban' => BankAccountRefusal.iban,
    'currency' => BankAccountRefusal.currency,
    'taken' => BankAccountRefusal.taken,
    'book_account' => BankAccountRefusal.bookAccount,
    'bank_account' => BankAccountRefusal.none,
    'other_account' => BankAccountRefusal.otherAccount,
    _ => null,
  };
  return kind == null ? null : BankAccountRefused(kind, name: name);
}

class SupabaseBankAccountRepository implements BankAccountRepository {
  const SupabaseBankAccountRepository(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'money', 'a bank account command ($fn)', error: e, stackTrace: st);
      final refused = bankAccountRefusalOf(e);
      if (refused == null) rethrow;
      Error.throwWithStackTrace(refused, st);
    }
  }

  @override
  Future<List<BankAccount>> accounts(String workspaceId) async {
    final rows = await fetchConfigurationList(
      table: 'bank_accounts',
      build: () => _client
          .from('bank_accounts')
          .select('id, name, iban, identifiers, aliases, currency, book_account_id, archived')
          .eq('workspace_id', workspaceId)
          .order('archived', ascending: true)
          .order('name', ascending: true)
          .order('id', ascending: true),
    );
    return [for (final row in rows) BankAccount.fromJson(row)];
  }

  @override
  Future<({String id, int attached})> save(String workspaceId, BankAccount account) async {
    final r = JsonReader.of(
      await _call('save_bank_account_v1', {
        'p_workspace_id': workspaceId,
        'p_id': account.id.isEmpty ? null : account.id,
        'p_name': account.name,
        'p_iban': account.iban,
        'p_identifiers': account.identifiers,
        'p_aliases': account.aliases,
        'p_currency': account.currency,
        'p_book_account_id': account.bookAccountId,
      }),
      context: 'save_bank_account_v1',
    );
    return (id: r.string('id'), attached: r.integer('attached'));
  }

  @override
  Future<bool> archive(String workspaceId, String accountId) async =>
      await _call('archive_bank_account_v1', {'p_workspace_id': workspaceId, 'p_id': accountId}) == true;

  @override
  Future<List<UnattachedBankName>> unattached(String workspaceId) async {
    final rows = await _call('bank_import_names_unattached_v1', {'p_workspace_id': workspaceId});
    return [for (final row in rows is List ? rows : const <Object?>[]) UnattachedBankName.fromJson(row)];
  }
}
