// SPDX-License-Identifier: 0BSD
//
// Invoices (0060): an IMMUTABLE archive — the member sees their own,
// admins the workspace's; the owner (or a delegated admin) issues; each
// row downloads or shares the signed PDF. Snapshots + the SHA-256
// fingerprint come from the server; the trigger refuses any mutation.
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

FakeMoneyRepository seededMoney() {
  final money = FakeMoneyRepository();
  money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    title: 'July membership',
    lines: const [InvoiceLine(label: 'Subscription', amountCents: 25000)],
  );
  return money;
}

Future<FakeMoneyRepository> pumpInvoices(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeWorkspaceRepository? workspace,
  FileSaver? saver,
  FileSharer? sharer,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: money,
          workspace: workspace,
          fileSharer: sharer,
        ),
        if (saver != null) fileSaverProvider.overrideWithValue(saver),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets(
      'the OWNER issues an invoice: member + title + lines → the archive '
      'lists it with number and total', (tester) async {
    final money = await pumpInvoices(tester);
    expect(find.text('No invoices yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('invoice-title-field')),
      'July membership',
    );
    await tester.enterText(
      find.byKey(const ValueKey('invoice-line-label-0')),
      'Subscription 100%',
    );
    await tester.enterText(
      find.byKey(const ValueKey('invoice-line-amount-0')),
      '250',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    final invoice = money.invoices.single;
    expect(invoice.title, 'July membership');
    expect(invoice.totalCents, 25000);
    expect(invoice.memberId, 'member-1');
    expect(invoice.number, startsWith('INV-'));
    expect(find.textContaining(invoice.number), findsOneWidget);
    expect(find.text('Invoice issued.'), findsOneWidget);
  });

  testWidgets(
      'a half-filled line refuses with the pinned validation message '
      '(nothing issued)', (tester) async {
    final money = await pumpInvoices(tester);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('invoice-line-label-0')),
      'Subscription',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Every line needs a label and amount.'),
      findsOneWidget,
    );
    expect(money.invoices, isEmpty);
  });

  testWidgets(
      'download saves the signed PDF into Downloads under the invoice '
      'number', (tester) async {
    final saved = <({String name, Uint8List bytes})>[];
    final money = await pumpInvoices(
      tester,
      money: seededMoney(),
      saver: ({required bytes, required fileName}) async {
        saved.add((name: fileName, bytes: bytes));
        return 'Download/$fileName';
      },
    );

    final invoice = money.invoices.single;
    // Font assets and PDF assembly need real async to complete.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('invoice-download-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(saved.single.name, 'inv-2026-0001.pdf');
    expect(String.fromCharCodes(saved.single.bytes.sublist(0, 5)), '%PDF-');
    expect(find.textContaining('Download/inv-2026-0001.pdf'), findsOneWidget);
  });

  testWidgets(
      'share hands the PDF to the system share sheet (mail, WhatsApp…) '
      'via the seam', (tester) async {
    final shared = <({String name, String mime, Uint8List bytes})>[];
    final money = await pumpInvoices(
      tester,
      money: seededMoney(),
      sharer: ({required bytes, required fileName, required mimeType}) async {
        shared.add((name: fileName, mime: mimeType, bytes: bytes));
      },
    );

    final invoice = money.invoices.single;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('invoice-share-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(shared.single.name, 'inv-2026-0001.pdf');
    expect(shared.single.mime, 'application/pdf');
    expect(String.fromCharCodes(shared.single.bytes.sublist(0, 5)), '%PDF-');
  });

  testWidgets(
      'a PLAIN member sees the archive (their own invoices) but no issue '
      'button', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    final money = await pumpInvoices(
      tester,
      money: seededMoney(),
      workspace: workspace,
    );
    expect(
      find.byKey(ValueKey('invoice-${money.invoices.single.id}')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('invoice-create-button')), findsNothing);
  });

  testWidgets('an admin WITHOUT the adminInvoicing delegation cannot issue',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: true);
    await pumpInvoices(tester, workspace: workspace);
    expect(find.byKey(const ValueKey('invoice-create-button')), findsNothing);
  });

  testWidgets('an admin WITH the adminInvoicing delegation gets the button',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'adminInvoicing': true},
    );
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: true);
    await pumpInvoices(tester, workspace: workspace);
    expect(
      find.byKey(const ValueKey('invoice-create-button')),
      findsOneWidget,
    );
  });
}
