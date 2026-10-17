// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_accounting_source_queries.dart';
import '../data/supabase_commercial_terms_repository.dart';
import '../data/supabase_expense_repository.dart';
import '../data/supabase_invoice_commands.dart';
import '../data/supabase_invoice_queries.dart';
import '../data/supabase_member_account_queries.dart';
import '../data/supabase_report_template_repository.dart';
import '../data/supabase_tax_reporting_repository.dart';
import '../domain/accounting_source_queries.dart';
import '../domain/commercial_terms_repository.dart';
import '../domain/expense_repository.dart';
import '../domain/invoice_commands.dart';
import '../domain/invoice_queries.dart';
import '../domain/member_account_queries.dart';
import '../domain/report_template_repository.dart';
import '../domain/tax_reporting_repository.dart';
import 'credit_providers.dart';

part 'money_queries_providers.g.dart';

/// #2591 C1 — the invoice reads on their own: a consumer that only reads
/// invoices depends on this and on nothing else of the money boundary.
@Riverpod(keepAlive: true)
InvoiceQueries invoiceQueries(Ref ref) =>
    SupabaseInvoiceQueries(ref.watch(moneyClientProvider));

/// #2591 C1 — the member's account, statement, ledger and usage reads.
@Riverpod(keepAlive: true)
MemberAccountQueries memberAccountQueries(Ref ref) =>
    SupabaseMemberAccountQueries(ref.watch(moneyClientProvider));

/// #2591 C2 — the report template and image library: the preview and the
/// editor depend on this and on nothing else of the money boundary.
@Riverpod(keepAlive: true)
ReportTemplateRepository reportTemplateRepository(Ref ref) =>
    SupabaseReportTemplateRepository(ref.watch(moneyClientProvider));

/// #2591 C3 — what a person does to an invoice: issue, void, remind,
/// regroup, settle a credit note, match a payment.
@Riverpod(keepAlive: true)
InvoiceCommands invoiceCommands(Ref ref) =>
    SupabaseInvoiceCommands(ref.watch(moneyClientProvider));

/// #2591 C3 — the workspace's VAT rates and returns.
@Riverpod(keepAlive: true)
TaxReportingRepository taxReportingRepository(Ref ref) =>
    SupabaseTaxReportingRepository(ref.watch(moneyClientProvider));

/// #2591 C4 — fee bands, subscription levels, services, packages and a
/// member's negotiated deal.
@Riverpod(keepAlive: true)
CommercialTermsRepository commercialTerms(Ref ref) =>
    SupabaseCommercialTermsRepository(ref.watch(moneyClientProvider));

/// #2591 C4 — the narrow legacy expense adapter (#2573 takes its source
/// bridge).
@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(Ref ref) =>
    SupabaseExpenseRepository(ref.watch(moneyClientProvider));

/// #2365 — the one fiscal source an accounting export reads.
@Riverpod(keepAlive: true)
AccountingSourceQueries accountingSourceQueries(Ref ref) =>
    SupabaseAccountingSourceQueries(ref.watch(moneyClientProvider));
