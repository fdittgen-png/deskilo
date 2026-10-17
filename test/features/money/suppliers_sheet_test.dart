// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2567 — suppliers on screen and on the wire: the wire model, the demo
// twin's numbering and refusals, the sheet's add / archive / review flows,
// and the inbox showing the supplier its document was linked to.
import 'package:deskilo/core/demo/data/einvoice_inbox_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/domain/einvoice_inbox.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_inbox_section.dart';
import 'package:deskilo/features/money/presentation/widgets/suppliers_sheet.dart';
import 'package:deskilo/features/money/providers/einvoice_inbox_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

void main() {
  test('a supplier row decodes; bank data is not part of it', () {
    final s = Supplier.fromRow({
      'id': 's1',
      'supplier_number': '12',
      'name': 'ACME',
      'tax_id_entered': 'fr 12 345678901',
      'tax_identifier': 'FR12345678901',
      'tax_id_kind': 'vat_group',
      'status': 'archived',
      'bank_revision': 3,
    });
    expect(s.number, '12');
    expect(s.isVerified, isTrue);
    expect(s.taxIdKind, SupplierIdKind.vatGroup);
    expect(s.isActive, isFalse);
    expect(s.bankRevision, 3);
  });

  test(
    'the demo twin numbers, refuses a taken identifier and keeps history',
    () async {
      final repo = FakeSupplierRepository();
      final a = await repo.save(
        'ws',
        const SupplierDraft(name: 'ACME', taxId: 'FR 12 345678901'),
      );
      final b = await repo.save('ws', const SupplierDraft(name: 'Beta'));
      expect(
        [for (final s in await repo.fetchSuppliers('ws')) s.number],
        ['1', '2'],
      );
      await expectLater(
        repo.save(
          'ws',
          const SupplierDraft(name: 'ACME again', taxId: 'FR12345678901'),
        ),
        throwsStateError,
      );
      expect(
        await repo.setBank(
          a,
          accountHolder: 'ACME',
          iban: 'FR76 3000',
          bic: '',
        ),
        1,
      );
      expect(
        (await repo.fetchBankHistory('ws', a)).single.validation,
        BankValidation.invalid,
      );
      expect((await repo.fetchSuppliers('ws'))[1].id, b);
    },
  );

  testWidgets('a supplier is added, archived and restored from the sheet', (
    tester,
  ) async {
    final repo = FakeSupplierRepository();
    await tester.pumpWidget(
      _app(const SuppliersView(workspaceId: 'ws'), [
        supplierRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('supplier-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('supplier-name')), 'ACME');
    await tester.enterText(
      find.byKey(const ValueKey('supplier-tax-id')),
      'FR12345678901',
    );
    await tester.tap(find.byKey(const ValueKey('supplier-save')));
    await tester.pumpAndSettle();
    expect(find.text('1 · ACME'), findsOneWidget);
    final id = repo.suppliers.single.id;

    await tester.tap(find.byKey(ValueKey('supplier-archive-$id')));
    await tester.pumpAndSettle();
    expect(repo.suppliers.single.isActive, isFalse);
    await tester.tap(find.byKey(ValueKey('supplier-archive-$id')));
    await tester.pumpAndSettle();
    expect(repo.suppliers.single.isActive, isTrue);
  });

  testWidgets('a review is resolved by linking to a candidate', (tester) async {
    final repo = FakeSupplierRepository();
    final id = await repo.save('ws', const SupplierDraft(name: 'ACME'));
    repo.reviews.add(
      SupplierReview(
        id: 'r1',
        reason: SupplierReviewReason.missingIdentifier,
        sourceName: 'ACME',
        sourceIdentifier: '',
        candidateIds: [id],
      ),
    );
    await tester.pumpWidget(
      _app(const SuppliersView(workspaceId: 'ws'), [
        supplierRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('supplier-review-r1')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('supplier-review-link-$id')));
    await tester.pumpAndSettle();
    expect(repo.reviews, isEmpty);
    expect(find.byKey(const ValueKey('supplier-review-r1')), findsNothing);
  });

  testWidgets('the inbox shows the supplier its document was linked to', (
    tester,
  ) async {
    final inbox = FakeEInvoiceInboxRepository()
      ..documents.add(
        const InboxDocument(
          id: 'd1',
          number: 'F-9',
          issueDate: '2026-09-01',
          currency: 'EUR',
          supplierName: 'ACME Sarl',
          grossCents: 12000,
          status: InboxStatus.received,
          supplierId: 's1',
          supplierNumber: '12',
        ),
      );
    await tester.pumpWidget(
      _app(const EInvoiceInboxSection(workspaceId: 'ws'), [
        eInvoiceInboxRepositoryProvider.overrideWithValue(inbox),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Supplier 12'), findsOneWidget);
    expect(find.text('ACME Sarl · F-9'), findsOneWidget);
  });
}
