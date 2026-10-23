// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The workspace configuration PDF renders, grows with its members and
// survives empty sections.
//
// #2898 — each level's plan prints under its heading, with the level's
// photo under the plan, in the bands and in a positioned layout alike.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/features/money/domain/configuration_report_bands.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/domain/report_layout/pdf_geometry.dart';
import 'package:deskilo/features/money/presentation/report_layout_actions.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/presentation/plan_png.dart';
import 'package:deskilo/features/workspace/domain/workspace_config_report.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

final _strings = WorkspaceConfigPdfStrings(
  title: 'Workspace configuration',
  overview: 'Overview',
  country: 'Country',
  currency: 'Currency',
  timezone: 'Time zone',
  granularity: 'Booking granularity',
  members: 'Members',
  colName: 'Name',
  colRole: 'Role',
  colStatus: 'Status',
  features: 'Enabled features',
  none: 'None',
  availability: 'Availability',
  openDays: 'Open days',
  closures: 'Closures',
  floorPlan: 'Floor plan',
  bookableWhole: 'bookable as a whole',
  seatsLabel: 'Seats',
  emptyLevel: 'No rooms',
  levelBookable: (price) =>
      price.isEmpty ? 'Bookable as a whole' : 'Bookable — $price',
  invitations: 'Invitations',
  invitationCustomTemplate: 'Custom invitation message configured',
  invitationDefault: 'Built-in invitation message',
  invitationSingleUse: 'Single-use codes; approval required',
  workingHours: 'Working hours',
  vatRates: 'VAT rates',
  sites: 'Sites',
);

pw.Font _ttf(String path) => pw.Font.ttf(
      ByteData.sublistView(File(path).readAsBytesSync()),
    );

FloorPlan _plan() {
  const office = Office(
    id: 'office-1',
    workspaceId: 'ws-1',
    levelId: 'level-1',
    name: 'Main room',
    color: 0,
    bookableAsWhole: true,
    rect: GridRect(x: 0, y: 0, w: 30, h: 20),
  );
  const desk = Desk(
    id: 'desk-1',
    workspaceId: 'ws-1',
    officeId: 'office-1',
    name: 'Window desk',
    rect: GridRect(x: 2, y: 2, w: 12, h: 4),
  );
  const seat = Seat(
    id: 'seat-1',
    workspaceId: 'ws-1',
    deskId: 'desk-1',
    name: 'A1',
    x: 2,
    y: 2,
    orientation: SeatOrientation.n,
    chair: 'standard',
    amenities: [],
  );
  return const FloorPlan(
    levelId: 'level-1',
    offices: [office],
    desks: [desk],
    seats: [seat],
  );
}

Future<Uint8List> _build({
  List<ConfigPdfMember> members = const [
    (name: 'Anna', role: 'Owner', status: 'Active', details: ''),
    (name: 'Ben', role: 'Member', status: 'Active', details: ''),
  ],
  List<ConfigFeatureGroup> featureGroups = const [
    (process: 'Coordination', features: ['Calendar tab']),
    (process: 'Money', features: ['Money tab']),
  ],
  List<String> closureLabels = const ['Jul 14, 2026 — Bastille Day'],
  String kind = 'workspace_configuration',
}) async {
  final data = workspaceConfigurationReportData(WorkspaceConfigDocument(strings: _strings,
      workspaceName: 'Test Space',
      generatedOnLabel: 'Generated on Jul 19, 2026',
      countryLabel: 'France',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      granularityLabel: 'Half day',
      members: members,
      featureGroups: featureGroups,
      openDaysLabel: 'Monday, Tuesday, Wednesday',
      closureLabels: closureLabels,
      levels: [
        (
          level: const Level(
            id: 'level-1',
            workspaceId: 'ws-1',
            name: 'Ground floor',
            sortOrder: 0,
          ),
          plan: _plan(),
        ),
      ],
      levelPrices: const {},
    hasCustomInvitationTemplate: false));
  final report = renderReportBands(bands: configurationReportBands(_strings.title), data: data)!
      .numberedFor(kind);
  final rows = report.body.whereType<ReportTableRow>().expand((row) => row.cells);
  for (final name in members.map((m) => m.name)) {
    expect(rows, contains(name));
  }
  expect(rows, contains('A1'));
  return buildBandedLetterPdf(report: report, documentTitle: _strings.title, pageLabel: 'Page',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'));
}

void main() {
  test('workspace configuration renders all members and seats through the engine', () async {
    final bytes = await _build();
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    Directory('build/report-config').createSync(recursive: true);
    File('build/report-config/configuration.pdf').writeAsBytesSync(bytes);
  });

  test('more members grow the document', () async {
    final few = await _build(
      members: const [(name: 'Anna', role: 'Owner', status: 'Active', details: '')],
    );
    final many = await _build(
      members: [
        for (var i = 0; i < 20; i++)
          (name: 'Member $i', role: 'Member', status: 'Active', details: ''),
      ],
    );
    expect(many.length, greaterThan(few.length));
  });

  test('empty sections still render (no members / features / closures)',
      () async {
    final bytes = await _build(
      members: const [],
      featureGroups: const [],
      closureLabels: const [],
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('#2862 — the configuration numbers page 1 too; a letter does not',
      () async {
    // The page number is the only ink in the bottom-right corner: the
    // footer band's own text sits at the left.
    int corner(Uint8List bytes) => textPositions(bytes)
        .where((i) => i.page == 1 && i.yMm > 270 && i.xMm > 150)
        .length;
    final report = await _build();
    final letter = await _build(kind: 'statement');
    expect(corner(report), greaterThan(corner(letter)));
    expect(corner(letter), 0);
  });

  group('#2898 — the plan of each level', () {
    const ground = Level(
      id: 'level-1',
      workspaceId: 'ws-1',
      name: 'Ground floor',
      sortOrder: 0,
      backgroundPath: 'ws-1/level-1',
    );
    const attic = Level(
      id: 'level-2',
      workspaceId: 'ws-1',
      name: 'Attic',
      sortOrder: 1,
    );
    const empty = FloorPlan(
      levelId: 'level-2',
      offices: [],
      desks: [],
      seats: [],
    );
    const colors = ColorScheme.light();
    late ui.Image photo;
    setUpAll(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 64, 64),
          ui.Paint()..color = const ui.Color(0xFF2060D0));
      photo = await recorder.endRecording().toImage(64, 64);
    });

    /// The pictures the export draws: through the data report's loader.
    Future<Map<String, Uint8List>> pngs(
            Future<ui.Image?> Function(String) background) =>
        reportPlanPngs({'level-1': _plan(), 'level-2': empty},
            colors: colors,
            photoLevels: {'level-1'},
            background: background,
            wait: const Duration(milliseconds: 50));

    Map<String, Object?> data(Map<String, Uint8List> pngs) =>
        workspaceConfigurationReportData(WorkspaceConfigDocument(
          strings: _strings,
          workspaceName: 'Test Space',
          generatedOnLabel: 'Generated on Jul 19, 2026',
          countryLabel: 'France',
          currencyCode: 'EUR',
          timezone: 'Europe/Paris',
          granularityLabel: 'Half day',
          members: const [],
          featureGroups: const [],
          openDaysLabel: 'Monday',
          closureLabels: const [],
          levels: [(level: ground, plan: _plan()), (level: attic, plan: empty)],
          levelPrices: const {},
          hasCustomInvitationTemplate: false,
          planImages: pngs.keys.toSet(),
        ));

    InvoiceReport report(Map<String, Uint8List> pngs) => renderReportBands(
        bands: configurationReportBands(_strings.title),
        data: data(pngs))!;

    Future<Uint8List> banded(Map<String, Uint8List> pngs) =>
        buildBandedLetterPdf(
            report: report(pngs),
            reportImages: configPlanImages(pngs),
            documentTitle: _strings.title,
            pageLabel: 'Page',
            baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
            boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'));

    // A design that keeps the configuration's own markup in its body —
    // what an owner's layout for the kind does.
    final layout = '<report-layout margin="20mm"><body><markup>'
        '${configurationReportBands(_strings.title).body}'
        '</markup></body></report-layout>';
    Future<Uint8List> positioned(Map<String, Uint8List> pngs) async {
      final images = configPlanImages(pngs);
      return (await tryLayoutPdf(
        layoutXml: layout,
        data: data(pngs),
        what: 'configuration',
        documentTitle: _strings.title,
        pageLabel: 'Page',
        font: (asset) async => _ttf(asset),
        image: (name) async => images[name],
      ))!;
    }

    test('a level with a plan prints it under its heading; its rooms, '
        'desks and seats still print as rows', () async {
      final drawn = await pngs((_) async => null);
      expect(drawn.keys, ['level-1'],
          reason: 'a level with nothing to draw has no picture');
      final body = report(drawn).body;
      final heading = body.indexWhere(
          (b) => b is ReportSubheading && b.text == 'Ground floor');
      final image = body[heading + 1];
      expect(image, isA<ReportImage>());
      expect((image as ReportImage).name, 'plan-level-1');
      expect(image.size, ReportImageSize.extraLarge);
      final cells =
          body.whereType<ReportTableRow>().expand((row) => row.cells).toList();
      expect(cells, containsAll(['Main room', 'Window desk', 'A1', 'No rooms']));
      expect(body.whereType<ReportImage>(), hasLength(1),
          reason: 'the empty attic prints no picture');
      expect(_imageStreams(await banded(drawn)), hasLength(_onePicture));
    });

    test('without a picture no row names one and nothing is drawn', () async {
      final rows = data(const {})['configuration_rows']! as List;
      expect(rows.where((row) => (row as Map).containsKey('image')), isEmpty);
      expect(report(const {}).body.whereType<ReportImage>(), isEmpty);
      expect(_imageStreams(await banded(const {})), isEmpty);
    });

    for (final (name, render) in [
      ('the bands', banded),
      ('a positioned layout', positioned),
    ]) {
      test('$name: the photo under the plan; an unreadable photo prints the '
          'plan alone', () async {
        final plain = _imageStreams(await render(await pngs((_) async => null)));
        expect(plain, hasLength(_onePicture));
        final withPhoto =
            _imageStreams(await render(await pngs((_) async => photo)));
        expect(withPhoto, hasLength(_onePicture));
        expect(withPhoto.first, isNot(plain.first));
        final unreadable = _imageStreams(await render(
            await pngs((_) async => throw Exception('Invalid image data'))));
        expect(unreadable, plain);
      });
    }

    test('a positioned layout prints the pictures its markup names', () async {
      final drawn = await pngs((_) async => null);
      final document = renderLayoutDocument(layout, data(drawn));
      expect(layoutDocumentImageNames(document),
          {'plan-level-1'});
      expect(_imageStreams(await positioned(const {})), isEmpty);
      expect(_imageStreams(await positioned(drawn)), hasLength(_onePicture));
    });
  });
}

/// One plan picture in a PDF: its colours and its alpha mask, the two
/// image streams the pdf package writes for a PNG.
const _onePicture = 2;

/// The image streams of [pdf], in order.
List<String> _imageStreams(Uint8List pdf) => [
  for (final m in RegExp(r'/Subtype\s*/Image.*?stream\r?\n(.*?)endstream',
          dotAll: true)
      .allMatches(latin1.decode(pdf)))
    m.group(1)!,
];
