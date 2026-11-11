// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3680 — a failed read is never shown as an empty answer: the VAT editor is
// not loaded from a failed read (an empty list saved back would remove every
// rate), and a member's invoice list says the failure with Try again instead
// of "no invoices yet".
import 'dart:io';

import 'package:deskilo/features/money/presentation/screens/vat_screen.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_overview.dart';
import 'package:deskilo/features/money/presentation/widgets/my_invoices_list.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/read_probe.dart';
import '../../helpers/test_workspace_context.dart';

final _en = AppLocalizationsEn();
const _failure = ValueKey('read-failure');
const _retry = ValueKey('inline-banner-action');

void main() {
  testWidgets('the VAT editor is never loaded from a failed read', (
    tester,
  ) async {
    final rates = ReadProbe<List<VatRate>>();
    await pumpStateScreen(
      tester,
      const VatScreen(),
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        vatRatesProvider.overrideWith((ref) => rates()),
        testReadyWorkspaceContext(),
      ],
    );
    await tester.pump();
    rates.fail(const SocketException('no route'));
    await tester.pump();
    expect(find.byKey(_failure), findsOneWidget);
    expect(find.byType(TextField), findsNothing,
        reason: 'no editor over an empty list');
    await tester.tap(find.byKey(_retry));
    await tester.pump();
    expect(rates.calls, 2, reason: 'Try again reads the rates again');
  });

  testWidgets("a member's invoice list says the failure, not 'no invoices "
      "yet'", (tester) async {
    final invoices = ReadProbe<List<Invoice>>();
    await pumpStateScreen(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: MyInvoicesList(
            memberId: 'member-1',
            exposure: InvoiceExposure(
              open: [],
              overdue: [],
              dueCents: 0,
              currency: 'EUR',
              termDays: 30,
            ),
          ),
        ),
      ),
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        invoicesProvider.overrideWith((ref) => invoices()),
        testReadyWorkspaceContext(),
      ],
    );
    await tester.pump();
    invoices.fail(const SocketException('no route'));
    await tester.pump();
    expect(find.text(_en.moneyNoInvoicesYet), findsNothing);
    expect(find.byKey(_failure), findsOneWidget);
  });
}
