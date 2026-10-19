// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 (C2) -- the valuations screen: the confirmed batch shows with its
// unknown figures as unknown; a file with a problem is named line by line and
// stages nothing; a usable file is staged once its source is named and is
// confirmed from the list.
import 'dart:convert';

import 'package:deskilo/core/demo/data/asset_valuation_repository.dart';
import 'package:deskilo/core/demo/seed/demo_valuation_seed.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/features/money/application/asset_valuation_commands.dart';
import 'package:deskilo/features/money/domain/asset_valuation.dart';
import 'package:deskilo/features/money/presentation/widgets/asset_valuations_sheet.dart';
import 'package:deskilo/features/money/providers/asset_valuation_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

final _today = DateTime(2026, 10, 18);

const _head =
    'AssetNumber,Basis,PeriodFrom,PeriodTo,Currency,OpeningMinor,AdditionsMinor,'
    'DisposalsMinor,DepreciationMinor,ImpairmentMinor,ClosingMinor,ExternalReference';

void main() {
  test('nothing is sent for a file with a problem, no source, or a batch that cannot be confirmed', () async {
    final repo = seedDemoValuations(_today);
    final commands = AssetValuationCommands(repo);
    const source = ValuationSource(
      system: 'Cabinet Martin',
      movements: 'period',
      completeScope: false,
    );
    final bad = readValuationCsv(
      '$_head\nx,book,2026-01-01,2026-12-31,EUR,,,,,,,\n',
    );
    expect(
      await commands.stage('ws', file: bad, source: source, requestId: 'r1'),
      isNull,
    );
    final good = readValuationCsv(valuationSampleCsv());
    expect(
      await commands.stage(
        'ws',
        file: good,
        source: const ValuationSource(
          system: ' ',
          movements: 'period',
          completeScope: false,
        ),
        requestId: 'r2',
      ),
      isNull,
    );
    expect(await repo.fetchBatches('ws'), hasLength(1));
    final staged = (await commands.stage(
      'ws',
      file: good,
      source: source,
      requestId: 'r3',
    ))!;
    expect(staged.status, ValuationStatus.staged);
    // The same bytes answer the same batch.
    expect(
      (await commands.stage(
        'ws',
        file: good,
        source: source,
        requestId: 'r4',
      ))!.id,
      staged.id,
    );
    expect(await repo.fetchBatches('ws'), hasLength(2));
  });

  test('an overlapping period needs the batch it replaces, and why', () async {
    final repo = FakeAssetValuationRepository();
    final commands = AssetValuationCommands(repo);
    const source = ValuationSource(
      system: 'Cabinet Martin',
      movements: 'period',
      completeScope: false,
    );
    ValuationCsv file(String closing) => readValuationCsv(
      '$_head\n1,book,2026-01-01,2026-12-31,EUR,100,0,0,0,0,$closing,\n',
    );
    final first = (await commands.stage(
      'ws',
      file: file('100'),
      source: source,
      requestId: 'a',
    ))!;
    await commands.confirm('ws', batch: first, requestId: 'b');
    // The same figures in other bytes are another source, hence another batch.
    final second = (await commands.stage(
      'ws',
      file: readValuationCsv(
        '$_head\n1,book,2026-01-01,2026-12-31,EUR,100,0,0,0,0,100,FA-1\n',
      ),
      source: source,
      requestId: 'c',
    ))!;
    await expectLater(
      commands.confirm('ws', batch: second, requestId: 'd'),
      throwsStateError,
    );
    expect(
      await commands.confirm(
        'ws',
        batch: second,
        requestId: 'e',
        supersedes: first.id,
      ),
      isNull,
      reason: 'a replacement states why',
    );
    final done = (await commands.confirm(
      'ws',
      batch: second,
      requestId: 'f',
      supersedes: first.id,
      reason: 'Re-issued',
    ))!;
    expect(done.status, ValuationStatus.confirmed);
    expect(
      (await repo.fetchBatches('ws'))
          .firstWhere((b) => b.id == first.id)
          .status,
      ValuationStatus.superseded,
    );
  });

  testWidgets(
    'the list shows the confirmed batch and its figures; an unknown stays unknown',
    (tester) async {
      final repo = seedDemoValuations(_today);
      await tester.pumpWidget(
        _app(const AssetValuationsView(workspaceId: 'ws'), [
          assetValuationRepositoryProvider.overrideWithValue(repo),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Book values from Cabinet Martin'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('valuation-status-demo-valuation-last')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('valuation-confirm-demo-valuation-last')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('valuation-rows-demo-valuation-last')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('960.00'), findsWidgets);
    },
  );

  testWidgets(
    'importing: a problem is named, a good file needs a source, then it is staged and confirmed',
    (tester) async {
      final repo = seedDemoValuations(_today);
      var csv = '$_head\nx,book,2026-01-01,2026-12-31,EUR,,,,,,,\n';
      await tester.pumpWidget(
        _app(const AssetValuationsView(workspaceId: 'ws'), [
          assetValuationRepositoryProvider.overrideWithValue(repo),
          filePickerProvider.overrideWithValue(
            (_) async => XFile.fromData(utf8.encode(csv), name: 'v.csv'),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('valuation-import')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('valuation-pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('valuation-issue')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('valuation-stage')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('valuation-invalid')), findsOneWidget);
      expect(await repo.fetchBatches('ws'), hasLength(1));

      csv = valuationSampleCsv().replaceAll('2026-', '2027-');
      await tester.tap(find.byKey(const ValueKey('valuation-pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('valuation-preview')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('valuation-stage')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('valuation-invalid')),
        findsOneWidget,
        reason: 'no source named',
      );
      await tester.enterText(
        find.byKey(const ValueKey('valuation-source')),
        'Cabinet Martin',
      );
      await tester.tap(find.byKey(const ValueKey('valuation-stage')));
      await tester.pumpAndSettle();
      final staged = (await repo.fetchBatches('ws')).last;
      expect(staged.status, ValuationStatus.staged);
      expect(staged.rowCount, 2);

      await tester.tap(find.byKey(ValueKey('valuation-confirm-${staged.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('valuation-confirm-save')));
      await tester.pumpAndSettle();
      expect(
        (await repo.fetchBatches('ws')).last.status,
        ValuationStatus.confirmed,
      );
    },
  );
}
