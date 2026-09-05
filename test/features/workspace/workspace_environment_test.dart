// SPDX-License-Identifier: 0BSD
//
// #917 — a workspace says whether it is real.
//
// The same app, the same numbering, the same documents: nothing told a
// space used for trying things out apart from one billing real people.
// So a workspace carries its environment, development by default and for
// every space that predates the column, the app says so on every screen,
// and every document it prints carries the word across the page.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

InvoicePdfStrings _strings({
  String development = '',
  String settledIn = '',
}) =>
    InvoicePdfStrings(
      invoiceTitle: 'Invoice',
      issuedOn: 'Issued on',
      issuedBy: 'Issued by',
      billedTo: 'Billed to',
      total: 'Balance due',
      signature: 'Digital signature',
      voided: 'ERRONEOUS — voided on',
      voidedWatermark: 'Erroneous',
      proforma: 'Proforma',
      copy: 'Copy',
      settledIn: settledIn,
      development: development,
      replaces: 'Replaces',
      description: 'Description',
      charges: 'Charges',
      payments: 'Payments',
      net: 'Net',
      annex: 'Annex',
      attendance: 'Attendance',
      activity: 'Activity',
      reserved: 'Reserved',
      page: 'Page',
    );

void main() {
  group('the flag', () {
    test('a workspace that never chose is a DEVELOPMENT one — the safe '
        'answer to "is this real?" is no', () {
      expect(WorkspaceEnvironment.development.wire, 'dev');
      expect(WorkspaceEnvironment.fromWire(null),
          WorkspaceEnvironment.development);
      expect(WorkspaceEnvironment.fromWire(''),
          WorkspaceEnvironment.development);
      expect(WorkspaceEnvironment.fromWire('staging'),
          WorkspaceEnvironment.development,
          reason: 'an unknown value must never read as production');
      expect(WorkspaceEnvironment.fromWire('prod'),
          WorkspaceEnvironment.production);
    });

    test('the extension reads the stored wire value', () {
      const dev = Workspace(
        id: 'ws-1',
        name: 'Demo',
        countryCode: 'FR',
        currencyCode: 'EUR',
        timezone: 'Europe/Paris',
        inviteCode: 'CODE',
      );
      expect(dev.environment, 'dev', reason: 'the model default');
      expect(dev.isDevelopment, isTrue);
      expect(dev.copyWith(environment: 'prod').isDevelopment, isFalse);
      expect(dev.copyWith(environment: 'nonsense').isDevelopment, isTrue);
    });
  });

  group('the watermark', () {
    test('a development workspace stamps every document, whatever else '
        'the page is', () {
      for (final (proforma, voided, copy) in [
        (false, false, false),
        (true, false, false),
        (false, true, false),
        (false, false, true),
        (true, true, true),
      ]) {
        expect(
          invoiceWatermark(
            _strings(development: 'DEVELOPMENT'),
            proforma: proforma,
            voided: voided,
            copy: copy,
          ),
          'DEVELOPMENT',
          reason: 'not real outranks proforma=$proforma voided=$voided '
              'copy=$copy',
        );
      }
    });

    test('and it outranks the regrouped stamp too', () {
      expect(
        invoiceWatermark(
          _strings(development: 'DEVELOPMENT', settledIn: 'REGROUPED IN X'),
          proforma: false,
          voided: false,
          copy: false,
        ),
        'DEVELOPMENT',
      );
    });

    test('a production workspace leaves the existing precedence alone — '
        'the absence of the word is what makes it mean something', () {
      expect(
        invoiceWatermark(_strings(),
            proforma: true, voided: false, copy: false),
        'PROFORMA',
      );
      expect(
        invoiceWatermark(_strings(settledIn: 'REGROUPED IN X'),
            proforma: false, voided: false, copy: false),
        'REGROUPED IN X',
      );
      expect(
        invoiceWatermark(_strings(),
            proforma: false, voided: true, copy: false),
        'ERRONEOUS',
      );
      expect(
        invoiceWatermark(_strings(),
            proforma: false, voided: false, copy: true),
        'COPY',
      );
      expect(
        invoiceWatermark(_strings(),
            proforma: false, voided: false, copy: false),
        '',
      );
    });

    test('the word is always upper-cased, whatever the language gives', () {
      expect(
        invoiceWatermark(_strings(development: 'Développement'),
            proforma: false, voided: false, copy: false),
        'DÉVELOPPEMENT',
      );
    });
  });

  group('the SQL twin (migration 0160)', () {
    final sql = File('supabase/migrations/0160_workspace_environment.sql')
        .readAsStringSync();

    test('the column defaults to dev, so every workspace that predates it '
        'became a development one', () {
      expect(sql, contains("add column if not exists environment text not null default 'dev'"));
      expect(sql, contains("check (environment in ('dev', 'prod'))"));
    });

    test('creation takes the environment and defaults it to dev', () {
      expect(sql, contains("p_environment text default 'dev'"));
      expect(sql, contains('drop function if exists public.create_workspace(text, text, text, text)'),
          reason: 'two overloads make a four-argument call ambiguous');
    });

    test('only an OWNER may declare a space real — an admin cannot take '
        'the mark off the documents they issue', () {
      expect(sql, contains('create or replace function public.set_workspace_environment'));
      expect(sql, contains('is_owner_of(p_workspace_id)'));
      expect(sql, contains('only owners may change the environment'));
      expect(sql, contains('revoke execute on function public.set_workspace_environment(uuid, text) from public, anon'));
    });

    test('an unknown environment is refused on both paths', () {
      expect("unknown environment %".allMatches(sql).length, 2);
    });
  });
}
