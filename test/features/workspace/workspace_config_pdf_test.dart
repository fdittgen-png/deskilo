// SPDX-License-Identifier: MIT
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/workspace_config_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

const _strings = WorkspaceConfigPdfStrings(
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
    (name: 'Anna', role: 'Owner', status: 'Active'),
    (name: 'Ben', role: 'Member', status: 'Active'),
  ],
  List<String> featureLabels = const ['Calendar tab', 'Money tab'],
  List<String> closureLabels = const ['Jul 14, 2026 — Bastille Day'],
}) =>
    buildWorkspaceConfigPdf(
      strings: _strings,
      workspaceName: 'Test Space',
      generatedOnLabel: 'Generated on Jul 19, 2026',
      countryLabel: 'France',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      granularityLabel: 'Half day',
      members: members,
      featureLabels: featureLabels,
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
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

void main() {
  test('buildWorkspaceConfigPdf renders a non-empty PDF', () async {
    final bytes = await _build();
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('more members grow the document', () async {
    final few = await _build(
      members: const [(name: 'Anna', role: 'Owner', status: 'Active')],
    );
    final many = await _build(
      members: [
        for (var i = 0; i < 20; i++)
          (name: 'Member $i', role: 'Member', status: 'Active'),
      ],
    );
    expect(many.length, greaterThan(few.length));
  });

  test('empty sections still render (no members / features / closures)',
      () async {
    final bytes = await _build(
      members: const [],
      featureLabels: const [],
      closureLabels: const [],
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });
}
