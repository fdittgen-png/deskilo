// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4120 -- an export files what the invoice stored: the CII kept with its
// original is the export's XML voucher, read back only while it matches the
// digest the server recorded; an invoice filed without its stored original is
// named, with why, in the summary of the archive or the export.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/money/demo_invoice_original_repository.dart';
import 'package:deskilo/features/money/application/invoice_originals.dart';
import 'package:deskilo/features/money/application/originals_summary.dart';
import 'package:deskilo/features/money/domain/invoice_original.dart';
import 'package:deskilo/features/money/presentation/document_policies.dart';
import 'package:deskilo/features/money/presentation/invoice_original_document.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/real_async.dart';
import '../../helpers/test_workspace_context.dart';

DemoInvoiceOriginalRepository _store() => DemoInvoiceOriginalRepository(
  storedBy: () => 'user-1',
  now: () => DateTime.utc(2026, 12),
);

/// The store [inner] answering with an altered structured part.
class _XmlAltered extends DemoInvoiceOriginalRepository {
  _XmlAltered() : super(storedBy: () => null, now: () => DateTime.utc(2026));
  @override
  Future<String> xmlOf(String workspaceId, InvoiceOriginal original) async =>
      '${await super.xmlOf(workspaceId, original)} ';
}

Future<(FakeMoneyRepository, Invoice)> _issued({bool keeps = true}) async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-11',
  );
  return (money, money.invoices.single.copyWith(keepsOriginal: keeps));
}

/// [invoice]'s voucher, as an export files it.
Future<FiledVoucher> _voucher(
  WidgetTester tester, {
  required Invoice invoice,
  required FakeMoneyRepository money,
  required InvoiceOriginalRepository store,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  FiledVoucher? voucher;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: money,
          workspace: workspace,
          invoiceOriginals: store,
        ),
        testReadyWorkspaceContext(),
        currentWorkspaceProvider.overrideWith(
          (ref) async => workspace.workspaces.single,
        ),
        myPermissionsProvider.overrideWithValue({
          WorkspacePermission.issueInvoices,
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('file'),
              onPressed: () async {
                await readDocumentPolicies(ref);
                if (!context.mounted) return;
                const party = InvoiceParty();
                voucher = await InvoiceDocumentFlow(
                  context,
                  ref,
                ).voucherOf(invoice, seller: party, buyer: party, iban: '');
              },
              child: const Text('file'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('file')));
    await untilReal(() => voucher != null, what: 'the voucher');
  });
  return voucher!;
}

void main() {
  test('the CII stored with an original is read back while it matches its '
      'digest', () async {
    final (_, invoice) = await _issued();
    Future<InvoiceRendered> render({required bool copy}) async =>
        (pdf: Uint8List.fromList(const [1, 2, 3]), xml: '<CII>stored</CII>');
    final kept = InvoiceOriginals(_store(), mayIssue: true);
    await kept.documentOf(invoice, render);
    expect(await kept.storedXmlOf(invoice), '<CII>stored</CII>');

    final altered = InvoiceOriginals(_XmlAltered(), mayIssue: true);
    await altered.documentOf(invoice, render);
    expect(
      await altered.storedXmlOf(invoice),
      isNull,
      reason: 'an altered structured part is never filed as the original',
    );

    final (_, before) = await _issued(keeps: false);
    expect(await kept.storedXmlOf(before), isNull);
  });

  testWidgets('the export\'s XML voucher is the stored original\'s XML', (
    tester,
  ) async {
    final (money, invoice) = await _issued();
    final store = _store();
    final voucher = await _voucher(
      tester,
      invoice: invoice,
      money: money,
      store: store,
    );
    expect(voucher.source, InvoiceDocumentSource.original);
    final kept = (await store.originalOf(invoice.workspaceId, invoice.id))!;
    expect(voucher.xml, await store.xmlOf(invoice.workspaceId, kept));
    expect(voucher.xml, isNotEmpty);
    expect(
      withoutOriginal([invoice], {invoice.id: voucher}, filesXml: true),
      isEmpty,
    );
  });

  testWidgets('an invoice filed without its original is named in the summary, '
      'with why', (tester) async {
    final (money, invoice) = await _issued(keeps: false);
    final voucher = await _voucher(
      tester,
      invoice: invoice,
      money: money,
      store: _store(),
    );
    expect(voucher.source, InvoiceDocumentSource.notKept);
    expect(voucher.bytes, isNotEmpty, reason: 'a copy is still filed');
    final files = originalsSummaryFiles(
      withoutOriginal([invoice], {invoice.id: voucher}),
    );
    final text = utf8.decode(files[originalsSummaryFileName]!);
    expect(text, contains(invoice.number));
    expect(text, contains('issued before originals were kept'));
  });

  test('a stored CII that no longer matches is named where the export files '
      'the XML, and nowhere else', () async {
    final (_, invoice) = await _issued();
    const FiledVoucher filed = (
      bytes: [1],
      fileName: 'f.pdf',
      source: InvoiceDocumentSource.original,
      why: '',
      xml: null,
    );
    expect(withoutOriginal([invoice], {invoice.id: filed}), isEmpty);
    expect(
      withoutOriginal(
        [invoice],
        {invoice.id: filed},
        filesXml: true,
      ).single.source,
      InvoiceDocumentSource.mismatch,
    );
  });

  test('every invoice filed as its original: no summary file', () {
    expect(originalsSummaryFiles(const []), isEmpty);
  });

  test('the summary names each reason in words', () {
    for (final source in InvoiceDocumentSource.values) {
      if (source == InvoiceDocumentSource.original) continue;
      expect(originalMissingReason(source), isNotEmpty, reason: source.name);
    }
  });
}
