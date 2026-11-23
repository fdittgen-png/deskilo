// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- the Demo's expiry report, answering as the server does from lots the Demo keeps with their dates: oat milk
// with a lot that expired days ago and one that expires soon, a crate of apples of which one expired and one will, and the five
// tagged pieces of the gift basket. Dates are relative to the Demo's day, so the report always has something expired and
// something expiring. The same rules as the server: a lot is listed once, expired is before the reference date, expiring from it
// up to the horizon (the setting's 30 days when none is given), by date then place.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/stock/domain/stock_expiry.dart';
import '../../../features/stock/domain/stock_tags.dart';
import 'demo_stock_tags.dart';

class _Lot {
  const _Lot(this.itemId, this.itemName, this.lot, this.offset, this.quantity, this.unit, this.placeId, this.placeCode, this.placeName);

  final String itemId;
  final String itemName;
  final String lot;
  final int offset;
  final String quantity;
  final String unit;
  final String placeId;
  final String placeCode;
  final String placeName;
}

const _lots = [
  _Lot('demo-item-milk', 'Oat milk', 'MILK-09', -6, '2', 'l', 'demo-place-main', 'MAIN', 'Main store'),
  _Lot('demo-item-milk', 'Oat milk', 'MILK-12', 4, '6', 'l', 'demo-place-main', 'MAIN', 'Main store'),
  _Lot('demo-item-apples', 'Apples, crate', 'APPLES-OLD', -2, '1', 'piece', 'demo-place-shelf', 'SHELF-A', 'Shelf A'),
  _Lot('demo-item-apples', 'Apples, crate', 'APPLES-1', 12, '1', 'piece', 'demo-place-back', 'BACK', 'Back room'),
];

/// The gift basket's lot expires this many days after the Demo's day.
const _basketLife = 9;

class DemoStockExpiry implements StockExpiry {
  DemoStockExpiry(this._now, this._tags, {this.itemsOfGroup, this.horizonDays = 30});

  final DateTime Function() _now;
  final DemoStockTags _tags;

  /// Whether an item belongs to a group; without it a group filter lists nothing.
  final Future<bool> Function(String itemId, String groupId)? itemsOfGroup;

  /// The business's look-ahead (the setting's default) when a query names none.
  final int horizonDays;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [day] moved by [days] calendar days.
  static DateTime _plus(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

  @override
  Future<ExpiryReport> report(String workspaceId, ExpiryQuery query, {int maxRows = 2000}) async {
    final today = _day(_now());
    final on = query.on == null ? today : _day(query.on!);
    final horizon = query.horizonDays ?? horizonDays;
    final all = <ExpiryRow>[];
    for (final l in _lots) {
      all.add(ExpiryRow(
        itemId: l.itemId,
        itemName: l.itemName,
        lotCode: l.lot,
        expiresOn: _plus(today, l.offset),
        days: 0,
        quantity: ExactQuantity.parse(l.quantity),
        unit: l.unit,
        locationCode: l.placeCode,
        locationName: l.placeName,
      ));
    }
    // the gift basket's five pieces, one lot, each with its tag
    final pieces = [for (final t in await _tags.tags(workspaceId, const TagOwner.item('demo-item-basket'))) if (t.isPiece) t];
    for (final t in pieces) {
      all.add(ExpiryRow(
        itemId: 'demo-item-basket',
        itemName: 'Gift basket',
        lotCode: 'BASKET-1',
        expiresOn: _plus(today, _basketLife),
        days: 0,
        quantity: ExactQuantity.parse('1'),
        unit: 'piece',
        locationCode: 'BACK',
        locationName: 'Back room',
        pieceId: t.pieceId,
        tag: t.code,
      ));
    }
    final rows = <ExpiryRow>[];
    for (final r in all) {
      final days = DateTime.utc(r.expiresOn.year, r.expiresOn.month, r.expiresOn.day).difference(DateTime.utc(on.year, on.month, on.day)).inDays;
      final expired = days < 0;
      final expiring = days >= 0 && days <= horizon;
      final wanted = switch (query.scope) {
        ExpiryScope.expired => expired,
        ExpiryScope.expiring => expiring,
        ExpiryScope.both => expired || expiring,
      };
      if (!wanted) continue;
      if (query.locationId != null && !_atPlace(r, query.locationId!)) continue;
      if (query.groupId != null && !(await (itemsOfGroup?.call(r.itemId, query.groupId!) ?? Future.value(false)))) continue;
      rows.add(ExpiryRow(
        itemId: r.itemId,
        itemName: r.itemName,
        lotCode: r.lotCode,
        expiresOn: r.expiresOn,
        days: days,
        quantity: r.quantity,
        unit: r.unit,
        locationCode: r.locationCode,
        locationName: r.locationName,
        pieceId: r.pieceId,
        tag: r.tag,
      ));
    }
    rows.sort((a, b) {
      final byDate = a.expiresOn.compareTo(b.expiresOn);
      if (byDate != 0) return byDate;
      final byPlace = a.locationCode.compareTo(b.locationCode);
      return byPlace != 0 ? byPlace : (a.tag.isEmpty ? a.itemName : a.tag).compareTo(b.tag.isEmpty ? b.itemName : b.tag);
    });
    return ExpiryReport(rows: rows, asOf: on);
  }

  static bool _atPlace(ExpiryRow r, String placeId) => switch (placeId) {
    'demo-place-main' => r.locationCode == 'MAIN',
    'demo-place-shelf' => r.locationCode == 'SHELF-A',
    'demo-place-back' => r.locationCode == 'BACK',
    _ => false,
  };
}
