// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/expense_repository.dart';
import '../domain/export_year.dart';
import '../domain/invoice.dart';
import '../domain/member_account_queries.dart';

/// The books of one fiscal year as the accounting export holds them:
/// the workspace's ledger and repartitions are fetched whole and cut to
/// [year] (#2365), so a 2026 file carries no 2024 expense.
Future<ExportYearBooks> exportYearBooks(
  MemberAccountQueries accounts,
  ExpenseRepository repo,
  String workspaceId,
  int year,
  List<Invoice> invoices,
) async => exportYearScope(
  year,
  invoices: invoices,
  ledger: await accounts.fetchWorkspaceLedger(workspaceId),
  repartitions: await repo.fetchExpenseRepartitions(workspaceId),
);
