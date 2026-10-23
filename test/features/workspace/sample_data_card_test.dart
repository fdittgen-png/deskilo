// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 (ADR 0047 §9) — the sample data card appears only in a test space
// and only for someone who configures it. With no batch it explains and
// fills; with one it shows the counts and clears; a clear that did not
// happen says "not cleared" and offers a retry that clears, never "done".
import 'package:deskilo/features/workspace/domain/sample_data.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/sample_data_card.dart';
import 'package:deskilo/features/workspace/providers/sample_data_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server holding at most one batch; [failClears] clears that throw.
class _FakeSampleData implements SampleDataRepository {
  _FakeSampleData({this.open, this.failClears = 0});
  SampleDataBatch? open;
  int failClears;
  final calls = <String>[];

  @override
  Future<SampleDataBatch?> status(String workspaceId) async => open;

  @override
  Future<SampleDataBatch> fill(String workspaceId, String requestId) async {
    calls.add('fill');
    return open ??= const SampleDataBatch(
      id: 'b1',
      counts: {'members': 6, 'reservations': 40, 'ledger_entries': 3},
    );
  }

  @override
  Future<SampleDataBatch> clear(String workspaceId, String batchId) async {
    calls.add('clear');
    if (failClears > 0) {
      failClears--;
      throw StateError('sample data not cleared: still referenced');
    }
    open = null;
    return SampleDataBatch(id: batchId, clearedAt: DateTime.utc(2026, 10, 22));
  }
}

const _batch = SampleDataBatch(
  id: 'b1',
  counts: {'members': 6, 'reservations': 40, 'ledger_entries': 3},
);

Workspace _space(String environment) => Workspace(
  id: 'ws-1',
  name: 'Test space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'ABC123',
  environment: environment,
);

Future<void> _pump(
  WidgetTester tester,
  _FakeSampleData repository, {
  String environment = 'dev',
  bool configures = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sampleDataRepositoryProvider.overrideWithValue(repository),
        currentWorkspaceProvider.overrideWith(
          (ref) async => _space(environment),
        ),
        myPermissionsProvider.overrideWithValue({
          if (configures) WorkspacePermission.manageConfiguration,
        }),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SampleDataCard(workspaceId: 'ws-1'),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('a production space shows no card', (tester) async {
    await _pump(tester, _FakeSampleData(), environment: 'prod');
    expect(find.byKey(const ValueKey('sample-data-card')), findsNothing);
  });

  testWidgets('someone who does not configure the space sees no card', (
    tester,
  ) async {
    await _pump(tester, _FakeSampleData(), configures: false);
    expect(find.byKey(const ValueKey('sample-data-card')), findsNothing);
  });

  testWidgets('with none, it explains and fills', (tester) async {
    final repository = _FakeSampleData();
    await _pump(tester, repository);
    expect(find.textContaining('Nothing is sent to anyone'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sample-data-fill')));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(repository.calls, ['fill']);
    expect(
      find.text(
        'This space holds sample data: 6 members, 40 bookings, 3 payments.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sample-data-clear')), findsOneWidget);
  });

  testWidgets('with a batch, it clears and offers the fill again', (
    tester,
  ) async {
    final repository = _FakeSampleData(open: _batch);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('sample-data-clear')));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(repository.calls, ['clear']);
    expect(find.byKey(const ValueKey('sample-data-fill')), findsOneWidget);
    expect(find.byKey(const ValueKey('sample-data-not-cleared')), findsNothing);
  });

  testWidgets('a failed clear says not cleared, and the retry clears', (
    tester,
  ) async {
    final repository = _FakeSampleData(open: _batch, failClears: 1);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('sample-data-clear')));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(
      find.byKey(const ValueKey('sample-data-not-cleared')),
      findsOneWidget,
    );
    expect(
      find.textContaining('the sample data is still in this space'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sample-data-counts')), findsOneWidget);
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(repository.calls, ['clear', 'clear']);
    expect(find.byKey(const ValueKey('sample-data-not-cleared')), findsNothing);
    expect(find.byKey(const ValueKey('sample-data-fill')), findsOneWidget);
  });
}
