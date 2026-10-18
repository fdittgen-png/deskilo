// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 -- the equipment register: what the commands refuse before sending,
// the rules the demo twin keeps in step with the server (pgTAP 231), and the
// sheet from the list to the decision. Nothing is inferred: a decision states
// its basis, an expensed item has no use date, an unknown cost is not
// capitalised.
import 'package:deskilo/core/demo/data/workspace_asset_repository.dart';
import 'package:deskilo/core/demo/seed/demo_asset_seed.dart';
import 'package:deskilo/features/money/application/asset_commands.dart';
import 'package:deskilo/features/money/domain/workspace_asset.dart';
import 'package:deskilo/features/money/presentation/widgets/equipment_sheet.dart';
import 'package:deskilo/features/money/providers/asset_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
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

const _line = AssetCandidateLine(
  purchaseId: 'p1',
  lineNo: 1,
  description: 'Espresso machine',
  grossCents: 144000,
  currency: 'EUR',
  supplierName: 'Café du Midi',
  originalReference: 'CM-1',
);

AssetDecisionCommand _decide(
  WorkspaceAsset a, {
  AssetDecision decision = AssetDecision.capitalise,
  String basis = 'IAS 16',
  DateTime? from,
  String request = 'd1',
}) => AssetDecisionCommand(
  assetId: a.id,
  revision: a.revision,
  decision: decision,
  basis: basis,
  availableForUseOn: from,
  requestId: request,
);

void main() {
  test('a registered line is a candidate with the cost the line gives, once', () async {
    final repo = FakeWorkspaceAssetRepository(lines: const [_line]);
    final commands = AssetCommands(repo);
    final a = (await commands.register('ws', _line, 'Machine', 'r1'))!;
    expect(a.assetNumber, 1);
    expect(a.description, 'Machine');
    expect(a.isCandidate, isTrue);
    expect(a.decision, AssetDecision.pending);
    expect(await commands.register('ws', _line, 'Machine', 'r1'), same(a));
    expect(() => commands.register('ws', _line, 'Machine', 'r2'), throwsStateError, reason: 'a line is registered once');
    expect(await repo.fetchCandidateLines('ws'), isEmpty);
  });

  test('a decision states its basis; an expensed item has no use date; an unknown cost is not capitalised', () async {
    final repo = seedDemoAssets(_today);
    final commands = AssetCommands(repo);
    final printer = repo.assets.firstWhere((a) => a.id == 'demo-asset-printer');
    expect(await commands.decide('ws', printer, _decide(printer, basis: '  ')), isNull);
    expect(
      await commands.decide('ws', printer, _decide(printer, decision: AssetDecision.expense, from: DateTime(2026, 3))),
      isNull,
    );
    expect(await commands.decide('ws', printer, _decide(printer, decision: AssetDecision.pending)), isNull);
    const unknown = WorkspaceAsset(
      id: 'x',
      revision: 1,
      assetNumber: 9,
      description: 'Unqualified',
      currency: 'EUR',
      decision: AssetDecision.pending,
      state: AssetState.candidate,
    );
    expect(await commands.decide('ws', unknown, _decide(unknown)), isNull, reason: 'no cost, no capitalising');
    expect(repo.assets.firstWhere((a) => a.id == printer.id).isCandidate, isTrue, reason: 'nothing was sent');
  });

  test('capitalising with a date puts it in use, without one it stays a candidate; expensing is final', () async {
    final repo = seedDemoAssets(_today);
    final commands = AssetCommands(repo);
    final printer = repo.assets.firstWhere((a) => a.id == 'demo-asset-printer');
    final inUse = (await commands.decide('ws', printer, _decide(printer, from: DateTime(2026, 9))))!;
    expect(inUse.state, AssetState.inUse);
    expect(inUse.availableForUseOn, DateTime(2026, 9));
    expect(inUse.revision, printer.revision + 1);
    expect(await commands.decide('ws', inUse, _decide(inUse, request: 'd2')), isNull, reason: 'a decided asset is corrected in the open period');

    final repo2 = FakeWorkspaceAssetRepository(lines: const [_line]);
    final c2 = AssetCommands(repo2);
    final fresh = (await c2.register('ws', _line, '', 'r1'))!;
    final undated = (await c2.decide('ws', fresh, _decide(fresh)))!;
    expect(undated.state, AssetState.candidate, reason: 'no date, no in-use');
    expect(undated.decision, AssetDecision.capitalise);
    final repo3 = FakeWorkspaceAssetRepository(lines: const [_line]);
    final fresh3 = (await AssetCommands(repo3).register('ws', _line, '', 'r1'))!;
    final expensed = (await AssetCommands(repo3).decide('ws', fresh3, _decide(fresh3, decision: AssetDecision.expense)))!;
    expect(expensed.state, AssetState.expensed);
  });

  testWidgets('the sheet lists the equipment; the doors appear for who may', (tester) async {
    final repo = seedDemoAssets(_today);
    Future<void> open({required bool register, required bool decide}) async {
      await tester.pumpWidget(_app(
        EquipmentView(workspaceId: 'ws', canRegister: register, canDecide: decide),
        [workspaceAssetRepositoryProvider.overrideWithValue(repo)],
      ));
      await tester.pumpAndSettle();
    }

    await open(register: false, decide: false);
    expect(find.text('#1 Espresso machine, kitchen'), findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-cost-demo-asset-machine')), findsOneWidget);
    expect(find.textContaining('1,200.00'), findsWidgets);
    expect(find.byKey(const ValueKey('equipment-register')), findsNothing);
    expect(find.byKey(const ValueKey('equipment-decide-demo-asset-printer')), findsNothing);

    await open(register: true, decide: true);
    expect(find.byKey(const ValueKey('equipment-register')), findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-decide-demo-asset-printer')), findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-decide-demo-asset-machine')), findsNothing,
        reason: 'a decided asset has no decide door');
  });

  testWidgets('deciding from the sheet: nothing entered sends nothing; a basis capitalises', (tester) async {
    final repo = seedDemoAssets(_today);
    await tester.pumpWidget(_app(
      const EquipmentView(workspaceId: 'ws', canRegister: true, canDecide: true),
      [workspaceAssetRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-decide-demo-asset-printer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-decide-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('equipment-invalid')), findsOneWidget);
    expect(repo.assets.firstWhere((a) => a.id == 'demo-asset-printer').isCandidate, isTrue);

    await tester.enterText(find.byKey(const ValueKey('equipment-basis')), 'Lasting equipment');
    await tester.tap(find.byKey(const ValueKey('equipment-decide-save')));
    await tester.pumpAndSettle();
    final printer = repo.assets.firstWhere((a) => a.id == 'demo-asset-printer');
    expect(printer.decision, AssetDecision.capitalise);
    expect(printer.decisionBasis, 'Lasting equipment');
    expect(find.byKey(const ValueKey('equipment-decide-save')), findsNothing);
  });

  testWidgets('registering from the sheet names the chosen line', (tester) async {
    final repo = seedDemoAssets(_today);
    await tester.pumpWidget(_app(
      const EquipmentView(workspaceId: 'ws', canRegister: true, canDecide: false),
      [workspaceAssetRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-register-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('equipment-invalid')), findsOneWidget, reason: 'no line chosen');
    await tester.tap(find.byKey(const ValueKey('equipment-line')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Folding ladder').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-register-save')));
    await tester.pumpAndSettle();
    expect(repo.assets.map((a) => a.description), contains('Folding ladder'));
    expect(repo.candidates, isEmpty);
  });
}
