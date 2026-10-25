// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2581 — the export and print controls on the Web-BI page. Without the
// right to export there is no export control (the server refuses the read
// anyway). Opening the export, choosing a file and closing write nothing;
// one click asks the server once; the preview shows the frozen snapshot's
// time, digest and qualification; Save writes exactly that snapshot (data
// changed since is not in it) and a browser download is said as a request;
// Read again is a new snapshot with its own time and digest; a refusal
// shows why and keeps no figure; another file is another export. A saved
// report's print layout is edited, saved with the report, exported under
// its id and revision, and shown in the preview.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/domain/bi_batch.dart';
import 'package:deskilo/features/workspace/domain/bi_report_snapshot.dart';
import 'package:deskilo/features/workspace/domain/bi_view_memory.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_export_sheet.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workbook_export_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/bi_report_fixture.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/unavailable_kpi_repository.dart';

final _en = AppLocalizationsEn();

typedef _Call = ({
  List<BiBatchRequest> requests,
  BiExportFormat format,
  String? reportId,
  int? revision,
});

/// The server's export read: each call answers with the data as it is at
/// that call (the reserved hours and the amounts move by 10 each time).
class _Exports implements BiExportRepository {
  final calls = <_Call>[];
  final refusals = <int, BiExportFailure>{};
  Completer<void>? gate;

  @override
  Future<Object?> snapshot(
    String workspaceId, {
    required List<BiBatchRequest> requests,
    required BiExportFormat format,
    String? reportId,
    int? reportRevision,
  }) async {
    calls.add((
      requests: requests,
      format: format,
      reportId: reportId,
      revision: reportRevision,
    ));
    final n = calls.length;
    await gate?.future;
    final refused = refusals[n];
    if (refused != null) throw BiExportRefused(refused);
    return fixtureAnswerOf(
      requests,
      workspaceId: workspaceId,
      format: format,
      hash: '$n' * 64,
      shift: (n - 1) * 10,
      computedAt: '2026-03-15T1$n:00:00Z',
    );
  }
}

class _Saver {
  final saved = <({Uint8List bytes, String name})>[];
  SaveOutcome Function(String name) outcome = SavedFile.new;

  Future<SaveOutcome> call({
    required Uint8List bytes,
    required String fileName,
  }) async {
    saved.add((bytes: bytes, name: fileName));
    return outcome(fileName);
  }
}

Future<(_Exports, _Saver, InMemoryBiViewRepository)> _pump(
  WidgetTester tester, {
  Set<WorkspacePermission>? permissions,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final exports = _Exports();
  final saver = _Saver();
  final views = InMemoryBiViewRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {
              'invoicing': true,
              'workspaceStatus': true,
              'capacityKpi': true,
              'biReportDesigner': true,
              'pdfExport': true,
              'dataExport': true,
            },
          ),
          clock: FixedClock(DateTime(2026, 9, 15, 12)),
          biViews: views,
        ),
        platformIsWebProvider.overrideWithValue(true),
        webShellProvider.overrideWithValue(true),
        kpiRepositoryProvider.overrideWithValue(
          const UnavailableKpiRepository(),
        ),
        biExportRepositoryProvider.overrideWithValue(exports),
        typedFileSaverProvider.overrideWithValue(saver.call),
        fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
        if (permissions != null)
          myPermissionsProvider.overrideWithValue(permissions),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (exports, saver, views);
}

Future<void> _open(WidgetTester tester, String location) async {
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

const _page = '/bi?cards=capacity.seat_utilisation,finance.invoiced';

void main() {
  test(
    'the files offered follow the export right and each format\'s feature',
    () {
      const all = {WorkspaceFeature.pdfExport, WorkspaceFeature.dataExport};
      expect(
        biExportFormats(all, {WorkspacePermission.viewAnalytics}),
        isEmpty,
      );
      expect(biExportFormats(all, {WorkspacePermission.exportData}), [
        BiExportFormat.pdf,
        BiExportFormat.csv,
        BiExportFormat.xlsx,
      ]);
      expect(
        biExportFormats(
          {WorkspaceFeature.pdfExport},
          {WorkspacePermission.exportData},
        ),
        [BiExportFormat.pdf],
      );
      expect(
        biExportFormats(
          {WorkspaceFeature.dataExport},
          {WorkspacePermission.exportData},
        ),
        [BiExportFormat.csv, BiExportFormat.xlsx],
      );
    },
  );

  testWidgets('without the right to export there is no export control', (
    tester,
  ) async {
    await _pump(
      tester,
      permissions: {
        WorkspacePermission.viewAnalytics,
        WorkspacePermission.viewFinances,
        WorkspacePermission.manageReservations,
      },
    );
    await _open(tester, _page);
    expect(_key('bi-page'), findsOneWidget);
    expect(_key('bi-export-report'), findsNothing);
  });

  testWidgets(
    'one click asks once; the preview is the frozen snapshot; Save writes it',
    (tester) async {
      final (exports, saver, _) = await _pump(tester);
      await _open(tester, _page);
      await _tap(tester, 'bi-export-report');
      expect(exports.calls, isEmpty, reason: 'opening the export asks nothing');
      await _tap(tester, 'bi-export-format-csv');
      exports.gate = Completer<void>();
      await tester.tap(_key('bi-export-take'));
      await tester.tap(_key('bi-export-take'), warnIfMissed: false);
      await tester.pump();
      exports.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        exports.calls,
        hasLength(1),
        reason: 'a second click while asking asks nothing',
      );
      expect(exports.calls.single.format, BiExportFormat.csv);
      expect(
        exports.calls.single.reportId,
        isNull,
        reason: 'an unsaved analysis has no report id',
      );
      expect(_key('bi-print-preview'), findsOneWidget);
      expect(_text(tester, 'bi-export-digest'), _en.biExportDigest('1' * 64));
      expect(
        _text(tester, 'bi-export-computed'),
        startsWith('Figures computed on'),
      );
      expect(_text(tester, 'bi-print-qualification'), _en.biPrintComplete);
      expect(saver.saved, isEmpty, reason: 'a preview writes nothing');

      await _tap(tester, 'bi-export-save');
      expect(saver.saved, hasLength(1));
      expect(
        exports.calls,
        hasLength(1),
        reason: 'the file is the snapshot, not a second read',
      );
      final csv = utf8.decode(saver.saved.single.bytes.sublist(3));
      expect(csv, contains(',${20 / 120},"percent"'));
      expect(csv, contains('"snapshot_hash","${'1' * 64}"'));
      expect(saver.saved.single.name, endsWith('-2026-09-11111111.csv'));
      expect(
        find.text(_en.commonSavedTo(saver.saved.single.name)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'read again is a new snapshot; the old one is what was saved before',
    (tester) async {
      final (exports, saver, _) = await _pump(tester);
      await _open(tester, _page);
      await _tap(tester, 'bi-export-report');
      await _tap(tester, 'bi-export-format-csv');
      await _tap(tester, 'bi-export-take');
      await _tap(tester, 'bi-export-refresh');
      expect(exports.calls, hasLength(2));
      expect(_text(tester, 'bi-export-computed'), startsWith('Read again on'));
      expect(_text(tester, 'bi-export-digest'), _en.biExportDigest('2' * 64));
      await _tap(tester, 'bi-export-save');
      final csv = utf8.decode(saver.saved.single.bytes.sublist(3));
      expect(
        csv,
        contains(',${30 / 120},"percent"'),
        reason: 'the data as it was at the second read',
      );
      expect(csv, isNot(contains(',${20 / 120},')));
    },
  );

  testWidgets('a browser download is said as a request, not as a saved file', (
    tester,
  ) async {
    final (_, saver, _) = await _pump(tester);
    saver.outcome = DownloadRequested.new;
    await _open(tester, _page);
    await _tap(tester, 'bi-export-report');
    await _tap(tester, 'bi-export-format-xlsx');
    await _tap(tester, 'bi-export-take');
    await _tap(tester, 'bi-export-save');
    final name = saver.saved.single.name;
    expect(name, endsWith('.xlsx'));
    expect(String.fromCharCodes(saver.saved.single.bytes.take(2)), 'PK');
    expect(find.text(_en.fileDownloadRequested(name)), findsOneWidget);
    expect(find.text(_en.commonSavedTo(name)), findsNothing);
  });

  testWidgets(
    'a refusal shows why and keeps no figure; another file is another export',
    (tester) async {
      final (exports, saver, _) = await _pump(tester);
      exports.refusals[2] = BiExportFailure.forbidden;
      exports.refusals[3] = BiExportFailure.tooLarge;
      await _open(tester, _page);
      await _tap(tester, 'bi-export-report');
      await _tap(tester, 'bi-export-take');
      expect(exports.calls.single.format, BiExportFormat.pdf);
      await _tap(tester, 'bi-export-refresh');
      expect(_text(tester, 'bi-export-failure'), _en.biExportFailedForbidden);
      expect(
        _key('bi-print-preview'),
        findsNothing,
        reason: 'a revoked right is not answered by an older copy',
      );
      expect(_key('bi-export-save'), findsNothing);
      await _tap(tester, 'bi-export-take');
      expect(_text(tester, 'bi-export-failure'), _en.biExportFailedTooLarge);
      await _tap(tester, 'bi-export-format-xlsx');
      expect(_key('bi-export-failure'), findsNothing);
      await _tap(tester, 'bi-export-take');
      expect(exports.calls.last.format, BiExportFormat.xlsx);
      expect(_key('bi-print-preview'), findsOneWidget);
      expect(saver.saved, isEmpty);
    },
  );

  testWidgets(
    'a report\'s print layout is edited, saved, exported and previewed',
    (tester) async {
      final (exports, _, views) = await _pump(tester);
      await _open(tester, _page);
      await _tap(tester, 'bi-views-duplicate-report');
      await _tap(tester, 'bi-report-print-layout');
      await _tap(tester, 'bi-print-orientation-landscape');
      await _tap(tester, 'bi-print-margin-wide');
      await tester.enterText(_key('bi-print-header'), 'Board pack');
      await _tap(tester, 'bi-print-page-breaks');
      await _tap(tester, 'bi-print-apply');
      await _tap(tester, 'bi-report-save');
      final saved = (await views.list('ws-1')).single;
      final style = saved.definition!.report!.printStyle;
      expect(style.orientation, 'landscape');
      expect(style.margin, 'wide');
      expect(style.header, 'Board pack');
      expect(style.pageBreaks, isFalse);
      expect(saved.revision, 2);

      await _tap(tester, 'bi-export-report');
      await _tap(tester, 'bi-export-take');
      expect(exports.calls.single.reportId, saved.id);
      expect(exports.calls.single.revision, 2);
      expect(
        find.descendant(
          of: _key('bi-print-preview'),
          matching: find.text('Board pack'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a header on two lines is refused under its field', (
    tester,
  ) async {
    final (_, _, views) = await _pump(tester);
    await _open(tester, _page);
    await _tap(tester, 'bi-views-duplicate-report');
    await _tap(tester, 'bi-report-print-layout');
    await tester.enterText(_key('bi-print-footer'), 'tab\there');
    await _tap(tester, 'bi-print-apply');
    expect(find.text(_en.biPrintLineInvalid), findsOneWidget);
    expect((await views.list('ws-1')).single.revision, 1);
  });
}
