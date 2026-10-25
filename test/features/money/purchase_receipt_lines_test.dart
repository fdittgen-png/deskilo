// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 — a member's receipt of several lines, and the place a purchase
// line names. On the wire: each line carries its own rate, recoverable tax
// (rounded as the server rounds it), class and place; a zero rate is a
// stated tax, a line without a rate leaves its tax unknown; nothing the
// server derives is sent. On screen: the purchases page offers the receipt
// to anyone; two lines at two rates in two places are saved and submitted
// once; a refusal keeps every entry and the retry reuses both request ids;
// an amount that is not one is named under its field and nothing is sent.
// The detail names the place of each line. The demonstration mirrors it.
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/purchase_receipt_line.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/money/application/purchase_commands.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const _office = PurchasePlace(kind: 'office', id: 'o1', name: 'Blue room');
const _site = PurchasePlace(kind: 'site', id: 's2', name: 'Quai Bas');

/// Places to choose from; refuses the first submit; remembers every id.
class _Receipts extends FakePurchaseRepository {
  _Receipts({this.failSubmit = false}) {
    placesOf = (_) => const [
      PurchasePlace(kind: 'site', id: 's1', name: 'Rue Haute'),
      _site,
      PurchasePlace(kind: 'level', id: 'l1', name: 'Ground floor'),
      _office,
    ];
  }

  bool failSubmit;
  final saveIds = <String>[];
  final submitIds = <String>[];
  final drafts = <PurchaseDraft>[];

  @override
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseDraft draft,
  ) {
    saveIds.add(requestId);
    drafts.add(draft);
    return super.saveDraft(workspaceId, requestId, draft);
  }

  @override
  Future<PurchaseState> submitBill(
    String workspaceId,
    String purchaseId,
    int revision,
    String requestId,
  ) async {
    submitIds.add(requestId);
    if (failSubmit) {
      failSubmit = false;
      throw StateError('network');
    }
    return super.submitBill(workspaceId, purchaseId, revision, requestId);
  }
}

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
  vatRegime: 'vat_registered',
);

/// A VAT-registered space with input VAT on and two rates, in a root
/// container the test disposes.
Widget _app(_Receipts repo) {
  final container = ProviderContainer(
    overrides: <Override>[
      purchaseRepositoryProvider.overrideWithValue(repo),
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      enabledFeaturesSyncProvider.overrideWithValue({
        WorkspaceFeature.purchases,
        WorkspaceFeature.inputVat,
      }),
      vatRatesProvider.overrideWith(
        (ref) async => const [
          VatRate(id: 'std', label: 'Standard', percent: 20, isDefault: true),
          VatRate(id: 'red', label: 'Reduced', percent: 5.5),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PurchasesView(workspaceId: 'ws', canCapture: false),
        ),
      ),
    ),
  );
}

Future<void> _pick(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// Opens the receipt and fills two lines: 120.00 at 20 % in the office,
/// 10.55 at 5.5 %, half deductible, for the other site.
Future<void> _fillTwoLines(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('purchase-add-receipt')));
  await tester.pumpAndSettle();
  await _type(tester, 'receipt-gross-0', '120');
  await _pick(tester, 'receipt-rate-0', '20 %');
  await _pick(tester, 'receipt-purpose-0', 'Day-to-day use');
  await _pick(tester, 'receipt-place-0', 'Blue room');
  await tester.ensureVisible(find.byKey(const ValueKey('receipt-add-line')));
  await tester.tap(find.byKey(const ValueKey('receipt-add-line')));
  await tester.pumpAndSettle();
  await _type(tester, 'receipt-gross-1', '10.55');
  await _pick(tester, 'receipt-rate-1', '5.5 %');
  await _type(tester, 'receipt-share-1', '50');
  await _pick(tester, 'receipt-place-1', 'Quai Bas');
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('receipt-submit')));
  await tester.tap(find.byKey(const ValueKey('receipt-submit')));
  await tester.pumpAndSettle();
}

void main() {
  test('a line at a rate carries its tax and recoverable share as the server '
      'rounds them, its class and its place', () {
    final line = PurchaseLineDraft.atRate(
      grossCents: 1055,
      percent: 5.5,
      deductiblePct: 50,
      recognitionKind: 'operating',
      place: _office,
    ).toJson();
    expect(line, {
      'description': '',
      'gross_cents': 1055,
      'recognition_kind': 'operating',
      'tax_cents': 55,
      'net_cents': 1000,
      'tax_rate_percent': 5.5,
      'recoverable_tax_cents': 28,
      'resource_kind': 'office',
      'resource_id': 'o1',
    });
    expect(
      PurchaseLineDraft.atRate(
        grossCents: 300,
        percent: 0,
        deductiblePct: 100,
        place: _site,
      ).toJson(),
      containsPair('tax_cents', 0),
      reason: 'a zero rate is a stated tax, not an unknown one',
    );
    expect(
      PurchaseLineDraft.atRate(
        grossCents: 300,
        percent: 0,
        deductiblePct: 100,
        place: _site,
      ).toJson()['cost_site_id'],
      's2',
    );
    final unknown = const PurchaseLineDraft(grossCents: 900).toJson();
    expect(unknown.containsKey('tax_cents'), isFalse);
    expect(unknown.containsKey('tax_rate_percent'), isFalse);
  });

  test('the receipt payload is a member receipt with its lines; nothing the '
      'server derives is sent', () {
    final payload = PurchaseReceiptDraft(
      category: 'supplies',
      lines: [
        PurchaseLineDraft.atRate(
          grossCents: 12000,
          percent: 20,
          deductiblePct: 100,
        ),
        PurchaseLineDraft.atRate(
          grossCents: 1055,
          percent: 5.5,
          deductiblePct: 100,
        ),
      ],
    ).toPayload();
    expect(payload['kind'], 'member_receipt');
    expect(payload['category'], 'supplies');
    expect(payload['lines'], hasLength(2));
    for (final forbidden in [
      'state',
      'submitter_member_id',
      'payer_kind',
      'total_cents',
      'currency',
    ]) {
      expect(payload.containsKey(forbidden), isFalse, reason: forbidden);
    }
    final again = const PurchaseReceiptDraft(
      category: 'x',
      lines: [PurchaseLineDraft(grossCents: 1)],
    ).savedAs('p1', 1).toPayload();
    expect(again['purchase_id'], 'p1');
  });

  test('the first line that cannot be sent is named, amount before share', () {
    expect(receiptProblem(grosses: [100, 200], shares: [100, 50]), isNull);
    expect(receiptProblem(grosses: [100, null], shares: [100, 50]), (
      problem: ReceiptProblem.amount,
      line: 1,
    ));
    expect(receiptProblem(grosses: [100, 0], shares: [101, 50]), (
      problem: ReceiptProblem.amount,
      line: 1,
    ));
    expect(receiptProblem(grosses: [100, 200], shares: [100, 101]), (
      problem: ReceiptProblem.deductible,
      line: 1,
    ));
  });

  test('the command sends no receipt without a category or a positive amount '
      'on every line', () async {
    final repo = _Receipts();
    final commands = PurchaseCommands(repo);
    expect(
      await commands.saveReceipt(
        'ws',
        'r1',
        const PurchaseReceiptDraft(
          category: '',
          lines: [PurchaseLineDraft(grossCents: 100)],
        ),
      ),
      isNull,
    );
    expect(
      await commands.saveReceipt(
        'ws',
        'r2',
        const PurchaseReceiptDraft(
          category: 'supplies',
          lines: [
            PurchaseLineDraft(grossCents: 100),
            PurchaseLineDraft(grossCents: 0),
          ],
        ),
      ),
      isNull,
    );
    expect(repo.saveIds, isEmpty);
  });

  test('the demonstration keeps a receipt line by line, with its places, and '
      'sends it to approval once', () async {
    final repo = _Receipts();
    final commands = PurchaseCommands(repo);
    final id = await commands.saveReceipt(
      'ws',
      'r1',
      PurchaseReceiptDraft(
        category: 'supplies',
        lines: [
          PurchaseLineDraft.atRate(
            grossCents: 12000,
            percent: 20,
            deductiblePct: 100,
            place: _office,
          ),
          PurchaseLineDraft.atRate(
            grossCents: 1055,
            percent: 5.5,
            deductiblePct: 100,
            place: _site,
          ),
        ],
      ),
    );
    final detail = await repo.fetchDetail('ws', id!);
    expect(detail.summary.kind, PurchaseKind.memberReceipt);
    expect(detail.grossCents, 13055);
    expect(
      [for (final l in detail.lines) l.placeName],
      ['Blue room', 'Quai Bas'],
    );
    expect(detail.lines.first.resourceKind, 'office');
    expect(detail.lines.last.costSiteId, 's2');
    expect(
      await commands.submitReceipt('ws', id, 1, 's1'),
      PurchaseState.pending,
    );
    expect(
      await commands.submitReceipt('ws', id, 1, 's1'),
      PurchaseState.pending,
      reason: 'the same request answers what it answered',
    );
    expect(
      (await repo.fetchDetail('ws', id)).summary.state,
      PurchaseState.pending,
    );
  });

  test('the demonstration offers its own sites, then each level and its '
      'offices, never another space\'s', () async {
    final workspaces = FakeWorkspaceRepository()
      ..sites.addAll(const [
        Site(id: 's1', workspaceId: 'ws', name: 'Rue Haute'),
        Site(id: 'sx', workspaceId: 'other', name: 'Elsewhere'),
      ]);
    final plan = FakeFloorPlanRepository()
      ..levels.addAll(const [
        Level(id: 'l2', workspaceId: 'ws', name: 'First', sortOrder: 1),
        Level(id: 'l1', workspaceId: 'ws', name: 'Ground', sortOrder: 0),
      ])
      ..offices.add(
        const Office(
          id: 'o1',
          workspaceId: 'ws',
          levelId: 'l2',
          name: 'Blue room',
          color: 0,
          bookableAsWhole: false,
          rect: GridRect(x: 0, y: 0, w: 1, h: 1),
        ),
      );
    expect(
      [
        for (final p in demoPurchasePlaces(workspaces, plan, 'ws'))
          '${p.kind}:${p.name}',
      ],
      ['site:Rue Haute', 'level:Ground', 'level:First', 'office:Blue room'],
    );
    expect(
      await FakePurchaseRepository().fetchPlaces('ws'),
      isEmpty,
      reason: 'nothing handed over, nothing offered',
    );
  });

  testWidgets('a member files a receipt of two rates in two places; it awaits '
      'approval', (tester) async {
    final repo = _Receipts();
    await tester.pumpWidget(_app(repo));
    await tester.pump(); // the fakes answer in a microtask
    await _fillTwoLines(tester);
    await _submit(tester);

    final draft = repo.drafts.single as PurchaseReceiptDraft;
    expect(draft.category, 'coffee');
    expect(draft.originalDate, isNotNull, reason: 'dated, so it reaches the books');
    expect([for (final l in draft.lines) l.taxRatePercent], [20, 5.5]);
    expect([for (final l in draft.lines) l.recoverableTaxCents], [2000, 28]);
    expect([for (final l in draft.lines) l.place], [_office, _site]);
    expect(draft.lines.first.recognitionKind, 'operating');
    expect(repo.submitIds, hasLength(1));
    expect(find.text('Receipt submitted: it awaits approval.'), findsOneWidget);
    final id = (await repo.fetchPurchases('ws')).single.id;
    expect(
      (await repo.fetchDetail('ws', id)).summary.state,
      PurchaseState.pending,
    );
  });

  testWidgets('a refused submit keeps every entry; the retry saves nothing new '
      'and reuses the submit request', (tester) async {
    final repo = _Receipts(failSubmit: true);
    await tester.pumpWidget(_app(repo));
    await tester.pump(); // the fakes answer in a microtask
    await _fillTwoLines(tester);
    await _submit(tester);
    expect(find.byKey(const ValueKey('form-sheet-error')), findsOneWidget);
    expect(find.text('10.55'), findsOneWidget, reason: 'the entries stay');
    await _submit(tester);
    expect(repo.saveIds, hasLength(1), reason: 'the draft was already saved');
    expect(repo.submitIds, hasLength(2));
    expect(repo.submitIds[0], repo.submitIds[1]);
    expect(find.text('Receipt submitted: it awaits approval.'), findsOneWidget);
  });

  testWidgets('a line without a positive amount is named under its field and '
      'nothing is sent', (tester) async {
    final repo = _Receipts();
    await tester.pumpWidget(_app(repo));
    await tester.pump(); // the fakes answer in a microtask
    await tester.tap(find.byKey(const ValueKey('purchase-add-receipt')));
    await tester.pumpAndSettle();
    await _type(tester, 'receipt-gross-0', '0');
    await _submit(tester);
    expect(find.text('Enter a positive amount on every line.'), findsOneWidget);
    expect(repo.saveIds, isEmpty);
    expect(find.byKey(const ValueKey('receipt-submit')), findsOneWidget);
  });

  testWidgets('the detail names the place and the class of each line', (
    tester,
  ) async {
    final repo = _Receipts()
      ..add(
        PurchaseDetail(
          summary: const PurchaseSummary(
            id: 'p1',
            kind: PurchaseKind.memberReceipt,
            state: PurchaseState.pending,
            category: 'supplies',
            reference: '',
            currency: 'EUR',
          ),
          revision: 1,
          lines: [
            PurchaseLineDraft.atRate(
              grossCents: 12000,
              percent: 20,
              deductiblePct: 100,
              recognitionKind: 'asset',
              place: _office,
            ).toLine(1),
          ],
          sources: const [],
        ),
      );
    await tester.pumpWidget(_app(repo));
    await tester.pump(); // the fakes answer in a microtask
    await tester.tap(find.byKey(const ValueKey('purchase-p1')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Long-lasting equipment · Blue room'),
      findsOneWidget,
    );
  });
}
