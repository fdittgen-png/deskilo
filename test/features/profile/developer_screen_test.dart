// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Developer mode: the trace list newest first, level filters, export to a
// .log file, and clear.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

TraceLogger seededLogger() {
  final logger = TraceLogger()
    ..log(TraceLevel.info, 'boot', 'older info entry')
    ..log(
      TraceLevel.warn,
      'push',
      'middle warning entry',
    )
    ..error(
      'money',
      'newest error entry',
      error: StateError('boom'),
      stackTrace: StackTrace.fromString('#0 first\n#1 second'),
    );
  return logger;
}

Future<void> pumpSettings(
  WidgetTester tester, {
  required TraceLogger logger,
  bool devMode = false,
  FileSaver? saver,
  FakeWorkspaceRepository? workspace,
  FakeReservationRepository? reservations,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          devMode: devMode,
          workspace: workspace,
          reservations: reservations,
        ),
        traceLoggerProvider.overrideWithValue(logger),
        fileSaverProvider.overrideWithValue(
            saver ?? ({required bytes, required fileName}) async => '/local/f'),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  // The settings list outgrew the test viewport (#147) and the section
  // headers (#188) push the Advanced section further down: bring it into
  // view. scrollUntilVisible stops once the tile is BUILT (cache extent),
  // ensureVisible finishes the job.
  await tester.scrollUntilVisible(find.text('Developer mode'), 100);
  await tester.ensureVisible(find.text('Developer mode'));
  await tester.pumpAndSettle();
}

Future<void> pumpDeveloper(
  WidgetTester tester, {
  required TraceLogger logger,
  FileSaver? saver,
  FakeWorkspaceRepository? workspace,
  FakeReservationRepository? reservations,
}) async {
  await pumpSettings(
    tester,
    logger: logger,
    devMode: true,
    saver: saver,
    workspace: workspace,
    reservations: reservations,
  );
  // The Developer tile sits below the dev-mode switch, which may rest at
  // the bottom edge after the scroll above — reveal it before tapping.
  await tester.scrollUntilVisible(find.text('Developer'), 100);
  await tester.ensureVisible(find.text('Developer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Developer'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'settings shows the developer-mode toggle to everyone and reveals the '
      'Developer tile only when it is on', (tester) async {
    await pumpSettings(
      tester,
      logger: TraceLogger(),
    );

    // #419: the switch is an ADMIN affordance now (the default test
    // viewer is the owner) and flips the mode for the whole workspace.
    expect(find.text('Developer mode'), findsOneWidget);
    expect(find.text('Developer'), findsNothing);

    await tester.tap(find.text('Developer mode'));
    await tester.pumpAndSettle();

    expect(find.text('Developer'), findsOneWidget);
  });

  testWidgets('the trace list renders entries newest first', (tester) async {
    await pumpDeveloper(tester, logger: seededLogger());

    expect(find.text('newest error entry'), findsOneWidget);
    expect(find.text('middle warning entry'), findsOneWidget);
    expect(find.text('older info entry'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('newest error entry')).dy,
      lessThan(tester.getTopLeft(find.text('older info entry')).dy),
    );
    expect(
      tester.getTopLeft(find.text('middle warning entry')).dy,
      lessThan(tester.getTopLeft(find.text('older info entry')).dy),
    );
  });

  testWidgets('the level filter chips narrow the list', (tester) async {
    await pumpDeveloper(tester, logger: seededLogger());

    await tester.tap(find.text('Errors'));
    await tester.pumpAndSettle();
    expect(find.text('newest error entry'), findsOneWidget);
    expect(find.text('middle warning entry'), findsNothing);
    expect(find.text('older info entry'), findsNothing);

    await tester.tap(find.text('Warnings+'));
    await tester.pumpAndSettle();
    expect(find.text('newest error entry'), findsOneWidget);
    expect(find.text('middle warning entry'), findsOneWidget);
    expect(find.text('older info entry'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('older info entry'), findsOneWidget);
  });

  testWidgets(
      'Export saves the full trace as a timestamped .log file locally',
      (tester) async {
    final saved = <(String, Uint8List)>[];
    await pumpDeveloper(
      tester,
      logger: seededLogger(),
      saver: ({required bytes, required fileName}) async {
        saved.add((fileName, bytes));
        return '/local/$fileName';
      },
    );

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(
      saved.single.$1,
      matches(RegExp(r'^deskilo-trace-\d{8}-\d{4}\.log$')),
    );
    final content = String.fromCharCodes(saved.single.$2);
    expect(content, contains('INFO boot: older info entry'));
    expect(content, contains('ERROR money: newest error entry'));
    expect(content, contains(r'#0 first\n#1 second'));
  });

  testWidgets('Clear empties the list down to the placeholder',
      (tester) async {
    final logger = seededLogger();
    await pumpDeveloper(tester, logger: logger);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(logger.entries, isEmpty);
    expect(find.text('No trace entries yet.'), findsOneWidget);
    expect(find.text('newest error entry'), findsNothing);
  });

  group('#1310 S0 — the reservation dump honours exportData', () {
    /// Two members' bookings in the workspace; 'member-1' is the viewer.
    FakeReservationRepository seededReservations() {
      final reservations = FakeReservationRepository();
      for (final (id, memberId) in [
        ('res-mine', 'member-1'),
        ('res-theirs', 'member-2'),
      ]) {
        reservations.reservations.add(Reservation(
          id: id,
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: memberId,
          startsAt: kTestNow,
          endsAt: kTestNow.add(const Duration(hours: 2)),
          status: ReservationStatus.reserved,
        ));
      }
      return reservations;
    }

    /// An ADMIN whose role row does or does not carry exportData. Owners
    /// hold every permission by construction, and developer mode is an
    /// admin affordance (#419), so the admin row is where this rule can
    /// be seen at all — and an admin is who reaches for a bulk export.
    FakeWorkspaceRepository adminWith(bool exportData) {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      workspace.myMember = workspace.myMember.copyWith(isOwner: false);
      workspace.workspaces[0] = workspace.workspaces[0].copyWith(
        rolePermissions: {
          'admin': [
            for (final p in defaultPermissionsFor(PermissionRole.admin))
              if (p != WorkspacePermission.exportData) p.wireName,
            if (exportData) WorkspacePermission.exportData.wireName,
          ],
        },
      );
      return workspace;
    }

    Future<String> exportedCsv(
      WidgetTester tester, {
      required bool exportData,
    }) async {
      String saved = '';
      await pumpDeveloper(
        tester,
        logger: TraceLogger(),
        workspace: adminWith(exportData),
        reservations: seededReservations(),
        saver: ({required bytes, required fileName}) async {
          if (fileName.contains('reservations')) {
            saved = String.fromCharCodes(bytes);
          }
          return '/local/$fileName';
        },
      );
      await tester.tap(
          find.byKey(const ValueKey('developer-export-reservations')));
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('without it, the file carries only my own bookings — the '
        'bug report survives, the bulk channel does not', (tester) async {
      final csv = await exportedCsv(tester, exportData: false);
      expect(csv, contains('res-mine'));
      expect(csv, isNot(contains('res-theirs')));
    });

    testWidgets('with it, the file carries the workspace', (tester) async {
      final csv = await exportedCsv(tester, exportData: true);
      expect(csv, contains('res-mine'));
      expect(csv, contains('res-theirs'));
    });
  });
}
