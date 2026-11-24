// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- a value of the stock wire this app does not know is a named `unknown`, never a guess: a count, a task, a
// line, a plan's scope, a unit's kind and a trace layer each read a value they know as itself and any other as
// `unknown` (an absent trace layer is nothing recorded, as the server answers it). A place is addressable when it
// is neither the server's nor the road.
import 'package:deskilo/features/stock/domain/handling_units.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_cycle_counts.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo/features/stock/domain/stock_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each known value reads as itself and any other as unknown', () {
    expect(
      [
        StockCountState.fromWire('applied'),
        StockCountState.fromWire('archived'),
      ],
      [StockCountState.applied, StockCountState.unknown],
    );
    expect(
      [
        CountTaskState.fromWire('complete'),
        CountTaskState.fromWire('paused'),
        CountTaskState.fromWire(null),
      ],
      [CountTaskState.complete, CountTaskState.unknown, CountTaskState.unknown],
    );
    expect(
      [
        CountLineState.fromWire('skipped'),
        CountLineState.fromWire('recounted'),
      ],
      [CountLineState.skipped, CountLineState.unknown],
    );
    expect(
      [
        CountScope.fromWire('high_value'),
        CountScope.fromWire('by_supplier'),
        CountScope.fromWire(''),
      ],
      [CountScope.highValue, CountScope.unknown, CountScope.unknown],
    );
    expect(
      [HandlingUnitKind.of('other'), HandlingUnitKind.of('drum')],
      [HandlingUnitKind.other, HandlingUnitKind.unknown],
    );
    expect(
      [StockCountState.fromWire('unknown'), HandlingUnitKind.of('unknown')],
      [StockCountState.unknown, HandlingUnitKind.unknown],
    );
  });

  test('a trace layer reads what the server says, nothing recorded when it says nothing, unknown otherwise', () {
    expect(
      [
        TraceState.of('linked'),
        TraceState.of('not_linked'),
        TraceState.of(null),
        TraceState.of('disputed'),
      ],
      [
        TraceState.linked,
        TraceState.notLinked,
        TraceState.notLinked,
        TraceState.unknown,
      ],
    );
  });

  test(
    'a place is addressable when it is neither the server\'s nor the road',
    () {
      StockPlaceConfig place(String kind, {bool virtual = false}) =>
          StockPlaceConfig(
            id: kind,
            revision: 1,
            kind: kind,
            code: kind.toUpperCase(),
            name: '',
            barcode: null,
            parentId: null,
            active: true,
            virtual: virtual,
          );
      expect(
        [
          place('shelf').isAddressable,
          place('in_transit').isAddressable,
          place('loss', virtual: true).isAddressable,
        ],
        [true, false, false],
      );
      expect(place('in_transit').inTransit, isTrue);
    },
  );
}
