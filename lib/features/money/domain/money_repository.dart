// SPDX-License-Identifier: AGPL-3.0-or-later
import 'billing_rules_repository.dart';
import 'commercial_terms_repository.dart';
import 'document_numbering.dart';
import 'dunning_repository.dart';
import 'einvoice_transmissions.dart';
import 'expense_repository.dart';
import 'invoice_commands.dart';
import 'invoice_queries.dart';
import 'member_account_commands.dart';
import 'member_account_queries.dart';
import 'payment_gateway_repository.dart';
import 'report_template_repository.dart';
import 'tax_reporting_repository.dart';

export 'command_receipt.dart';
export 'invoice_action_commands.dart';

/// Compatibility facade (#2591): it is the sum of the narrow money ports
/// (invoice and account reads and commands, report templates, tax
/// reporting, commercial terms, expenses, dunning, billing rules, document
/// numbering, online payments, e-invoice transmission) and declares
/// nothing of its own. It gets NO new methods — product code depends on
/// the narrow port it needs; the in-memory fake keeps implementing this
/// so one store answers every port in the tests.
///
/// Money boundary (spec §7). Payments are only *recorded* — the pending
/// event created by [MemberAccountCommands.recordPayment] must be confirmed
/// by the other side before a ledger credit exists.
abstract class MoneyRepository implements
        InvoiceQueries,
        MemberAccountQueries,
        MemberAccountCommands,
        ReportTemplateRepository,
        InvoiceCommands,
        TaxReportingRepository,
        CommercialTermsRepository,
        ExpenseRepository,
        DunningRepository,
        BillingRulesRepository,
        DocumentNumbering,
        PaymentGatewayRepository,
        EInvoiceTransmissions {}
