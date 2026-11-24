// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — the installation's operator reads the error reports: newest first,
// each with its kind, code, version, platform and time, its redacted stack
// when opened, older ones on request; nothing yet says so, and a refused or
// failed read is the shared read failure with Try again.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/instance_repository.dart';
import 'package:deskilo/features/mcp/presentation/widgets/instance_error_reports.dart';
import 'package:deskilo/features/workspace/domain/instance_trace_report.dart';
import 'package:deskilo/features/workspace/providers/instance_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Refusing extends FakeInstanceRepository {
  @override
  Future<List<InstanceTraceReport>> traceReports({DateTime? before}) async =>
      throw StateError('only the instance operator');
}

InstanceTraceReport _report(int n, {String? code}) => InstanceTraceReport(
  id: 'r$n',
  reportedAt: DateTime.utc(2026, 11, 24, 10).subtract(Duration(minutes: n)),
  appVersion: '2.2.0',
  schemaVersion: 953,
  platform: 'android',
  failureType: 'money/StateError $n',
  failureCode: code,
  stack: '#0 issue (invoice.dart:$n) for <email>',
);

Future<void> _open(WidgetTester tester, FakeInstanceRepository repo) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [instanceRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: InstanceErrorReportsTile()),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('instance-error-reports')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the newest report comes first, and opened shows its stack', (
    tester,
  ) async {
    final repo = FakeInstanceRepository()
      ..traceReportRows.addAll([_report(1, code: DkCode.dkn01), _report(2)]);
    await _open(tester, repo);
    final first = find.byKey(const ValueKey('instance-error-report-r1'));
    final second = find.byKey(const ValueKey('instance-error-report-r2'));
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(find.text('money/StateError 1'), findsOneWidget);
    expect(find.textContaining('2.2.0 · android'), findsNWidgets(2));
    expect(find.text('Code DKN01'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('instance-error-report-stack-r1')),
      findsNothing,
    );
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('instance-error-report-stack-r1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('instance-error-reports-older')),
      findsNothing,
    );
  });

  testWidgets('a full page offers the older reports, which follow it', (
    tester,
  ) async {
    final repo = FakeInstanceRepository()
      ..traceReportRows.addAll([
        for (var i = 1; i <= traceReportsPageSize + 1; i++) _report(i),
      ]);
    await _open(tester, repo);
    expect(
      find.byKey(
        const ValueKey('instance-error-report-r${traceReportsPageSize + 1}'),
      ),
      findsNothing,
    );
    final older = find.byKey(const ValueKey('instance-error-reports-older'));
    await tester.scrollUntilVisible(
      older,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(older);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('instance-error-report-r${traceReportsPageSize + 1}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no report yet says so', (tester) async {
    await _open(tester, FakeInstanceRepository());
    expect(
      find.byKey(const ValueKey('instance-error-reports-none')),
      findsOneWidget,
    );
  });

  testWidgets('a refused read is the shared read failure with Try again', (
    tester,
  ) async {
    await _open(tester, _Refusing());
    expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
    expect(find.byKey(const ValueKey('inline-banner-action')), findsOneWidget);
  });
}
