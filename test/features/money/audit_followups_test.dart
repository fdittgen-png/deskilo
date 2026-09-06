// SPDX-License-Identifier: 0BSD
//
// #953 / #954 / #955 / #956 — the audit follow-ups: the SQL twins and the
// payments report's separated figures.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0172 normalises every line\'s VAT rate to a number at issue', () {
    final sql = File('supabase/migrations/0172_line_vat_normalised.sql').readAsStringSync();
    expect(sql, contains("jsonb_build_object(''vat_percent'', coalesce((l->>''vat_percent'')::numeric, 0))"));
    expect(sql, contains("raise exception '0172: anchor missing'"));
  });

  test('0173 removes only DRAFT declarations of workspaces that charge no VAT', () {
    final sql = File('supabase/migrations/0173_orphan_vat_drafts.sql').readAsStringSync();
    expect(sql, contains("where d.status = 'draft' and not public.workspace_charges_vat(d.workspace_id)"));
    expect(sql, isNot(contains("status = 'submitted'")));
  });

  test('0174 stamps the formula at issue and never calls a legacy mismatch an alteration', () {
    final sql = File('supabase/migrations/0174_invoice_integrity.sql').readAsStringSync();
    expect(sql, contains("p_kind, 7);"));
    expect(sql, contains("if v.signature_algo is null then return 'unverifiable'; end if;"));
    expect(sql, contains("return 'altered';"));
    expect(sql, contains("if not public.is_member_of(v.workspace_id) then raise exception 'not a member'; end if;"));
  });

  test('the payments report names pending payments and pending expenses apart', () {
    expect(InvoicePdfTemplate.placeholders, containsAll(['pending_payments_total', 'pending_expenses_total']));
  });
}
