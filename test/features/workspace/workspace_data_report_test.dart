// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The workspace data report (#2862) is the workbook on paper: rendered
// from the Pézenas demo space, every section is present, the registers are
// printed across the sheet, every page is numbered, and each total equals
// the sum of the workbook's column for the same rows. The rules behind the
// totals (a cancelled invoice counts nowhere, a credit note reduces what
// was bought) are pinned on a small fixture beside it.
import 'dart:convert' show latin1;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/core/i18n/currencies.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/report_layout/pdf_geometry.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/presentation/plan_png.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_data_report.dart';
import 'package:deskilo/features/workspace/domain/workspace_data_report_builder.dart';
import 'package:deskilo/features/workspace/domain/workspace_data_report_pdf.dart';
import 'package:deskilo/features/workspace/domain/workspace_excel.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _parts = {
  DataReportPart.members: 'Members',
  DataReportPart.bookings: 'Bookings by month',
  DataReportPart.invoices: 'Invoice register',
  DataReportPart.payments: 'Payments and balances',
  DataReportPart.purchases: 'Purchases and suppliers',
  DataReportPart.plan: 'Plan and prices',
};

final _strings = WorkspaceDataReportStrings(
  title: 'Workspace data report',
  contents: 'Contents',
  workspace: 'Workspace',
  period: 'Period',
  generatedOn: 'Generated on',
  timeZone: 'Time zone',
  currency: 'Currency',
  total: 'Total',
  none: 'None',
  yes: 'Yes',
  no: 'No',
  pageLabel: 'Page',
  part: (p) => _parts[p]!,
  table: (k) => k,
  column: (k) => k,
  word: (k) => k,
  role: (k) => k,
  wholeLevel: (price) => 'Bookable as a whole $price',
  money: (cents) => (cents / 100).toStringAsFixed(2),
  day: (d) => d.toIso8601String().substring(0, 10),
  month: (d) => d.toIso8601String().substring(0, 7),
  number: (n) => '$n',
);

/// The sum of the workbook column [column] of [sheet], in minor units,
/// over the rows [where] keeps.
int _sheetCents(
  List<XlsxSheet> sheets,
  String sheet,
  String column, {
  required String currency,
  bool Function(Map<String, Object?> row)? where,
}) {
  final s = sheets.firstWhere((x) => x.name == sheet);
  final header = s.rows.first;
  var sum = 0.0;
  for (final row in s.rows.skip(1)) {
    final named = {
      for (final (i, h) in header.indexed) '$h': i < row.length ? row[i] : null,
    };
    if (where != null && !where(named)) continue;
    final v = named[column];
    if (v is XlsxAmount) sum += v.value;
  }
  return (sum * Currencies.minorPerMajor(currency)).round();
}

int _rows(List<XlsxSheet> sheets, String sheet) =>
    sheets.firstWhere((x) => x.name == sheet).rows.length - 1;

/// Pages whose media box is wider than tall.
int _landscapePages(Uint8List pdf) =>
    RegExp(r'/MediaBox\[0 0 841\.\d+ 595\.')
        .allMatches(String.fromCharCodes(pdf))
        .length;

/// The bytes of every image the PDF embeds, in order.
List<String> _imageStreams(Uint8List pdf) => [
  for (final m in RegExp(r'/Subtype\s*/Image.*?stream\r?\n(.*?)endstream',
          dotAll: true)
      .allMatches(latin1.decode(pdf)))
    m.group(1)!,
];

int _pages(Uint8List pdf) =>
    RegExp(r'/MediaBox').allMatches(String.fromCharCodes(pdf)).length;

void main() {
  group('rendered from the Pézenas demo space', () {
    late WorkspaceExportDetails details;
    late WorkspaceDataReport report;
    late List<XlsxSheet> workbook;
    late List<DataReportPurchase> purchases;

    setUpAll(() async {
      final now = DateTime(2026, 10, 14, 10);
      final fixture = DemoFixture.build(now: now);
      final ws = fixture.workspaces.workspaces.first;
      final levels = await fixture.floorPlan.fetchLevels(ws.id);
      final plans = {
        for (final l in levels) l.id: await fixture.floorPlan.fetchPlan(l.id),
      };
      final members = await fixture.workspaces.fetchMembers(ws.id);
      final reservations = await fixture.reservations.fetchAllForExport(ws.id);
      final ledger = await fixture.money.fetchWorkspaceLedger(ws.id);
      final invoices = await fixture.money.fetchInvoices(ws.id);
      final buying = seedDemoPurchasing(now, money: fixture.money);
      details = WorkspaceExportDetails(
        workspace: ws,
        levels: levels,
        plansByLevel: plans,
        memberName: fixture.workspaces.memberNames,
        ledger: ledger,
        events: const [],
        decisions: const {},
        invoices: invoices,
        members: members,
        reservations: reservations,
        invoiceMatches: await fixture.money.fetchInvoiceMatches(ws.id),
      );
      purchases = [
        for (final p in await buying.purchases.fetchPurchases(ws.id))
          (
            date: p.originalDate ?? p.receivedOn,
            reference: p.reference,
            kind: p.kind.wire,
            state: p.state.name,
            category: p.category,
            grossCents: p.grossCents,
          ),
      ];
      report = buildWorkspaceDataReport(
        details,
        purchases: purchases,
        suppliers: [
          for (final s in await buying.suppliers.fetchSuppliers(ws.id))
            (
              number: s.number,
              name: s.name,
              taxId: s.taxIdentifier,
              city: s.city,
              country: s.countryCode,
              status: s.status.name,
            ),
        ],
      );
      workbook = [
        ...buildWorkspaceExcelExport(
          workspace: ws,
          enabledFeatures: const {},
          levels: levels,
          plansByLevel: plans,
          members: members,
          profilesByUserId: const {},
          reservations: reservations,
          ledger: ledger,
          pendingEvents: const [],
          paymentIntents: const [],
          services: const [],
          invoices: invoices,
          transmissionsByInvoice: const {},
        ),
        ...buildWorkspaceExcelDetailSheets(details),
      ];
    });

    test('the demo space holds every kind of record the report prints', () {
      for (final key in [
        'members',
        'bookings',
        'invoices',
        'payments',
        'balances',
        'purchases',
        'suppliers',
      ]) {
        expect(report.table(key).rows, isNotEmpty, reason: key);
      }
      expect(report.section(DataReportPart.plan).levels, isNotEmpty);
      expect(report.from, isNotNull);
    });

    test('the invoice register totals equal the workbook Invoices column', () {
      final c = report.currency;
      bool standing(Map<String, Object?> r) => r['voided_at'] == null;
      final t = report.table('invoices');
      for (final (col, sheetCol) in [
        ('net', 'net'),
        ('vat', 'vat'),
        ('total', 'total'),
      ]) {
        expect(
          t.total(col),
          _sheetCents(
            workbook,
            'Invoices',
            sheetCol,
            currency: c,
            where: standing,
          ),
          reason: col,
        );
      }
    });

    test('payments and balances equal the Payments and Ledger sheets', () {
      final c = report.currency;
      expect(
        report.table('payments').total('amount'),
        _sheetCents(
          workbook,
          'Payments',
          'amount',
          currency: c,
          where: (r) => r['state'] == 'confirmed',
        ),
      );
      expect(
        report.table('balances').total('balance'),
        _sheetCents(workbook, 'Ledger', 'signed_amount', currency: c),
      );
      final b = report.table('balances');
      expect(
        (b.total('charges')! as int) - (b.total('credits')! as int),
        b.total('balance'),
      );
    });

    test('members and bookings count the Users and Bookings rows', () {
      expect(report.table('members').total('name'), _rows(workbook, 'Users'));
      expect(
        report.table('bookings').total('bookings'),
        _rows(workbook, 'Reservations'),
      );
    });

    test('the purchases total is what was bought, net of credit notes', () {
      final counted = purchases.where(
        (p) => p.state != 'rejected' && p.state != 'cancelled',
      );
      expect(
        report.table('purchases').total('total'),
        counted.fold<int>(
          0,
          (s, p) =>
              s + (p.kind == 'credit_note' ? -p.grossCents : p.grossCents),
        ),
      );
    });

    test('the PDF: a cover, the contents, every section on its own pages, '
        'the registers across the sheet, every page numbered', () async {
      final pdf = await buildWorkspaceDataReportPdf(
        WorkspaceDataReportPdfRequest(
          report: report,
          strings: _strings,
          generatedAt: DateTime(2026, 10, 14),
          baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
          boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
        ),
      );
      final raw = String.fromCharCodes(pdf);
      expect(raw.startsWith('%PDF-'), isTrue);
      // One outline entry per section: what the contents page lists.
      for (final title in _parts.values) {
        expect(raw, contains('($title)'), reason: title);
      }
      final pages = _pages(pdf);
      final across = _landscapePages(pdf);
      // Invoices, payments and purchases: at least a page each, across.
      expect(across, greaterThanOrEqualTo(3));
      // Cover, contents, members, bookings and plan stay upright.
      expect(pages - across, greaterThanOrEqualTo(5));
      // "Page n/m" is the only ink in the bottom-right corner, on every
      // page, the cover's first.
      final numbered = {
        for (final ink in textPositions(pdf))
          if (ink.yMm > 270 && ink.xMm > 150) ink.page,
      };
      expect(numbered, hasLength(pages));
    });
  });

  group('the rules behind the totals', () {
    const ws = Workspace(
      id: 'ws-1',
      name: 'Test Space',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'GOODCODE22',
    );
    Invoice invoice(
      String id,
      int net,
      int vat, {
      DateTime? voidedAt,
      String? settledBy,
    }) => Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'm-1',
      number: 'F-$id',
      issuedAt: DateTime.utc(2026, 3, 2),
      period: '2026-03',
      title: 'March',
      lines: const [],
      totalCents: net + vat,
      vatTotals: [
        InvoiceVatTotal(
          percent: 20,
          category: 'S',
          grossCents: net + vat,
          netCents: net,
          vatCents: vat,
        ),
      ],
      currency: 'EUR',
      memberName: 'Ana',
      memberAddress: '',
      workspaceName: 'Test Space',
      workspaceAddress: '',
      issuerName: 'Flo',
      signature: 'f' * 64,
      voidedAt: voidedAt,
      settledByInvoiceId: settledBy,
    );
    Reservation booking(String id, DateTime start, ReservationStatus status) =>
        Reservation(
          id: id,
          workspaceId: 'ws-1',
          memberId: 'm-1',
          seatId: 'seat-1',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 4)),
          status: status,
        );
    final d = WorkspaceExportDetails(
      workspace: ws,
      levels: const [],
      plansByLevel: const {},
      memberName: const {'m-1': 'Ana'},
      ledger: [
        LedgerEntry(
          id: 'c',
          memberId: 'm-1',
          kind: LedgerKind.charge,
          category: LedgerCategory.subscription,
          amountCents: 12000,
          description: 'March',
          period: '2026-03',
          createdAt: DateTime.utc(2026, 3, 2),
        ),
        LedgerEntry(
          id: 'p',
          memberId: 'm-1',
          kind: LedgerKind.credit,
          category: LedgerCategory.payment,
          amountCents: 5000,
          description: 'Transfer',
          period: '2026-03',
          createdAt: DateTime.utc(2026, 3, 9),
        ),
      ],
      events: const [],
      decisions: const {},
      invoices: [
        invoice('a', 10000, 2000),
        invoice('void', 5000, 1000, voidedAt: DateTime.utc(2026, 3, 3)),
        invoice('folded', 1000, 200, settledBy: 'a'),
      ],
      invoiceMatches: {
        'a': InvoiceMatch(
          invoiceId: 'a',
          paidCents: 5000,
          resolution: 'under_accepted',
          matchedAt: DateTime.utc(2026, 3, 9),
        ),
      },
      reservations: [
        booking('1', DateTime.utc(2026, 3, 3, 8), ReservationStatus.completed),
        booking('2', DateTime.utc(2026, 3, 4, 8), ReservationStatus.cancelled),
        booking('3', DateTime.utc(2026, 4, 1, 8), ReservationStatus.reserved),
      ],
    );
    final report = buildWorkspaceDataReport(
      d,
      purchases: [
        (
          date: DateTime(2026, 3),
          reference: 'B1',
          kind: 'bill',
          state: 'approved',
          category: 'rent',
          grossCents: 80000,
        ),
        (
          date: DateTime(2026, 3, 5),
          reference: 'C1',
          kind: 'credit_note',
          state: 'approved',
          category: 'rent',
          grossCents: 10000,
        ),
        (
          date: DateTime(2026, 3, 6),
          reference: 'B2',
          kind: 'bill',
          state: 'rejected',
          category: 'rent',
          grossCents: 999,
        ),
      ],
    );

    test('a cancelled invoice is listed and counted in no total', () {
      final t = report.table('invoices');
      expect(t.rows, hasLength(3));
      expect(t.total('net'), 11000);
      expect(t.total('vat'), 2200);
      expect(t.total('total'), 13200);
    });

    test('open is what the standing payment left; nothing on a folded one', () {
      final t = report.table('invoices');
      final open = t.columns.indexWhere((c) => c.key == 'open');
      final byNumber = {for (final r in t.rows) r.first: r[open]};
      expect(byNumber['F-a'], 7000);
      expect(byNumber['F-folded'], 0);
      expect(byNumber['F-void'], 0);
      expect(t.total('paid'), 5000);
      expect(t.total('open'), 7000);
    });

    test('a balance is what was charged less what settled it', () {
      final t = report.table('balances');
      expect(t.rows.single, ['Ana', 12000, 5000, 7000]);
      expect(report.table('payments').total('amount'), 5000);
    });

    test('bookings by month: held, cancelled and the hours held', () {
      final t = report.table('bookings');
      expect(t.rows.first, [DateTime(2026, 3), 2, 1, 0, 1, 4.0]);
      expect(t.totals, [null, 3, 2, 0, 1, 8.0]);
    });

    test('a credit note reduces purchases; a refused bill counts nowhere', () {
      expect(report.table('purchases').total('total'), 70000);
    });
  });

  // #2898 — the level's background photo prints under its plan; a photo
  // that cannot be read leaves the picture the report printed before.
  group('the plan over the level photo', () {
    const ws = Workspace(
      id: 'ws-1',
      name: 'Test Space',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'GOODCODE22',
    );
    const level = Level(
      id: 'level-1',
      workspaceId: 'ws-1',
      name: 'Ground floor',
      sortOrder: 0,
      backgroundPath: 'ws-1/level-1',
    );
    const plan = FloorPlan(
      levelId: 'level-1',
      offices: [
        Office(
          id: 'o',
          workspaceId: 'ws-1',
          levelId: 'level-1',
          name: 'Room',
          color: 0,
          bookableAsWhole: false,
          rect: GridRect(x: 50, y: 50, w: 20, h: 20),
        ),
      ],
      desks: [],
      seats: [],
    );
    const colors = ColorScheme.light();
    const details = WorkspaceExportDetails(
      workspace: ws,
      levels: [level],
      plansByLevel: {'level-1': plan},
      memberName: {},
      ledger: [],
      events: [],
      decisions: {},
      invoices: [],
    );
    final report = buildWorkspaceDataReport(details);

    Future<Uint8List> pdf(Map<String, Uint8List> planImages) =>
        buildWorkspaceDataReportPdf(
          WorkspaceDataReportPdfRequest(
            report: report,
            strings: _strings,
            generatedAt: DateTime(2026, 10, 14),
            baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
            boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
            planImages: planImages,
          ),
        );
    Future<Uint8List> printed(Future<ui.Image?> Function(String) photo) async =>
        pdf(await reportPlanPngs(details.plansByLevel,
            colors: colors,
            photoLevels: {
              for (final l in details.levels)
                if (l.hasBackground) l.id,
            },
            background: photo));

    test('the photo under the plan; unreadable, the plan as before', () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 64, 64),
          ui.Paint()..color = const ui.Color(0xFF2060D0));
      final photo = await recorder.endRecording().toImage(64, 64);
      final before = _imageStreams(await pdf({
        'level-1': (await buildPlanPng(plan, colors: colors))!,
      }));
      expect(before, isNotEmpty, reason: 'the level prints its plan');

      final withPhoto = _imageStreams(await printed((_) async => photo));
      expect(withPhoto, hasLength(before.length));
      expect(withPhoto.first, isNot(before.first));

      final unreadable = _imageStreams(
          await printed((_) async => throw Exception('Invalid image data')));
      expect(unreadable, before);
    });
  });
}
