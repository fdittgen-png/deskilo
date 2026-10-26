// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the bank statements of a space and the movements of each.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/settings/active_settings.dart';
import '../application/bank_import_commands.dart';
import '../data/supabase_bank_statement_repository.dart';
import '../domain/bank/bank_import_settings.dart';
import '../domain/bank/bank_records.dart';
import 'credit_providers.dart';

part 'bank_statement_providers.g.dart';

@Riverpod(keepAlive: true)
BankStatementRepository bankStatementRepository(Ref ref) =>
    SupabaseBankStatementRepository(ref.watch(moneyClientProvider));

@riverpod
BankImportCommands bankImportCommands(Ref ref) =>
    BankImportCommands(ref.watch(bankStatementRepositoryProvider));

/// The bounds a file is read under and the suggestion window, from the
/// active space's settings.
@riverpod
BankImportSettings bankImportSettings(Ref ref) =>
    BankImportSettings.fromSettings(ref.watch(activeSettingsProvider));

/// The statements of one space, newest period first.
@riverpod
Future<List<StoredBankStatement>> bankStatements(Ref ref, String workspaceId) =>
    ref.watch(bankStatementRepositoryProvider).fetchStatements(workspaceId);

/// The movements of one statement, in the file's order.
@riverpod
Future<List<StoredBankLine>> bankStatementLines(Ref ref, String statementId) =>
    ref.watch(bankStatementRepositoryProvider).fetchLines(statementId);
