// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_invoice_queries.dart';
import '../data/supabase_member_account_queries.dart';
import '../data/supabase_report_template_repository.dart';
import '../domain/invoice_queries.dart';
import '../domain/member_account_queries.dart';
import '../domain/report_template_repository.dart';

part 'money_queries_providers.g.dart';

/// #2591 C1 — the invoice reads on their own: a consumer that only reads
/// invoices depends on this and on nothing else of the money boundary.
@Riverpod(keepAlive: true)
InvoiceQueries invoiceQueries(Ref ref) =>
    SupabaseInvoiceQueries(Supabase.instance.client);

/// #2591 C1 — the member's account, statement, ledger and usage reads.
@Riverpod(keepAlive: true)
MemberAccountQueries memberAccountQueries(Ref ref) =>
    SupabaseMemberAccountQueries(Supabase.instance.client);

/// #2591 C2 — the report template and image library: the preview and the
/// editor depend on this and on nothing else of the money boundary.
@Riverpod(keepAlive: true)
ReportTemplateRepository reportTemplateRepository(Ref ref) =>
    SupabaseReportTemplateRepository(Supabase.instance.client);
