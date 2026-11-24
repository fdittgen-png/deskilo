// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4403 -- ONE table of stock scenarios, run against the domain's StockLedger here and against the RPCs as pgTAP
// (supabase/tests/database/568_stock_contract.sql, whose rows are this table's rows to the letter: the parity test
// prints each row as SQL and finds it there). Both start from the same world and run the rows in order; each row
// names the balances it starts from (given), a command, the outcome and the balances after (then).
//
// The world: a business with two sites, MAIN (a warehouse) with SHELF under it and BRANCH with BRANCH-S1 under it,
// and the server's own places (SUPPLIER, CUSTOMER, LOSS, TRANSIT). Coffee beans by the kg, mugs by the piece (a box
// is 6), syrup by the litre (a third is 1/3). Received at the opening: 10 kg of beans at MAIN (O1), 24 mugs on SHELF
// (O2), 2 l of syrup at MAIN (O3).
//
// A command is a kind, a spec and an argument:
//   transfer  spec: lines `ITEM QTY FROM>TO [UNIT]`, joined by `;`
//   load      spec: lines `ITEM QTY FROM`; arg: the place the transfer goes to
//   receive   spec: `QTY [TO]`; arg: the row whose load it receives, or `none`
//   take_out  spec: lines `ITEM QTY FROM`; arg: `consumption` or `loss`
//   return    spec: `QTY [PLACE]`; arg: `KIND:ROW`, the row (or opening) whose first movement it reverses
//   count     spec: `ITEM PLACE OBSERVED`, recorded then applied; arg: a transfer line made in between, or empty
// An outcome is `ok`, `short` (less on hand than asked, DKG03), `refused REASON FIELD` (DKG11) or `code DKGnn`.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_ledger.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

typedef StockScenario = ({String id, String name, String given, String kind, String spec, String arg, String outcome, String then});

const stockScenarios = <StockScenario>[
  (id: 'S01', name: 'a transfer inside a site moves the goods', given: 'MUGS@SHELF=24 MUGS@MAIN=0',
      kind: 'transfer', spec: 'MUGS 4 SHELF>MAIN', arg: '', outcome: 'ok', then: 'MUGS@SHELF=20 MUGS@MAIN=4'),
  (id: 'S02', name: 'a box is moved as its 6 pieces', given: 'MUGS@SHELF=20 MUGS@MAIN=4',
      kind: 'transfer', spec: 'MUGS 1 SHELF>MAIN box', arg: '', outcome: 'ok', then: 'MUGS@SHELF=14 MUGS@MAIN=10'),
  (id: 'S03', name: 'a third of a litre is kept to six decimals', given: 'SYRUP@MAIN=2 SYRUP@SHELF=0',
      kind: 'transfer', spec: 'SYRUP 1 MAIN>SHELF third', arg: '', outcome: 'ok', then: 'SYRUP@MAIN=1.666667 SYRUP@SHELF=0.333333'),
  (id: 'S04', name: 'more than is there is refused and moves nothing', given: 'MUGS@SHELF=14',
      kind: 'transfer', spec: 'MUGS 100 SHELF>MAIN', arg: '', outcome: 'short', then: 'MUGS@SHELF=14 MUGS@MAIN=10'),
  (id: 'S05', name: 'one line short refuses the whole request', given: 'MUGS@SHELF=14 MUGS@MAIN=10',
      kind: 'transfer', spec: 'MUGS 1 SHELF>MAIN; MUGS 100 SHELF>MAIN', arg: '', outcome: 'short', then: 'MUGS@SHELF=14 MUGS@MAIN=10'),
  (id: 'S06', name: 'between two sites the goods go through transit', given: 'MUGS@SHELF=14 MUGS@BRANCH-S1=0',
      kind: 'transfer', spec: 'MUGS 1 SHELF>BRANCH-S1', arg: '', outcome: 'refused transfer_needs_transit lines[0]', then: 'MUGS@SHELF=14 MUGS@BRANCH-S1=0'),
  (id: 'S07', name: 'the in-transit place is the two-step transfer''s alone', given: 'MUGS@SHELF=14 MUGS@TRANSIT=0',
      kind: 'transfer', spec: 'MUGS 1 SHELF>TRANSIT', arg: '', outcome: 'refused transit_is_system lines[0]', then: 'MUGS@SHELF=14 MUGS@TRANSIT=0'),
  (id: 'S08', name: 'a transfer goes between two real places', given: 'MUGS@SHELF=14',
      kind: 'transfer', spec: 'MUGS 1 SHELF>LOSS', arg: '', outcome: 'refused reason_places lines[0]', then: 'MUGS@SHELF=14'),
  (id: 'S09', name: 'goods loaded for another site wait in transit', given: 'MUGS@SHELF=14 MUGS@TRANSIT=0',
      kind: 'load', spec: 'MUGS 4 SHELF', arg: 'BRANCH', outcome: 'ok', then: 'MUGS@SHELF=10 MUGS@TRANSIT=4'),
  (id: 'S10', name: 'inside one site a transfer is one step', given: 'MUGS@SHELF=10',
      kind: 'load', spec: 'MUGS 1 SHELF', arg: 'MAIN', outcome: 'refused same_site to_location_id', then: 'MUGS@SHELF=10 MUGS@TRANSIT=4'),
  (id: 'S11', name: 'a transfer has one source place', given: 'MUGS@SHELF=10 BEANS@MAIN=10',
      kind: 'load', spec: 'MUGS 1 SHELF; BEANS 1 MAIN', arg: 'BRANCH', outcome: 'refused one_source lines', then: 'MUGS@SHELF=10 BEANS@MAIN=10'),
  (id: 'S12', name: 'a transfer goes to a real place', given: 'MUGS@SHELF=10',
      kind: 'load', spec: 'MUGS 1 SHELF', arg: 'LOSS', outcome: 'refused location_foreign to_location_id', then: 'MUGS@SHELF=10'),
  (id: 'S13', name: 'more than is there is not loaded', given: 'MUGS@SHELF=10',
      kind: 'load', spec: 'MUGS 100 SHELF', arg: 'BRANCH', outcome: 'short', then: 'MUGS@SHELF=10 MUGS@TRANSIT=4'),
  (id: 'S14', name: 'a part is received onto a place of the destination', given: 'MUGS@TRANSIT=4 MUGS@BRANCH-S1=0',
      kind: 'receive', spec: '1 BRANCH-S1', arg: 'S09', outcome: 'ok', then: 'MUGS@TRANSIT=3 MUGS@BRANCH-S1=1'),
  (id: 'S15', name: 'never more than is still on its way', given: 'MUGS@TRANSIT=3',
      kind: 'receive', spec: '5', arg: 'S09', outcome: 'refused receive_over lines[0].quantity', then: 'MUGS@TRANSIT=3'),
  (id: 'S16', name: 'received at the destination''s site only', given: 'MUGS@TRANSIT=3 MUGS@SHELF=10',
      kind: 'receive', spec: '1 SHELF', arg: 'S09', outcome: 'refused wrong_site lines[0].to', then: 'MUGS@TRANSIT=3 MUGS@SHELF=10'),
  (id: 'S17', name: 'a quantity above zero is received', given: 'MUGS@TRANSIT=3',
      kind: 'receive', spec: '0', arg: 'S09', outcome: 'refused quantity_invalid lines[0].quantity', then: 'MUGS@TRANSIT=3'),
  (id: 'S18', name: 'a transfer of the business is received', given: 'MUGS@TRANSIT=3',
      kind: 'receive', spec: '1', arg: 'none', outcome: 'refused transfer_unknown transfer', then: 'MUGS@TRANSIT=3'),
  (id: 'S19', name: 'the rest is received at the destination itself', given: 'MUGS@TRANSIT=3 MUGS@BRANCH=0',
      kind: 'receive', spec: '3', arg: 'S09', outcome: 'ok', then: 'MUGS@TRANSIT=0 MUGS@BRANCH=3'),
  (id: 'S20', name: 'goods are taken out for use', given: 'BEANS@MAIN=10',
      kind: 'take_out', spec: 'BEANS 2 MAIN', arg: 'consumption', outcome: 'ok', then: 'BEANS@MAIN=8'),
  (id: 'S21', name: 'more than is there is not written off', given: 'BEANS@MAIN=8',
      kind: 'take_out', spec: 'BEANS 100 MAIN', arg: 'loss', outcome: 'short', then: 'BEANS@MAIN=8'),
  (id: 'S22', name: 'goods on the road are not written off', given: 'MUGS@TRANSIT=0',
      kind: 'take_out', spec: 'MUGS 1 TRANSIT', arg: 'loss', outcome: 'refused transit_is_system lines[0]', then: 'MUGS@TRANSIT=0'),
  (id: 'S23', name: 'a take-out leaves a real place', given: '',
      kind: 'take_out', spec: 'MUGS 1 SUPPLIER', arg: 'loss', outcome: 'refused reason_places lines[0]', then: 'MUGS@SHELF=10'),
  (id: 'S24', name: 'a correction takes back part of a take-out', given: 'BEANS@MAIN=8',
      kind: 'return', spec: '1', arg: 'correction:S20', outcome: 'ok', then: 'BEANS@MAIN=9'),
  (id: 'S25', name: 'never more than the movement still allows', given: 'BEANS@MAIN=9',
      kind: 'return', spec: '5', arg: 'correction:S20', outcome: 'code DKG17', then: 'BEANS@MAIN=9'),
  (id: 'S26', name: 'a customer return follows a sale', given: 'MUGS@MAIN=10',
      kind: 'return', spec: '1 MAIN', arg: 'customer:S01', outcome: 'code DKG18', then: 'MUGS@MAIN=10'),
  (id: 'S27', name: 'goods go back to the supplier of a receipt', given: 'BEANS@MAIN=9',
      kind: 'return', spec: '1 MAIN', arg: 'supplier:O1', outcome: 'ok', then: 'BEANS@MAIN=8'),
  (id: 'S28', name: 'a leg of a transfer between sites is not corrected', given: 'MUGS@TRANSIT=0',
      kind: 'return', spec: '1', arg: 'correction:S09', outcome: 'code DKG18', then: 'MUGS@TRANSIT=0 MUGS@SHELF=10'),
  (id: 'S29', name: 'an applied count moves exactly its difference', given: 'BEANS@MAIN=8',
      kind: 'count', spec: 'BEANS MAIN 7', arg: '', outcome: 'ok', then: 'BEANS@MAIN=7'),
  (id: 'S30', name: 'a count the stock moved since is counted again', given: 'MUGS@SHELF=10 MUGS@MAIN=10',
      kind: 'count', spec: 'MUGS SHELF 9', arg: 'MUGS 1 SHELF>MAIN', outcome: 'code DKG20', then: 'MUGS@SHELF=9 MUGS@MAIN=11'),
];

/// The pgTAP twin of [s], to the letter: the given balances, the command and its outcome, the balances after.
List<String> stockScenarioSql(StockScenario s) => [
  if (s.given.isNotEmpty) "select is(pg_temp.bal('${s.given}'), '${s.given}', '${s.id} given');",
  "select is(pg_temp.run('${s.id}', '${s.kind}', '${s.spec}', '${s.arg}'), '${s.outcome}', '${s.id} ${s.name.replaceAll("'", "''")}');",
  "select is(pg_temp.bal('${s.then}'), '${s.then}', '${s.id} then');",
];

StockPlaceConfig _place(String code, String kind, {String? parent, bool virtual = false}) => StockPlaceConfig(
  id: code, revision: 1, kind: kind, code: code, name: '', barcode: null, parentId: parent, active: true, virtual: virtual,
);

/// The scenarios' world on a fresh [StockLedger], the openings booked.
class StockScenarioWorld {
  StockScenarioWorld() {
    ledger = StockLedger(
      'ws',
      items: () => const [
        StockItem(id: 'BEANS', name: 'Coffee beans', unit: 'kg'),
        StockItem(id: 'MUGS', name: 'Mugs', unit: 'piece'),
        StockItem(id: 'SYRUP', name: 'Syrup', unit: 'l'),
      ],
      places: () => _places,
      units: (item) => switch (item) {
        'MUGS' => const [StockUnitDraft(unit: 'box', factorNum: 6, factorDen: 1)],
        'SYRUP' => const [StockUnitDraft(unit: 'third', factorNum: 1, factorDen: 3)],
        _ => const [],
      },
      clock: () => DateTime.utc(2026, 11),
    );
    for (final (id, item, quantity, to) in const [('O1', 'BEANS', '10', 'MAIN'), ('O2', 'MUGS', '24', 'SHELF'), ('O3', 'SYRUP', '2', 'MAIN')]) {
      _first[id] = ledger.book(StockPost(item: ledger.itemOf(item)!, quantity: ExactQuantity.parse(quantity), from: 'SUPPLIER', to: to, reason: 'receipt')).id;
    }
  }

  late final StockLedger ledger;
  final Map<String, String> _first = {};
  final Map<String, String> _transfers = {};

  static final _places = {
    for (final p in [
      _place('MAIN', 'warehouse'),
      _place('SHELF', 'shelf', parent: 'MAIN'),
      _place('BRANCH', 'warehouse'),
      _place('BRANCH-S1', 'shelf', parent: 'BRANCH'),
      _place('SUPPLIER', 'supplier', virtual: true),
      _place('CUSTOMER', 'customer', virtual: true),
      _place('LOSS', 'loss', virtual: true),
      _place('TRANSIT', 'in_transit', virtual: true),
    ])
      p.id: p,
  };

  /// [spec] (`ITEM@PLACE=QTY ...`) with the quantities the ledger holds now.
  String balances(String spec) => [
    for (final part in spec.split(' ').where((p) => p.isNotEmpty))
      () {
        final [item, place] = part.split('=').first.split('@');
        return '$item@$place=${ledger.held(item, place).text}';
      }(),
  ].join(' ');

  static List<StockLineDraft> _lines(String spec) => [
    for (final line in spec.split(';'))
      () {
        final t = line.trim().split(RegExp(r'\s+'));
        final [from, to] = t[2].contains('>') ? t[2].split('>') : [t[2], null];
        return StockLineDraft(itemId: t[0], quantity: t[1], fromLocationId: from!, toLocationId: to, unit: t.length > 3 ? t[3] : null);
      }(),
  ];

  /// Runs [s]'s command; answers its outcome as the table words it.
  String run(StockScenario s) {
    final before = ledger.movements.length;
    final outcome = _outcome(() => _command(s));
    if (outcome == 'ok' && ledger.movements.length > before) _first[s.id] = ledger.movements[ledger.movements.length - before - 1].id;
    return outcome;
  }

  void _command(StockScenario s) {
    final t = s.spec.split(' ');
    switch (s.kind) {
      case 'transfer':
        ledger.transferInSite(_lines(s.spec));
      case 'load':
        _transfers[s.id] = ledger.load(s.arg, _lines(s.spec)).id;
      case 'receive':
        final transfer = ledger.transfer(_transfers[s.arg] ?? 'none');
        ledger.receive(transfer?.id ?? 'none', [
          (lineId: transfer?.lines.first.id ?? 'none', quantity: t[0], toLocationId: t.length > 1 ? t[1] : null),
        ]);
      case 'take_out':
        ledger.takeOut(StockTakeOutReason.values.byName(s.arg), _lines(s.spec));
      case 'return':
        final [kind, source] = s.arg.split(':');
        ledger.makeReturn('return-${s.id}', StockReturnKind.values.byName(kind), [
          (lineId: 'line-${s.id}', sourceMovementId: _first[source]!, quantity: t[0], locationId: t.length > 1 ? t[1] : null, note: ''),
        ]);
      case 'count':
        ledger.recordCount((countId: 'count-${s.id}', itemId: t[0], locationId: t[1], observed: t[2], requestId: s.id, variantId: null, lotId: null, reason: ''),
            author: 'me');
        if (s.arg.isNotEmpty) ledger.transferInSite(_lines(s.arg));
        ledger.decideCount('count-${s.id}', StockCountDecision.apply, decider: 'me');
      default:
        throw ArgumentError(s.kind);
    }
  }

  static String _outcome(void Function() run) {
    try {
      run();
      return 'ok';
    } on StockConfigRefused catch (e) {
      return 'refused ${e.reason.wire} ${e.field}';
    } on StockNotEnough {
      return 'short';
    } on StockCodeRefused catch (e) {
      return 'code ${e.code}';
    }
  }
}
