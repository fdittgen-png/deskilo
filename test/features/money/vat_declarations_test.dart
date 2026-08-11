// SPDX-License-Identifier: 0BSD
//
// VAT declarations (#534/0107): the rate catalogue covers the governed
// territories, the aggregation matches the invoices' own vatSplit, the
// official-box mapping (CA3/UStVA/generic), the XML export, and the
// screen's generate → PDF/XML → transmit/mark-filed lifecycle.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Invoice _invoice(
  String id,
  DateTime issuedAt,
  List<InvoiceLine> lines, {
  DateTime? voidedAt,
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-$id',
      issuedAt: issuedAt,
      period: '2026-08',
      title: 'Invoice $id',
      lines: lines,
      totalCents: lines.fold(0, (sum, l) => sum + l.amountCents),
      currency: 'EUR',
      memberName: 'Flo',
      memberAddress: '',
      workspaceName: 'pezenas1',
      workspaceAddress: '',
      issuerName: 'Flo',
      signature: 'sig',
      voidedAt: voidedAt,
    );

void main() {
  group('vat catalogue (#534)', () {
    test('covers every EU member state, CH, NO and CA', () {
      const eu = [
        'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', //
        'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', //
        'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
      ];
      for (final code in [...eu, 'CH', 'NO', 'CA']) {
        expect(hasVatCatalogue(code), isTrue, reason: code);
        expect(vatCatalogueFor(code).first.isDefault, isTrue,
            reason: code);
      }
      // The US deliberately has NO preset (no federal VAT) — a note
      // explains instead.
      expect(hasVatCatalogue('US'), isFalse);
      expect(vatCatalogueNote('US'), isNotNull);
      expect(vatCatalogueNote('CA'), isNotNull);
    });

    test('pins the 2026 standard rates that recently moved', () {
      double standard(String code) => vatCatalogueFor(code).first.percent;
      expect(standard('EE'), 24); // 22 → 24
      expect(standard('FI'), 25.5); // 24 → 25.5
      expect(standard('RO'), 21); // 19 → 21
      expect(standard('SK'), 23); // 20 → 23
      expect(standard('CH'), 8.1);
      expect(standard('NO'), 25);
      // Switzerland's accommodation special rate exists.
      expect(vatCatalogueFor('CH').any((r) => r.percent == 3.8), isTrue);
    });
  });

  group('declaration aggregation (#534)', () {
    test('matches vatSplit per line, filters period, skips voided', () {
      final august = DateTime(2026, 8, 5);
      final invoices = [
        // Two lines at 20 %: 120.00 gross → net 100.00, VAT 20.00 each.
        _invoice('a', august, const [
          InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20),
          InvoiceLine(label: 'Meeting', amountCents: 12000, vatPercent: 20),
        ]),
        // One at 5.5 %: 105.50 gross → net 100.00, VAT 5.50.
        _invoice('b', DateTime(2026, 8, 20), const [
          InvoiceLine(label: 'Book', amountCents: 10550, vatPercent: 5.5),
        ]),
        // Voided — never counted.
        _invoice('v', august, const [
          InvoiceLine(label: 'Wrong', amountCents: 99900, vatPercent: 20),
        ], voidedAt: DateTime(2026, 8, 6)),
        // Outside the period.
        _invoice('c', DateTime(2026, 7, 30), const [
          InvoiceLine(label: 'July', amountCents: 12000, vatPercent: 20),
        ]),
      ];
      final lines = computeVatDeclarationLines(
          invoices, DateTime(2026, 8, 1), DateTime(2026, 8, 31));
      expect(lines, hasLength(2));
      final at20 = lines.singleWhere((l) => l.percent == 20);
      expect(at20.grossCents, 24000);
      expect(at20.netCents, 20000);
      expect(at20.vatCents, 4000);
      expect(at20.invoiceCount, 1);
      final at55 = lines.singleWhere((l) => l.percent == 5.5);
      expect(at55.netCents, 10000);
      expect(at55.vatCents, 550);
    });

    test('maps onto the official boxes — FR CA3 and DE UStVA', () {
      const lines = [
        VatDeclarationLine(
            percent: 20,
            grossCents: 24000,
            netCents: 20000,
            vatCents: 4000,
            invoiceCount: 2),
        VatDeclarationLine(
            percent: 5.5,
            grossCents: 10550,
            netCents: 10000,
            vatCents: 550,
            invoiceCount: 1),
      ];
      final fr = vatFormBoxes('FR', lines);
      expect(fr.singleWhere((b) => b.code == '08').vatCents, 4000);
      expect(fr.singleWhere((b) => b.code == '9B').netCents, 10000);

      const german = [
        VatDeclarationLine(
            percent: 19,
            grossCents: 11900,
            netCents: 10000,
            vatCents: 1900,
            invoiceCount: 1),
      ];
      final de = vatFormBoxes('DE', german);
      expect(de.single.code, 'Kz 81');
      expect(de.single.netCents, 10000);

      // Anywhere else: generic per-rate boxes.
      final generic = vatFormBoxes('NO', lines);
      expect(generic, hasLength(2));
    });

    test('the XML export carries seller, rates and boxes', () {
      final declaration = VatDeclaration(
        id: 'd1',
        workspaceId: 'ws-1',
        periodStart: DateTime(2026, 8, 1),
        periodEnd: DateTime(2026, 8, 31),
        status: 'draft',
        lines: const [
          VatDeclarationLine(
              percent: 20,
              grossCents: 12000,
              netCents: 10000,
              vatCents: 2000,
              invoiceCount: 1),
        ],
        totalNetCents: 10000,
        totalVatCents: 2000,
        currency: 'EUR',
        invoiceCount: 1,
        createdAt: DateTime.utc(2026, 8, 11),
      );
      final xml = vatDeclarationXml(
        declaration: declaration,
        workspaceName: 'pezenas1',
        vatId: 'FR123',
        countryCode: 'FR',
      );
      expect(xml, contains('deskilo-vat-1'));
      expect(xml, contains('<vat-id>FR123</vat-id>'));
      expect(xml, contains('percent="20.0"'));
      expect(xml, contains('code="08"'));
      expect(xml, contains('<vat-cents>2000</vat-cents>'));
    });

    test('pins the lifecycle contract against migration 0107', () {
      final sql = File('supabase/migrations/0107_vat_declarations.sql')
          .readAsStringSync();
      expect(sql, contains('save_vat_declaration'));
      expect(sql, contains('mark_vat_declaration_submitted'));
      expect(sql, contains("check (status in ('draft', 'submitted'))"));
      expect(sql, contains('only the owner files VAT declarations'));
      expect(sql, contains('workspace_charges_vat'));
      expect(sql, contains('declaration already submitted'));
    });
  });

  group('declarations screen (#534)', () {
    Future<FakeMoneyRepository> pump(
      WidgetTester tester, {
      String regime = 'vat_registered',
    }) async {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      workspace.workspaces[0] =
          workspace.workspaces[0].copyWith(vatRegime: regime);
      final money = FakeMoneyRepository()
        // The platform channel is configured — the Transmit button shows.
        ..einvoiceGateway =
            const EInvoiceGatewayConfig(configured: true);
      money.invoices.add(_invoice(
        'a',
        DateTime(kTestNow.year, kTestNow.month, 3),
        const [
          InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20),
        ],
      ));
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides:
              standardTestOverrides(money: money, workspace: workspace),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).push('/vat-declarations');
      await tester.pumpAndSettle();
      return money;
    }

    testWidgets('generate builds the draft from the month\'s invoices',
        (tester) async {
      final money = await pump(tester);

      await tester.tap(find.byKey(const ValueKey('vat-decl-generate')));
      await tester.pumpAndSettle();

      final declaration = money.vatDeclarations.single;
      expect(declaration.status, 'draft');
      expect(declaration.totalNetCents, 10000);
      expect(declaration.totalVatCents, 2000);
      expect(declaration.invoiceCount, 1);
      expect(
          find.byKey(ValueKey('vat-decl-${declaration.id}')), findsOneWidget);
    });

    testWidgets('transmit sends through the platform and stamps submitted',
        (tester) async {
      final money = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('vat-decl-generate')));
      await tester.pumpAndSettle();
      final id = money.vatDeclarations.single.id;

      await tester.tap(find.byKey(ValueKey('vat-decl-send-$id')));
      await tester.pumpAndSettle();

      expect(money.sentDeclarationIds, [id]);
      expect(money.vatDeclarations.single.isSubmitted, isTrue);
      expect(money.vatDeclarations.single.submittedChannel, 'platform');
    });

    testWidgets('mark as filed asks first, then locks the declaration',
        (tester) async {
      final money = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('vat-decl-generate')));
      await tester.pumpAndSettle();
      final id = money.vatDeclarations.single.id;

      await tester.tap(find.byKey(ValueKey('vat-decl-filed-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vat-decl-filed-confirm')));
      await tester.pumpAndSettle();

      expect(money.vatDeclarations.single.isSubmitted, isTrue);
      expect(money.vatDeclarations.single.submittedChannel, 'manual');
      // Submitted → the transmit/mark buttons are gone.
      expect(find.byKey(ValueKey('vat-decl-send-$id')), findsNothing);
      expect(find.byKey(ValueKey('vat-decl-filed-$id')), findsNothing);
    });

    testWidgets('an exempt workspace hits the regime gate', (tester) async {
      await pump(tester, regime: 'exempt');
      expect(
          find.byKey(const ValueKey('vat-decl-regime-gate')), findsOneWidget);
      expect(find.byKey(const ValueKey('vat-decl-generate')), findsNothing);
    });
  });
}
